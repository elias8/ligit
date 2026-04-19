part of 'api.dart';

/// Type of change described by a [DiffDelta].
///
/// [DeltaStatus.renamed] and [DeltaStatus.copied] only appear after
/// [Diff.findSimilar] has been run. [DeltaStatus.typechange] only
/// appears when [DiffOption.includeTypechange] is set; otherwise type
/// changes are split into add/delete pairs.
typedef DeltaStatus = Delta;

/// Flags controlling the behavior of [Diff.findSimilar] rename and
/// copy detection.
typedef DiffFindOption = DiffFind;

/// Line origin constants passed to [Diff.foreach] and [Diff.printLines].
///
/// Describes where a line came from. Special origin values are used
/// by the text output callbacks to demarcate file and hunk headers.
typedef DiffLineOrigin = DiffLine;

/// Tree and file differencing routines.
///
/// A [Diff] records the set of changes between two snapshots of a
/// repository — two trees, a tree and the index, the index and the
/// working directory, and so on. Create one with any of the named
/// constructors, then inspect the [deltas], format the diff to text
/// with [toText], or run [findSimilar] to detect renames and copies.
///
/// Owns a native resource; call [dispose] when finished.
///
/// ```dart
/// final diff = Diff.treeToWorkdir(repo: repo, oldTree: tree);
/// try {
///   print('${diff.numDeltas} changed files');
///   print(diff.toText());
/// } finally {
///   diff.dispose();
/// }
/// ```
@immutable
final class Diff {
  /// Maximum number of header bytes a diff hunk can carry.
  static const hunkHeaderSize = diffHunkHeaderSize;

  static final _finalizer = Finalizer<int>(diffFree);

  final int _handle;

  /// Creates a diff between two tree objects — equivalent to
  /// `git diff <oldTree> <newTree>`.
  ///
  /// [oldTree] is the "old" side of each delta and [newTree] is the
  /// "new" side. Either may be null to signal an empty tree; passing
  /// null for both is invalid.
  factory Diff.treeToTree({
    required Repository repo,
    Tree? oldTree,
    Tree? newTree,
    DiffOptions? options,
  }) => Diff._(
    diffTreeToTree(
      repo._handle,
      oldTree?._handle ?? 0,
      newTree?._handle ?? 0,
      options: options?._record,
    ),
  );

  /// Creates a diff between [oldTree] and an index — equivalent to
  /// `git diff --cached <treeish>` (or, with the HEAD tree,
  /// `git diff --cached`).
  ///
  /// [oldTree] is the "old" side of each delta and [index] the "new"
  /// side. When [index] is null the repository's current index is
  /// used and refreshed from disk if needed.
  factory Diff.treeToIndex({
    required Repository repo,
    Tree? oldTree,
    Index? index,
    DiffOptions? options,
  }) => Diff._(
    diffTreeToIndex(
      repo._handle,
      oldTree?._handle ?? 0,
      indexHandle: index?._handle ?? 0,
      options: options?._record,
    ),
  );

  /// Creates a diff between an index and the working directory —
  /// matches the `git diff` command.
  ///
  /// [index] supplies the "old" side (the repository's current index
  /// when null, refreshed from disk if needed); the working directory
  /// supplies the "new" side.
  factory Diff.indexToWorkdir({
    required Repository repo,
    Index? index,
    DiffOptions? options,
  }) => Diff._(
    diffIndexToWorkdir(
      repo._handle,
      indexHandle: index?._handle ?? 0,
      options: options?._record,
    ),
  );

  /// Creates a diff between [oldTree] and the working directory.
  ///
  /// This is not the same as `git diff <treeish>` — which consults
  /// the index. Use [Diff.treeToWorkdirWithIndex] to emulate the
  /// command-line behavior. Here, differences are computed strictly
  /// between the tree and the files on disk, regardless of what is
  /// staged.
  factory Diff.treeToWorkdir({
    required Repository repo,
    Tree? oldTree,
    DiffOptions? options,
  }) => Diff._(
    diffTreeToWorkdir(
      repo._handle,
      oldTree?._handle ?? 0,
      options: options?._record,
    ),
  );

  /// Creates a diff between [oldTree] and the working directory,
  /// using index data to account for staged deletions, tracked
  /// files, etc. — emulates `git diff <tree>`.
  ///
  /// Computes the tree-to-index diff and the index-to-workdir diff
  /// and blends the results into a single diff.
  factory Diff.treeToWorkdirWithIndex({
    required Repository repo,
    Tree? oldTree,
    DiffOptions? options,
  }) => Diff._(
    diffTreeToWorkdirWithIndex(
      repo._handle,
      oldTree?._handle ?? 0,
      options: options?._record,
    ),
  );

  /// Creates a diff between two indexes belonging to [repo].
  ///
  /// [oldIndex] supplies the "old" side of each delta; [newIndex] the
  /// "new" side.
  factory Diff.indexToIndex({
    required Repository repo,
    required Index oldIndex,
    required Index newIndex,
    DiffOptions? options,
  }) => Diff._(
    diffIndexToIndex(
      repo._handle,
      oldIndex._handle,
      newIndex._handle,
      options: options?._record,
    ),
  );

  /// Reads a git-formatted patch file from [buffer] into a [Diff].
  ///
  /// The resulting diff is similar to one produced by comparing two
  /// trees directly, but with differences — object ids in deltas may
  /// be abbreviated to whatever length the patch file stored. Only
  /// patches emitted by a git implementation are accepted.
  factory Diff.fromBuffer(Uint8List buffer) => Diff._(diffFromBuffer(buffer));

  /// Returns the single character label git uses for [status] in
  /// `git diff --name-status` output (`A` for added, `D` for
  /// deleted, `M` for modified, etc., or a space for untracked).
  static String statusChar(DeltaStatus status) =>
      String.fromCharCode(diffStatusChar(status.value));

  Diff._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Total number of deltas in this diff.
  int get numDeltas => diffNumDeltas(_handle);

  /// Number of deltas in this diff whose status equals [status].
  int countDeltasOfType(DeltaStatus status) =>
      diffNumDeltasOfType(_handle, status.value);

  /// Whether deltas in this diff are sorted case-insensitively.
  bool get isSortedIcase => diffIsSortedIcase(_handle);

  /// Returns the delta at [position], or null when out of range.
  ///
  /// The binary-content flags on the delta may not yet be populated
  /// — to force them, iterate with [foreach] or build a [Patch].
  DiffDelta? getDelta(int position) {
    final r = diffGetDelta(_handle, position);
    return r == null ? null : DiffDelta._(r);
  }

  /// Every delta in this diff, in the order libgit2 produced them.
  Iterable<DiffDelta> get deltas sync* {
    for (var i = 0; i < numDeltas; i++) {
      final r = diffGetDelta(_handle, i);
      if (r == null) return;
      yield DiffDelta._(r);
    }
  }

  /// Merges [other] into this diff.
  ///
  /// Items that appear in only one side are carried through; items
  /// that appear in both are combined so the old side comes from
  /// this diff and the new side from [other]. A pending delete in
  /// the middle keeps its deleted status in the merged result.
  void merge(Diff other) => diffMerge(_handle, other._handle);

  /// Detects file renames and copies, rewriting deltas in place.
  ///
  /// Old entries that look like renames or copies are replaced with
  /// new entries reflecting those changes. When requested by
  /// [options], modified files whose change amount crosses the
  /// threshold are broken into add/delete pairs.
  void findSimilar([DiffFindOptions? options]) =>
      diffFindSimilar(_handle, options: options?._record);

  /// Iterates every delta and, optionally, every hunk and line.
  ///
  /// [onFile] fires once per delta; [onHunk] once per hunk; [onLine]
  /// once per diff line (context, added, removed, or the deleted
  /// trailing newline). The hunk and line callbacks are skipped for
  /// binary files and for files whose only change is the file mode.
  /// Returning a negative value from any callback aborts iteration
  /// and raises a [UserException].
  void foreach({
    int Function(DiffDelta delta, double progress)? onFile,
    int Function(DiffDelta delta, DiffHunk hunk)? onHunk,
    int Function(DiffDelta delta, DiffHunk? hunk, DiffLine line)? onLine,
  }) {
    diffForeach(
      _handle,
      onFile: onFile == null ? null : (d, p) => onFile(DiffDelta._(d), p),
      onHunk: onHunk == null
          ? null
          : (d, h) => onHunk(DiffDelta._(d), DiffHunk._(h)),
      onLine: onLine == null
          ? null
          : (d, h, l) => onLine(
              DiffDelta._(d),
              h == null ? null : DiffHunk._(h),
              DiffLine._(l),
            ),
    );
  }

  /// Formats this diff as UTF-8 text using [format].
  String toText([DiffFormat format = DiffFormat.patch]) =>
      diffToText(_handle, format.value);

  /// Iterates this diff, invoking [onLine] for every formatted line
  /// of output.
  ///
  /// Matches `git diff` console output. Returning a negative value
  /// from [onLine] aborts printing.
  void printLines(
    int Function(DiffDelta delta, DiffHunk? hunk, DiffLine line) onLine, {
    DiffFormat format = DiffFormat.patch,
  }) {
    diffPrint(
      _handle,
      format.value,
      (d, h, l) => onLine(
        DiffDelta._(d),
        h == null ? null : DiffHunk._(h),
        DiffLine._(l),
      ),
    );
  }

  /// Diffs [oldBlob] against [newBlob] directly, invoking the same
  /// callbacks as [foreach]; no [Diff] is allocated.
  ///
  /// Pass null for either side to represent the empty blob; passing
  /// null for both is a no-op. Because blobs lack context, the
  /// [DiffFile] passed to callbacks has a synthetic `mode` of 0 and
  /// null `path`. [oldAsPath] and [newAsPath] substitute filenames
  /// for attribute lookup. A binary-content check is run on each
  /// side; the hunk and line callbacks are skipped when either side
  /// is binary unless [DiffOption.forceText] is set.
  static void compareBlobs({
    Blob? oldBlob,
    String? oldAsPath,
    Blob? newBlob,
    String? newAsPath,
    DiffOptions? options,
    int Function(DiffDelta delta, double progress)? onFile,
    int Function(DiffDelta delta, DiffHunk hunk)? onHunk,
    int Function(DiffDelta delta, DiffHunk? hunk, DiffLine line)? onLine,
  }) {
    diffBlobs(
      oldBlob?._handle ?? 0,
      oldAsPath,
      newBlob?._handle ?? 0,
      newAsPath,
      options: options?._record,
      onFile: onFile == null ? null : (d, p) => onFile(DiffDelta._(d), p),
      onHunk: onHunk == null
          ? null
          : (d, h) => onHunk(DiffDelta._(d), DiffHunk._(h)),
      onLine: onLine == null
          ? null
          : (d, h, l) => onLine(
              DiffDelta._(d),
              h == null ? null : DiffHunk._(h),
              DiffLine._(l),
            ),
    );
  }

  /// Diffs [oldBlob] against the in-memory [newBuffer] directly.
  ///
  /// Pass null for [oldBlob] to emit an `added` delta covering the
  /// buffer contents; pass null for [newBuffer] to emit a `removed`
  /// delta covering the blob. Synthetic [DiffFile] data is supplied
  /// to callbacks as in [compareBlobs].
  static void compareBlobToBuffer({
    Blob? oldBlob,
    String? oldAsPath,
    Uint8List? newBuffer,
    String? newAsPath,
    DiffOptions? options,
    int Function(DiffDelta delta, double progress)? onFile,
    int Function(DiffDelta delta, DiffHunk hunk)? onHunk,
    int Function(DiffDelta delta, DiffHunk? hunk, DiffLine line)? onLine,
  }) {
    diffBlobToBuffer(
      oldBlob?._handle ?? 0,
      oldAsPath,
      newBuffer,
      newAsPath,
      options: options?._record,
      onFile: onFile == null ? null : (d, p) => onFile(DiffDelta._(d), p),
      onHunk: onHunk == null
          ? null
          : (d, h) => onHunk(DiffDelta._(d), DiffHunk._(h)),
      onLine: onLine == null
          ? null
          : (d, h, l) => onLine(
              DiffDelta._(d),
              h == null ? null : DiffHunk._(h),
              DiffLine._(l),
            ),
    );
  }

  /// Diffs two in-memory buffers directly. Behaves like
  /// [compareBlobs], with even less context — [DiffFile] parameters
  /// to callbacks are faked in the same way.
  static void compareBuffers({
    Uint8List? oldBuffer,
    String? oldAsPath,
    Uint8List? newBuffer,
    String? newAsPath,
    DiffOptions? options,
    int Function(DiffDelta delta, double progress)? onFile,
    int Function(DiffDelta delta, DiffHunk hunk)? onHunk,
    int Function(DiffDelta delta, DiffHunk? hunk, DiffLine line)? onLine,
  }) {
    diffBuffers(
      oldBuffer,
      oldAsPath,
      newBuffer,
      newAsPath,
      options: options?._record,
      onFile: onFile == null ? null : (d, p) => onFile(DiffDelta._(d), p),
      onHunk: onHunk == null
          ? null
          : (d, h) => onHunk(DiffDelta._(d), DiffHunk._(h)),
      onLine: onLine == null
          ? null
          : (d, h, l) => onLine(
              DiffDelta._(d),
              h == null ? null : DiffHunk._(h),
              DiffLine._(l),
            ),
    );
  }

  /// Stable patch id for this diff.
  ///
  /// Derived by hashing every file diff while ignoring whitespace
  /// and line numbers. Two diffs with the same patch id are, with
  /// high probability, the same change. Matches the id produced by
  /// `git patch-id`.
  Oid get patchId => Oid._(diffPatchId(_handle));

  /// Accumulated file and line counts for this diff. Callers must
  /// [DiffStats.dispose] the returned value.
  DiffStats get stats => DiffStats._(diffStatsNew(_handle));

  /// Releases the resources held by this diff.
  void dispose() {
    _finalizer.detach(this);
    diffFree(_handle);
  }
}

/// Options controlling diff generation.
@immutable
final class DiffOptions {
  /// Combination of [DiffOption] flags influencing the diff.
  final Set<DiffOption> flags;

  /// Overrides the submodule ignore setting for every submodule
  /// included in the diff.
  final SubmoduleIgnore ignoreSubmodules;

  /// Paths or fnmatch patterns constraining the diff to a subset of
  /// files.
  final List<String> pathspec;

  /// Number of unchanged lines shown around a hunk. Defaults to 3.
  final int contextLines;

  /// Maximum number of unchanged lines between two hunks before they
  /// are merged into one. Defaults to 0.
  final int interhunkLines;

  /// Abbreviation length used when formatting object ids in output.
  /// Zero uses the `core.abbrev` setting (defaults to 7).
  final int idAbbrev;

  /// Blob size above which a file is forced to binary classification.
  /// Negative disables the check. Defaults to 512 MB.
  final int maxSize;

  /// Virtual directory prefix prepended to old file names in diff
  /// headers.
  final String? oldPrefix;

  /// Virtual directory prefix prepended to new file names in diff
  /// headers.
  final String? newPrefix;

  const DiffOptions({
    this.flags = const {},
    this.ignoreSubmodules = SubmoduleIgnore.unspecified,
    this.pathspec = const [],
    this.contextLines = 3,
    this.interhunkLines = 0,
    this.idAbbrev = 0,
    this.maxSize = 512 * 1024 * 1024,
    this.oldPrefix,
    this.newPrefix,
  });

  DiffOptionsRecord get _record {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    return (
      flags: bits,
      ignoreSubmodules: ignoreSubmodules.value,
      pathspec: pathspec,
      contextLines: contextLines,
      interhunkLines: interhunkLines,
      idAbbrev: idAbbrev,
      maxSize: maxSize,
      oldPrefix: oldPrefix,
      newPrefix: newPrefix,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiffOptions &&
          _setEq(flags, other.flags) &&
          ignoreSubmodules == other.ignoreSubmodules &&
          _listEq(pathspec, other.pathspec) &&
          contextLines == other.contextLines &&
          interhunkLines == other.interhunkLines &&
          idAbbrev == other.idAbbrev &&
          maxSize == other.maxSize &&
          oldPrefix == other.oldPrefix &&
          newPrefix == other.newPrefix);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(flags),
    ignoreSubmodules,
    Object.hashAll(pathspec),
    contextLines,
    interhunkLines,
    idAbbrev,
    maxSize,
    oldPrefix,
    newPrefix,
  );
}

/// Options controlling [Diff.findSimilar] rename and copy detection.
@immutable
final class DiffFindOptions {
  /// Combination of [DiffFindOption] flags controlling detection.
  final Set<DiffFindOption> flags;

  /// Threshold above which similar files are considered renames.
  final int renameThreshold;

  /// Similarity below which a modified file becomes a rename
  /// source candidate.
  final int renameFromRewriteThreshold;

  /// Threshold above which similar files are considered copies.
  final int copyThreshold;

  /// Threshold below which a modified file is split into a
  /// delete/add pair.
  final int breakRewriteThreshold;

  /// Maximum number of rename candidates examined per target file.
  final int renameLimit;

  const DiffFindOptions({
    this.flags = const {DiffFindOption.findByConfig},
    this.renameThreshold = 50,
    this.renameFromRewriteThreshold = 50,
    this.copyThreshold = 50,
    this.breakRewriteThreshold = 60,
    this.renameLimit = 1000,
  });

  DiffFindOptionsRecord get _record {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    return (
      flags: bits,
      renameThreshold: renameThreshold,
      renameFromRewriteThreshold: renameFromRewriteThreshold,
      copyThreshold: copyThreshold,
      breakRewriteThreshold: breakRewriteThreshold,
      renameLimit: renameLimit,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiffFindOptions &&
          _setEq(flags, other.flags) &&
          renameThreshold == other.renameThreshold &&
          renameFromRewriteThreshold == other.renameFromRewriteThreshold &&
          copyThreshold == other.copyThreshold &&
          breakRewriteThreshold == other.breakRewriteThreshold &&
          renameLimit == other.renameLimit);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(flags),
    renameThreshold,
    renameFromRewriteThreshold,
    copyThreshold,
    breakRewriteThreshold,
    renameLimit,
  );
}

/// One side of a [DiffDelta] — either the old or the new version of
/// a path.
@immutable
final class DiffFile {
  /// [Oid] of the file; the zero [Oid] when the file is absent on
  /// this side.
  final Oid id;

  /// Path relative to the repository working directory.
  final String path;

  /// Size of the file in bytes.
  final int size;

  /// Combination of [DiffFlag] bits describing this file.
  final int flags;

  /// POSIX file mode.
  final int mode;

  /// Number of hex characters [id] was abbreviated to when the diff
  /// came from a patch file that stored a prefix.
  final int idAbbrev;

  const DiffFile._raw({
    required this.id,
    required this.path,
    required this.size,
    required this.flags,
    required this.mode,
    required this.idAbbrev,
  });

  factory DiffFile._(DiffFileRecord r) => DiffFile._raw(
    id: Oid._(r.id),
    path: r.path,
    size: r.size,
    flags: r.flags,
    mode: r.mode,
    idAbbrev: r.idAbbrev,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiffFile &&
          id == other.id &&
          path == other.path &&
          size == other.size &&
          flags == other.flags &&
          mode == other.mode);

  @override
  int get hashCode => Object.hash(id, path, size, flags, mode);
}

/// Describes changes to one entry in a [Diff].
@immutable
final class DiffDelta {
  /// How the path changed (added, deleted, modified, renamed, …).
  final DeltaStatus status;

  /// Combination of [DiffFlag] bits describing this delta.
  final int flags;

  /// Similarity score for renames and copies (0–100).
  final int similarity;

  /// Number of files involved in this delta.
  final int nfiles;

  /// Old side of the change — the "from" version of the path.
  final DiffFile oldFile;

  /// New side of the change — the "to" version of the path.
  final DiffFile newFile;

  const DiffDelta._raw({
    required this.status,
    required this.flags,
    required this.similarity,
    required this.nfiles,
    required this.oldFile,
    required this.newFile,
  });

  factory DiffDelta._(DiffDeltaRecord r) => DiffDelta._raw(
    status: DeltaStatus.fromValue(r.status),
    flags: r.flags,
    similarity: r.similarity,
    nfiles: r.nfiles,
    oldFile: DiffFile._(r.oldFile),
    newFile: DiffFile._(r.newFile),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiffDelta &&
          status == other.status &&
          flags == other.flags &&
          similarity == other.similarity &&
          nfiles == other.nfiles &&
          oldFile == other.oldFile &&
          newFile == other.newFile);

  @override
  int get hashCode =>
      Object.hash(status, flags, similarity, nfiles, oldFile, newFile);
}

/// A contiguous range of modified lines within a [DiffDelta].
@immutable
final class DiffHunk {
  /// Starting line number in the old file.
  final int oldStart;

  /// Number of lines from the old file in this hunk.
  final int oldLines;

  /// Starting line number in the new file.
  final int newStart;

  /// Number of lines from the new file in this hunk.
  final int newLines;

  /// `@@` header text, including surrounding context identifiers.
  final String header;

  const DiffHunk._raw({
    required this.oldStart,
    required this.oldLines,
    required this.newStart,
    required this.newLines,
    required this.header,
  });

  factory DiffHunk._(DiffHunkRecord r) => DiffHunk._raw(
    oldStart: r.oldStart,
    oldLines: r.oldLines,
    newStart: r.newStart,
    newLines: r.newLines,
    header: r.header,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiffHunk &&
          oldStart == other.oldStart &&
          oldLines == other.oldLines &&
          newStart == other.newStart &&
          newLines == other.newLines &&
          header == other.header);

  @override
  int get hashCode =>
      Object.hash(oldStart, oldLines, newStart, newLines, header);
}

/// A single line within a [DiffHunk].
@immutable
final class DiffLine {
  /// Origin marker (`+`, `-`, ` `, …) recorded as a code unit.
  ///
  /// Values match [DiffLineOrigin].
  final int origin;

  /// Line number in the old file, or -1 for added lines.
  final int oldLineno;

  /// Line number in the new file, or -1 for deleted lines.
  final int newLineno;

  /// Number of newline characters in [content].
  final int numLines;

  /// Byte offset of [content] within the file it came from.
  final int contentOffset;

  /// Raw line bytes; not null-terminated.
  final Uint8List content;

  const DiffLine._raw({
    required this.origin,
    required this.oldLineno,
    required this.newLineno,
    required this.numLines,
    required this.contentOffset,
    required this.content,
  });

  factory DiffLine._(DiffLineRecord r) => DiffLine._raw(
    origin: r.origin,
    oldLineno: r.oldLineno,
    newLineno: r.newLineno,
    numLines: r.numLines,
    contentOffset: r.contentOffset,
    content: r.content,
  );

  /// The origin marker as a character (`+`, `-`, ` `, …).
  String get originChar => String.fromCharCode(origin);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiffLine &&
          origin == other.origin &&
          oldLineno == other.oldLineno &&
          newLineno == other.newLineno &&
          numLines == other.numLines &&
          contentOffset == other.contentOffset &&
          _listEq(content, other.content));

  @override
  int get hashCode => Object.hash(
    origin,
    oldLineno,
    newLineno,
    numLines,
    contentOffset,
    Object.hashAll(content),
  );
}

/// Accumulated file and line counts for every delta in a [Diff].
///
/// Owns a native resource; call [dispose] when finished.
@immutable
final class DiffStats {
  static final _finalizer = Finalizer<int>(diffStatsFree);

  final int _handle;

  DiffStats._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Total number of files changed in the diff.
  int get filesChanged => diffStatsFilesChanged(_handle);

  /// Total number of inserted lines across every delta.
  int get insertions => diffStatsInsertions(_handle);

  /// Total number of deleted lines across every delta.
  int get deletions => diffStatsDeletions(_handle);

  /// Formats the stats using [format] and a target column width.
  ///
  /// [width] only affects [DiffStatsFormat.full] output.
  String toText({
    DiffStatsFormat format = DiffStatsFormat.full,
    int width = 80,
  }) => diffStatsToText(_handle, format.value, width);

  /// Releases the resources held by these stats.
  void dispose() {
    _finalizer.detach(this);
    diffStatsFree(_handle);
  }
}
