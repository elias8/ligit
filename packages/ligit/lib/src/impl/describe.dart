part of 'api.dart';

/// The result of a `git describe` operation.
///
/// Describes a commit by finding the most recent tag reachable from
/// it and reporting its position relative to that tag. Obtain one
/// through [DescribeResult.commit] or [DescribeResult.workdir], then
/// render it with [format].
///
/// Must be [dispose]d when done.
///
/// ```dart
/// final desc = DescribeResult.workdir(repo);
/// try {
///   print(desc.format());                          // v1.2.0-3-gabcdef0
///   print(desc.format(dirtySuffix: '-dirty'));
/// } finally {
///   desc.dispose();
/// }
/// ```
@immutable
final class DescribeResult {
  static final _finalizer = Finalizer<int>(describeResultFree);

  final int _handle;

  /// Describes [commit] relative to nearby tags.
  ///
  /// [maxCandidatesTags] caps the number of candidate tags
  /// considered (default 10). [strategy] widens the lookup to every
  /// tag or every reference. [pattern] restricts candidates to names
  /// matching a glob. Set [onlyFollowFirstParent] to measure
  /// distance along the first-parent ancestry only. Set
  /// [showCommitOidAsFallback] to render a bare OID when no
  /// candidate tag is found instead of failing.
  factory DescribeResult.commit(
    GitObject commit, {
    int maxCandidatesTags = 10,
    DescribeStrategy strategy = DescribeStrategy.default$,
    String? pattern,
    bool onlyFollowFirstParent = false,
    bool showCommitOidAsFallback = false,
  }) {
    return DescribeResult._(
      describeCommit(
        commit._handle,
        maxCandidatesTags: maxCandidatesTags,
        strategy: strategy,
        pattern: pattern,
        onlyFollowFirstParent: onlyFollowFirstParent,
        showCommitOidAsFallback: showCommitOidAsFallback,
      ),
    );
  }

  /// Describes the current HEAD of [repo] against nearby tags.
  ///
  /// After describing HEAD, a status is run and the description is
  /// considered dirty when the working tree has uncommitted changes
  /// — render that suffix by passing [DescribeResult.format]'s
  /// `dirtySuffix`.
  ///
  /// See [DescribeResult.commit] for the meaning of the remaining
  /// options.
  factory DescribeResult.workdir(
    Repository repo, {
    int maxCandidatesTags = 10,
    DescribeStrategy strategy = DescribeStrategy.default$,
    String? pattern,
    bool onlyFollowFirstParent = false,
    bool showCommitOidAsFallback = false,
  }) {
    return DescribeResult._(
      describeWorkdir(
        repo._handle,
        maxCandidatesTags: maxCandidatesTags,
        strategy: strategy,
        pattern: pattern,
        onlyFollowFirstParent: onlyFollowFirstParent,
        showCommitOidAsFallback: showCommitOidAsFallback,
      ),
    );
  }

  DescribeResult._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Renders this result as a string.
  ///
  /// [abbreviatedSize] is the lower bound on the length of the
  /// abbreviated commit id (default 7). Set [alwaysUseLongFormat]
  /// to keep the long form (`tag-N-gHASH`) even when the tag alone
  /// would be unique. Pass [dirtySuffix] to have it appended when
  /// the working tree has uncommitted changes.
  String format({
    int abbreviatedSize = 7,
    bool alwaysUseLongFormat = false,
    String? dirtySuffix,
  }) {
    return describeFormat(
      _handle,
      abbreviatedSize: abbreviatedSize,
      alwaysUseLongFormat: alwaysUseLongFormat,
      dirtySuffix: dirtySuffix,
    );
  }

  /// Releases the native describe-result handle.
  void dispose() {
    _finalizer.detach(this);
    describeResultFree(_handle);
  }

  @override
  String toString() => 'DescribeResult(${format()})';
}
