part of 'api.dart';

/// Cherry-pick routines on a [Repository].
extension RepositoryCherryPick on Repository {
  /// Cherry-picks [commit] onto HEAD, producing changes in the
  /// index and the working directory.
  ///
  /// [mainline] selects which parent of [commit] to treat as the
  /// base when [commit] is a merge (1-based; pass `0` for non-merge
  /// commits).
  ///
  /// Throws [ConflictException] when conflicts prevent the
  /// cherry-pick.
  void cherryPick(Commit commit, {int mainline = 0}) {
    cp.cherryPick(_handle, commit._handle, mainline: mainline);
  }

  /// Cherry-picks [commit] against [ours], returning an [Index] that
  /// reflects the result without touching the working directory.
  ///
  /// Useful for previewing whether a cherry-pick would conflict
  /// before applying it (for example, against HEAD). [mainline]
  /// selects which parent of [commit] to treat as the base when
  /// [commit] is a merge (1-based; pass `0` for non-merge commits).
  ///
  /// Callers must [Index.dispose] the returned index.
  Index cherryPickCommit(Commit commit, Commit ours, {int mainline = 0}) {
    final handle = cp.cherryPickCommit(
      _handle,
      commit._handle,
      ours._handle,
      mainline: mainline,
    );
    return Index._(handle);
  }
}
