part of 'api.dart';

/// The text diff for a single [DiffDelta].
///
/// A [Patch] stores all the text changes for one entry in a [Diff] —
/// every hunk, each hunk's metadata, and every line within them. It
/// is the object that knows *how* each file changed, while [Diff]
/// knows *which* files changed.
///
/// Owns a native resource; call [dispose] when finished.
@immutable
final class Patch {
  static final _finalizer = Finalizer<int>(patchFree);

  final int _handle;

  /// Generates a patch directly from the difference between an
  /// [oldBlob] and the in-memory [buffer].
  ///
  /// Pass null for [oldBlob] to use the empty blob. [oldAsPath] and
  /// [bufferAsPath] substitute virtual filenames used for attribute
  /// lookup.
  factory Patch.fromBlobAndBuffer({
    Blob? oldBlob,
    required Uint8List buffer,
    String? oldAsPath,
    String? bufferAsPath,
    DiffOptions? options,
  }) => Patch._(
    patchFromBlobAndBuffer(
      oldBlob?._handle ?? 0,
      buffer,
      oldAsPath: oldAsPath,
      bufferAsPath: bufferAsPath,
      options: options?._record,
    ),
  );

  /// Generates a patch directly from the difference between two
  /// blobs.
  ///
  /// Pass null for either side to represent the empty blob.
  /// [oldAsPath] and [newAsPath] substitute virtual filenames used
  /// for attribute lookup.
  factory Patch.fromBlobs({
    Blob? oldBlob,
    Blob? newBlob,
    String? oldAsPath,
    String? newAsPath,
    DiffOptions? options,
  }) => Patch._(
    patchFromBlobs(
      oldBlob?._handle ?? 0,
      newBlob?._handle ?? 0,
      oldAsPath: oldAsPath,
      newAsPath: newAsPath,
      options: options?._record,
    ),
  );

  /// Generates a patch directly from the difference between two
  /// in-memory buffers.
  factory Patch.fromBuffers({
    required Uint8List oldBuffer,
    required Uint8List newBuffer,
    String? oldAsPath,
    String? newAsPath,
    DiffOptions? options,
  }) => Patch._(
    patchFromBuffers(
      oldBuffer,
      newBuffer,
      oldAsPath: oldAsPath,
      newAsPath: newAsPath,
      options: options?._record,
    ),
  );

  /// Returns the patch for entry [position] of [diff].
  ///
  /// Unchanged files and binary deltas produce no patch; this
  /// constructor throws [StateError] in that case. Iterate [Diff]
  /// itself to inspect such entries without triggering this error.
  factory Patch.fromDiff(Diff diff, int position) {
    final handle = patchFromDiff(diff._handle, position);
    if (handle == 0) {
      throw StateError('no patch available for delta $position');
    }
    return Patch._(handle);
  }

  Patch._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// The delta associated with this patch, or null when the patch
  /// is detached (for example, produced directly from buffers).
  DiffDelta? get delta {
    final r = patchGetDelta(_handle);
    return r == null ? null : DiffDelta._(r);
  }

  /// Serializes this patch to text, invoking [onLine] for every file
  /// header, hunk header, and diff line.
  ///
  /// Returning a negative value aborts printing.
  void printLines(
    int Function(DiffDelta delta, DiffHunk? hunk, DiffLine line) onLine,
  ) {
    patchPrint(
      _handle,
      (d, h, l) => onLine(
        DiffDelta._(d),
        h == null ? null : DiffHunk._(h),
        DiffLine._(l),
      ),
    );
  }

  /// Context, addition, and deletion line counts across every hunk.
  ///
  /// Matches a `git diff --numstat`-style breakdown.
  ({int context, int additions, int deletions}) get lineStats =>
      patchLineStats(_handle);

  /// Number of hunks in this patch.
  int get numHunks => patchNumHunks(_handle);

  /// Releases the resources held by this patch.
  void dispose() {
    _finalizer.detach(this);
    patchFree(_handle);
  }

  /// Returns the hunk at [hunkIndex] along with the total number of
  /// lines it contains.
  ({DiffHunk hunk, int lines}) getHunk(int hunkIndex) {
    final r = patchGetHunk(_handle, hunkIndex);
    return (hunk: DiffHunk._(r.hunk), lines: r.lines);
  }

  /// Returns line [lineOfHunk] from the hunk at [hunkIndex].
  DiffLine getLineInHunk(int hunkIndex, int lineOfHunk) =>
      DiffLine._(patchGetLineInHunk(_handle, hunkIndex, lineOfHunk));

  /// Number of lines in the hunk at [hunkIndex].
  int numLinesInHunk(int hunkIndex) => patchNumLinesInHunk(_handle, hunkIndex);

  /// Raw size of the patch data in bytes.
  ///
  /// Only counts the data on the diff lines themselves. Pass false
  /// for [includeContext] to exclude context lines (as if
  /// `contextLines` were 0); pass false for [includeHunkHeaders] or
  /// [includeFileHeaders] to exclude the `@@` or `diff --git` lines.
  int size({
    bool includeContext = true,
    bool includeHunkHeaders = true,
    bool includeFileHeaders = true,
  }) => patchSize(
    _handle,
    includeContext: includeContext,
    includeHunkHeaders: includeHunkHeaders,
    includeFileHeaders: includeFileHeaders,
  );

  /// Returns the full content of this patch as a single UTF-8 diff
  /// string.
  String toText() => patchToText(_handle);
}
