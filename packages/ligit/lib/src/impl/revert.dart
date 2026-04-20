part of 'api.dart';

/// Revert routines on a [Repository].
extension RepositoryRevert on Repository {
  /// Reverts [commit] against HEAD, producing changes in the index
  /// and the working directory.
  ///
  /// [mainline] selects which parent of [commit] to treat as the
  /// base when [commit] is a merge (1-based; pass `0` for non-merge
  /// commits).
  ///
  /// Throws [ConflictException] when conflicts prevent the revert.
  void revert(Commit commit, {int mainline = 0}) {
    rv.revert(_handle, commit._handle, mainline: mainline);
  }

  /// Reverts [commit] against [ours], returning an [Index] that
  /// reflects the result without touching the working directory.
  ///
  /// Useful for previewing a revert before applying it (for example,
  /// against HEAD). [mainline] selects which parent of [commit] to
  /// treat as the base when [commit] is a merge (1-based; pass `0`
  /// for non-merge commits).
  ///
  /// Callers must [Index.dispose] the returned index.
  Index revertCommit(Commit commit, Commit ours, {int mainline = 0}) {
    final handle = rv.revertCommit(
      _handle,
      commit._handle,
      ours._handle,
      mainline: mainline,
    );
    return Index._(handle);
  }
}
