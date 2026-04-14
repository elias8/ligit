part of 'api.dart';

/// Graph-reachability queries on [Repository].
extension RepositoryGraph on Repository {
  /// Counts the number of unique commits between two commits.
  ///
  /// `ahead` is the number of commits [local] has that [upstream]
  /// does not; `behind` is the number of commits [upstream] has that
  /// [local] does not. The two commits do not have to be on branches
  /// — thinking of one as a branch and the other as its upstream is
  /// just the usual case, and the values correspond to what git
  /// would report in that scenario.
  ({int ahead, int behind}) aheadBehind(Oid local, Oid upstream) {
    return graphAheadBehind(_handle, local._bytes, upstream._bytes);
  }

  /// Whether [commit] is a descendant of [ancestor].
  ///
  /// A commit is not considered a descendant of itself, in contrast
  /// to `git merge-base --is-ancestor`.
  bool descendantOf({required Oid commit, required Oid ancestor}) {
    return graphDescendantOf(_handle, commit._bytes, ancestor._bytes);
  }

  /// Whether [commit] is reachable from any of [descendants] by
  /// following parent edges.
  bool reachableFromAny(Oid commit, List<Oid> descendants) {
    return graphReachableFromAny(_handle, commit._bytes, [
      for (final d in descendants) d._bytes,
    ]);
  }
}
