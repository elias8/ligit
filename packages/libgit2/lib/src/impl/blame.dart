part of 'api.dart';

/// A blame hunk: a contiguous run of lines last touched by the same
/// commit.
///
/// [BlameHunk] is a pure Dart value; every field is copied out of
/// libgit2's buffers at construction time so it outlives the
/// parent [Blame].
@immutable
final class BlameHunk {
  /// Number of lines in this hunk.
  final int lineCount;

  /// OID of the commit that last changed these lines.
  final Oid finalCommitId;

  /// 1-based line number where this hunk begins in the final
  /// version of the file.
  final int finalStartLine;

  /// Author of the commit that last changed these lines. Maps
  /// through mailmap when [BlameFlag.useMailmap] was set.
  final Signature finalAuthor;

  /// Committer of the commit that last changed these lines. Maps
  /// through mailmap when [BlameFlag.useMailmap] was set.
  final Signature finalCommitter;

  /// OID of the commit where this hunk was found; usually identical
  /// to [finalCommitId] except under rename/copy tracking.
  final Oid origCommitId;

  /// Path to the file where this hunk originated in [origCommitId].
  final String origPath;

  /// 1-based line number where this hunk begins in [origPath] at
  /// [origCommitId].
  final int origStartLine;

  /// Author of [origCommitId], or `null` when the origin commit
  /// could not be resolved.
  final Signature? origAuthor;

  /// Committer of [origCommitId], or `null` when the origin commit
  /// could not be resolved.
  final Signature? origCommitter;

  /// One-line summary of the commit that introduced this hunk.
  final String summary;

  /// Whether this hunk reaches the blame's boundary — the root of
  /// history or the `oldestCommit` bound.
  final bool isBoundary;

  const BlameHunk._({
    required this.lineCount,
    required this.finalCommitId,
    required this.finalStartLine,
    required this.finalAuthor,
    required this.finalCommitter,
    required this.origCommitId,
    required this.origPath,
    required this.origStartLine,
    required this.origAuthor,
    required this.origCommitter,
    required this.summary,
    required this.isBoundary,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlameHunk &&
          lineCount == other.lineCount &&
          finalCommitId == other.finalCommitId &&
          finalStartLine == other.finalStartLine &&
          finalAuthor == other.finalAuthor &&
          finalCommitter == other.finalCommitter &&
          origCommitId == other.origCommitId &&
          origPath == other.origPath &&
          origStartLine == other.origStartLine &&
          origAuthor == other.origAuthor &&
          origCommitter == other.origCommitter &&
          summary == other.summary &&
          isBoundary == other.isBoundary);

  @override
  int get hashCode => Object.hash(
    lineCount,
    finalCommitId,
    finalStartLine,
    finalAuthor,
    finalCommitter,
    origCommitId,
    origPath,
    origStartLine,
    origAuthor,
    origCommitter,
    summary,
    isBoundary,
  );

  @override
  String toString() => 'BlameHunk($finalCommitId @ $finalStartLine)';
}

/// Line-level blame annotations for a single file.
///
/// Build one with [Blame.file] (or [Blame.fileFromBuffer] when the
/// working copy has local edits) and enumerate the hunks through
/// [length] and [hunk], or look up a hunk by line with
/// [hunkForLine]. Use [Blame.withBuffer] to update a cached blame
/// when the user edits the file in memory.
///
/// Owns a native handle; must be [dispose]d.
///
/// ```dart
/// final blame = Blame.file(repo, 'lib/main.dart');
/// try {
///   for (var i = 0; i < blame.length; i++) {
///     final h = blame.hunk(i)!;
///     print('${h.finalCommitId} ${h.finalAuthor.name}: '
///         '${h.lineCount} line(s) @ ${h.finalStartLine}');
///   }
/// } finally {
///   blame.dispose();
/// }
/// ```
@immutable
final class Blame {
  static final _finalizer = Finalizer<int>(blameFree);

  final int _handle;

  /// Blames [path] in [repo].
  factory Blame.file(
    Repository repo,
    String path, {
    Set<BlameFlag> flags = const {},
    int minMatchCharacters = 0,
    Oid? newestCommit,
    Oid? oldestCommit,
    int minLine = 0,
    int maxLine = 0,
  }) {
    return Blame._(
      blameFile(
        repo._handle,
        path,
        flags: _bits(flags),
        minMatchCharacters: minMatchCharacters,
        newestCommit: newestCommit?._bytes,
        oldestCommit: oldestCommit?._bytes,
        minLine: minLine,
        maxLine: maxLine,
      ),
    );
  }

  /// Rebuilds this blame against [buffer], reusing the committed
  /// analysis of [base].
  ///
  /// Fast once [base] has been computed. Lines that differ from
  /// any committed version appear with a zero [BlameHunk.finalCommitId].
  factory Blame.withBuffer(Blame base, String buffer) =>
      Blame._(blameBuffer(base._handle, buffer));

  /// Blames the in-memory [buffer] as if it were committed at [path]
  /// in [repo].
  ///
  /// Use this when a file exists only in memory (e.g. pre-commit
  /// preview) and you need a full blame rather than the incremental
  /// update provided by [Blame.withBuffer].
  factory Blame.fileFromBuffer(
    Repository repo,
    String path,
    String buffer, {
    Set<BlameFlag> flags = const {},
    int minMatchCharacters = 0,
    Oid? newestCommit,
    Oid? oldestCommit,
    int minLine = 0,
    int maxLine = 0,
  }) {
    return Blame._(
      blameFileFromBuffer(
        repo._handle,
        path,
        buffer,
        flags: _bits(flags),
        minMatchCharacters: minMatchCharacters,
        newestCommit: newestCommit?._bytes,
        oldestCommit: oldestCommit?._bytes,
        minLine: minLine,
        maxLine: maxLine,
      ),
    );
  }

  Blame._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Number of hunks in the blame.
  int get length => blameHunkCount(_handle);

  /// Total number of lines the blame covers.
  int get lineCount => blameLineCount(_handle);

  /// Reads the hunk at [index] (0-based), or `null` when out of
  /// range.
  BlameHunk? hunk(int index) {
    final raw = blameHunkByIndex(_handle, index);
    return raw == null ? null : _hunk(raw);
  }

  /// Reads the hunk covering [lineNumber] (1-based), or `null` when
  /// no hunk matches.
  BlameHunk? hunkForLine(int lineNumber) {
    final raw = blameHunkByLine(_handle, lineNumber);
    return raw == null ? null : _hunk(raw);
  }

  /// Reads the content of line [index] (1-based), or `null` when
  /// out of range.
  String? line(int index) => blameLineByIndex(_handle, index);

  /// Releases the native blame handle.
  void dispose() {
    _finalizer.detach(this);
    blameFree(_handle);
  }

  static int _bits(Set<BlameFlag> flags) {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    return bits;
  }

  static Signature _sigFrom(
    ({String name, String email, int time, int offset}) r,
  ) {
    return Signature._(
      name: r.name,
      email: r.email,
      when: DateTime.fromMillisecondsSinceEpoch(r.time * 1000, isUtc: true),
      offset: r.offset,
    );
  }

  static BlameHunk _hunk(
    ({
      int linesInHunk,
      Uint8List finalCommitId,
      int finalStartLineNumber,
      ({String name, String email, int time, int offset}) finalSignature,
      ({String name, String email, int time, int offset}) finalCommitter,
      Uint8List origCommitId,
      String origPath,
      int origStartLineNumber,
      ({String name, String email, int time, int offset})? origSignature,
      ({String name, String email, int time, int offset})? origCommitter,
      String summary,
      bool boundary,
    })
    raw,
  ) {
    return BlameHunk._(
      lineCount: raw.linesInHunk,
      finalCommitId: Oid._(raw.finalCommitId),
      finalStartLine: raw.finalStartLineNumber,
      finalAuthor: _sigFrom(raw.finalSignature),
      finalCommitter: _sigFrom(raw.finalCommitter),
      origCommitId: Oid._(raw.origCommitId),
      origPath: raw.origPath,
      origStartLine: raw.origStartLineNumber,
      origAuthor: raw.origSignature == null
          ? null
          : _sigFrom(raw.origSignature!),
      origCommitter: raw.origCommitter == null
          ? null
          : _sigFrom(raw.origCommitter!),
      summary: raw.summary,
      isBoundary: raw.boundary,
    );
  }
}
