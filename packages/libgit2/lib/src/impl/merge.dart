part of 'api.dart';

Set<MergeAnalysis> _decodeAnalysis(int bits) {
  return {
    for (final v in MergeAnalysis.values)
      if (v != MergeAnalysis.none && (bits & v.value) != 0) v,
  };
}

/// Merge analysis, merge base discovery, and tree, commit, and file
/// merge routines.
///
/// Every entry point is static: merge operations do not own any
/// native resource of their own — they either return an [Index] the
/// caller operates on, write changes through to HEAD, or produce a
/// [MergeFileResult].
///
/// ```dart
/// final theirs = AnnotatedCommit.fromRevSpec(repo, 'feature');
/// try {
///   final (:analysis, :preference) = Merge.analysis(repo, [theirs]);
///   if (analysis.contains(MergeAnalysis.fastforward)) {
///     // fast-forward is possible
///   } else if (analysis.contains(MergeAnalysis.normal)) {
///     Merge.intoHead(repo: repo, theirHeads: [theirs]);
///   }
/// } finally {
///   theirs.dispose();
/// }
/// ```
abstract final class Merge {
  /// Default number of marker characters in a conflict line
  /// (`<<<<<<<`, `=======`, `>>>>>>>`).
  static const conflictMarkerSize = mergeConflictMarkerSize;

  /// Analyzes how [theirHeads] could be merged into HEAD.
  ///
  /// Returns the analysis bits ([MergeAnalysis.normal],
  /// [MergeAnalysis.upToDate], [MergeAnalysis.fastforward], and
  /// [MergeAnalysis.unborn]) along with the user's configured merge
  /// preference.
  static ({Set<MergeAnalysis> analysis, MergePreference preference}) analysis(
    Repository repo,
    List<AnnotatedCommit> theirHeads,
  ) {
    final r = mergeAnalysis(repo._handle, [
      for (final h in theirHeads) h._handle,
    ]);
    return (
      analysis: _decodeAnalysis(r.analysis),
      preference: MergePreference.fromValue(r.preference),
    );
  }

  /// Analyzes how [theirHeads] could be merged into the reference
  /// [ourRef].
  static ({Set<MergeAnalysis> analysis, MergePreference preference})
  analysisForRef(
    Repository repo,
    Reference ourRef,
    List<AnnotatedCommit> theirHeads,
  ) {
    final r = mergeAnalysisForRef(repo._handle, ourRef._handle, [
      for (final h in theirHeads) h._handle,
    ]);
    return (
      analysis: _decodeAnalysis(r.analysis),
      preference: MergePreference.fromValue(r.preference),
    );
  }

  /// Finds a merge base between commits [one] and [two].
  ///
  /// Returns null when the commits share no common ancestor.
  static Oid? base(Repository repo, Oid one, Oid two) {
    final bytes = mergeBase(repo._handle, one._bytes, two._bytes);
    return bytes == null ? null : Oid._(bytes);
  }

  /// Finds a merge base considering every commit in [inputs].
  ///
  /// Returns null when no base exists.
  static Oid? baseMany(Repository repo, List<Oid> inputs) {
    final bytes = mergeBaseMany(repo._handle, [
      for (final o in inputs) o._bytes,
    ]);
    return bytes == null ? null : Oid._(bytes);
  }

  /// Finds a merge base in preparation for an octopus merge of
  /// [inputs]. Returns null when no base exists.
  static Oid? baseOctopus(Repository repo, List<Oid> inputs) {
    final bytes = mergeBaseOctopus(repo._handle, [
      for (final o in inputs) o._bytes,
    ]);
    return bytes == null ? null : Oid._(bytes);
  }

  /// Returns every merge base between commits [one] and [two].
  static List<Oid> bases(Repository repo, Oid one, Oid two) {
    return [
      for (final b in mergeBases(repo._handle, one._bytes, two._bytes))
        Oid._(b),
    ];
  }

  /// Returns every merge base considering every commit in [inputs].
  static List<Oid> basesMany(Repository repo, List<Oid> inputs) {
    return [
      for (final b in mergeBasesMany(repo._handle, [
        for (final o in inputs) o._bytes,
      ]))
        Oid._(b),
    ];
  }

  /// Three-way merges the trees of [ours] and [theirs], producing an
  /// [Index] that reflects the result.
  ///
  /// The common ancestor is discovered automatically. The returned
  /// index may carry conflicts; resolve them and write a tree with
  /// [Index.writeTree] before committing. Callers must
  /// [Index.dispose] the returned index.
  static Index commits({
    required Repository repo,
    required Commit ours,
    required Commit theirs,
    MergeOptions? options,
  }) {
    return Index._(
      mergeCommits(
        repo._handle,
        ours._handle,
        theirs._handle,
        options: options?._record,
      ),
    );
  }

  /// Three-way merges three in-memory file buffers, using [ancestor]
  /// as the baseline.
  ///
  /// This entry point does not consult any repository; every setting
  /// must be supplied through [options].
  static MergeFileResult file({
    required MergeFileInput ancestor,
    required MergeFileInput ours,
    required MergeFileInput theirs,
    MergeFileOptions? options,
  }) {
    return MergeFileResult._(
      mergeFile(
        ancestor._record,
        ours._record,
        theirs._record,
        options: options?._record,
      ),
    );
  }

  /// Three-way merges three index entries, using [ancestor] (stage
  /// 1) as the baseline, [ours] (stage 2) and [theirs] (stage 3) as
  /// the two sides.
  ///
  /// Any side may be null to indicate the file was absent in that
  /// tree.
  static MergeFileResult fileFromIndex({
    required Repository repo,
    IndexEntry? ancestor,
    IndexEntry? ours,
    IndexEntry? theirs,
    MergeFileOptions? options,
  }) => MergeFileResult._(
    mergeFileFromIndex(
      repo._handle,
      ancestor: ancestor?._record,
      ours: ours?._record,
      theirs: theirs?._record,
      options: options?._record,
    ),
  );

  /// Merges [theirHeads] into HEAD, writing the result into the
  /// working directory and staging the changes.
  ///
  /// Conflicts are written into the index as stage-2/3 entries —
  /// inspect the repository's index afterwards to resolve them and
  /// prepare a commit. On success the repository is left in the
  /// `merging` state; clear it with [Repository.stateCleanup] once
  /// the commit is done or the user aborts.
  static void intoHead({
    required Repository repo,
    required List<AnnotatedCommit> theirHeads,
    MergeOptions? options,
    Set<CheckoutStrategy> checkoutStrategy = const {},
    List<String> checkoutPaths = const [],
  }) {
    var strategy = 0;
    for (final s in checkoutStrategy) {
      strategy |= s.value;
    }
    merge(
      repo._handle,
      [for (final h in theirHeads) h._handle],
      mergeOptions: options?._record,
      checkoutStrategy: strategy,
      checkoutPaths: checkoutPaths,
    );
  }

  /// Three-way merges three trees, producing an [Index] that
  /// reflects the result.
  ///
  /// Pass null for [ancestor] for an unrelated-histories merge. The
  /// returned index may carry conflicts — resolve them and write a
  /// tree with [Index.writeTree] before committing. Callers must
  /// [Index.dispose] the returned index.
  static Index trees({
    required Repository repo,
    Tree? ancestor,
    required Tree ours,
    required Tree theirs,
    MergeOptions? options,
  }) {
    return Index._(
      mergeTrees(
        repo._handle,
        ancestor?._handle ?? 0,
        ours._handle,
        theirs._handle,
        options: options?._record,
      ),
    );
  }
}

/// One side of a file-level merge: the file's raw contents and the
/// metadata used to stamp the result.
@immutable
final class MergeFileInput {
  /// Raw bytes of this side of the file.
  final Uint8List contents;

  /// Path of the file, or null to skip path-based resolution.
  final String? path;

  /// POSIX file mode, or `0` to skip mode-based resolution.
  final int mode;

  const MergeFileInput({required this.contents, this.path, this.mode = 0});

  MergeFileInputRecord get _record =>
      (contents: contents, path: path, mode: mode);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MergeFileInput &&
          _listEq(contents, other.contents) &&
          path == other.path &&
          mode == other.mode);

  @override
  int get hashCode => Object.hash(Object.hashAll(contents), path, mode);
}

/// Options for file-level merges.
@immutable
final class MergeFileOptions {
  /// Label prepended to the ancestor side in diff3-style output.
  final String? ancestorLabel;

  /// Label prepended to our side in conflict output.
  final String? ourLabel;

  /// Label prepended to their side in conflict output.
  final String? theirLabel;

  /// Strategy used to resolve region-level conflicts.
  final MergeFileFavor favor;

  /// Combination of [MergeFileFlag] bits controlling file-level
  /// merge behavior.
  final Set<MergeFileFlag> flags;

  /// Number of marker characters (`<<<<<<<`, `=======`, `>>>>>>>`).
  final int markerSize;

  const MergeFileOptions({
    this.ancestorLabel,
    this.ourLabel,
    this.theirLabel,
    this.favor = MergeFileFavor.normal,
    this.flags = const {},
    this.markerSize = Merge.conflictMarkerSize,
  });

  MergeFileOptionsRecord get _record {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    return (
      ancestorLabel: ancestorLabel,
      ourLabel: ourLabel,
      theirLabel: theirLabel,
      favor: favor.value,
      flags: bits,
      markerSize: markerSize,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MergeFileOptions &&
          ancestorLabel == other.ancestorLabel &&
          ourLabel == other.ourLabel &&
          theirLabel == other.theirLabel &&
          favor == other.favor &&
          _setEq(flags, other.flags) &&
          markerSize == other.markerSize);

  @override
  int get hashCode => Object.hash(
    ancestorLabel,
    ourLabel,
    theirLabel,
    favor,
    Object.hashAllUnordered(flags),
    markerSize,
  );
}

/// Outcome of a file-level merge.
@immutable
final class MergeFileResult {
  /// Whether the merge produced a clean result with no conflict
  /// markers.
  final bool automergeable;

  /// Target path of the merged file, or null when the paths on the
  /// two sides collided.
  final String? path;

  /// POSIX mode selected for the merged file.
  final int mode;

  /// Raw bytes of the merged file, including any conflict markers.
  final Uint8List contents;

  factory MergeFileResult._(MergeFileResultRecord r) => MergeFileResult._raw(
    automergeable: r.automergeable,
    path: r.path,
    mode: r.mode,
    contents: r.contents,
  );

  const MergeFileResult._raw({
    required this.automergeable,
    required this.path,
    required this.mode,
    required this.contents,
  });

  @override
  int get hashCode =>
      Object.hash(automergeable, path, mode, Object.hashAll(contents));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MergeFileResult &&
          automergeable == other.automergeable &&
          path == other.path &&
          mode == other.mode &&
          _listEq(contents, other.contents));
}

/// Options for tree- and commit-level merges.
@immutable
final class MergeOptions {
  /// Combination of [MergeFlag] bits driving the overall merge.
  final Set<MergeFlag> flags;

  /// Similarity above which add/delete pairs are matched as renames.
  /// Defaults to 50. Only consulted when [MergeFlag.findRenames] is
  /// set.
  final int renameThreshold;

  /// Maximum number of add/delete pairs examined for rename
  /// detection. Defaults to 200.
  final int targetLimit;

  /// Maximum number of virtual ancestors generated when resolving
  /// criss-cross merges. Zero means unlimited.
  final int recursionLimit;

  /// Name of the merge driver consulted when both sides of the merge
  /// change. Null uses the default `text` driver.
  final String? defaultDriver;

  /// Strategy the text driver uses to resolve region-level file
  /// conflicts.
  final MergeFileFavor fileFavor;

  /// File-level merge flags controlling whitespace handling, diff
  /// algorithm, and conflict marker style.
  final Set<MergeFileFlag> fileFlags;

  const MergeOptions({
    this.flags = const {MergeFlag.findRenames},
    this.renameThreshold = 50,
    this.targetLimit = 200,
    this.recursionLimit = 0,
    this.defaultDriver,
    this.fileFavor = MergeFileFavor.normal,
    this.fileFlags = const {},
  });

  MergeOptionsRecord get _record {
    var flagBits = 0;
    for (final f in flags) {
      flagBits |= f.value;
    }
    var fileFlagBits = 0;
    for (final f in fileFlags) {
      fileFlagBits |= f.value;
    }
    return (
      flags: flagBits,
      renameThreshold: renameThreshold,
      targetLimit: targetLimit,
      recursionLimit: recursionLimit,
      defaultDriver: defaultDriver,
      fileFavor: fileFavor.value,
      fileFlags: fileFlagBits,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MergeOptions &&
          _setEq(flags, other.flags) &&
          renameThreshold == other.renameThreshold &&
          targetLimit == other.targetLimit &&
          recursionLimit == other.recursionLimit &&
          defaultDriver == other.defaultDriver &&
          fileFavor == other.fileFavor &&
          _setEq(fileFlags, other.fileFlags));

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(flags),
    renameThreshold,
    targetLimit,
    recursionLimit,
    defaultDriver,
    fileFavor,
    Object.hashAllUnordered(fileFlags),
  );
}
