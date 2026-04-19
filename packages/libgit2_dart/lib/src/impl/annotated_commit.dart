part of 'api.dart';

/// A commit plus the context by which the user resolved it (ref,
/// revspec, FETCH_HEAD, etc.).
///
/// Merge, rebase, and cherry-pick use the recorded context to produce
/// more specific conflict messages — for example, reporting
/// `merging branch 'feature'` instead of a bare commit id. Prefer the
/// most specific constructor available: lookups by ref produce richer
/// context than lookups by bare id.
///
/// Instances own native memory and must be [dispose]d. Two
/// [AnnotatedCommit] instances compare by identity because each one
/// carries its own resolution context even when the commit [id]
/// matches.
///
/// ```dart
/// final ac = AnnotatedCommit.fromRevSpec(repo, 'HEAD~2');
/// print(ac.id);   // Oid of the commit two back from HEAD
/// print(ac.ref);  // null (no ref was used)
/// ac.dispose();
/// ```
final class AnnotatedCommit {
  static final _finalizer = Finalizer<int>(annotatedCommitFree);

  final int _handle;

  /// Constructs the annotated commit FETCH_HEAD would produce after a
  /// fetch from [remoteUrl] on [branchName] advertising [commitId].
  factory AnnotatedCommit.fromFetchHead({
    required Repository repo,
    required String branchName,
    required String remoteUrl,
    required Oid commitId,
  }) {
    return AnnotatedCommit._(
      annotatedCommitFromFetchHead(
        repo._handle,
        branchName,
        remoteUrl,
        commitId.bytes,
      ),
    );
  }

  /// Resolves the annotated commit for [revSpec].
  ///
  /// [revSpec] accepts the extended SHA syntax `git-rev-parse` uses
  /// (for example `HEAD`, `HEAD~2`, `main@{yesterday}`, or
  /// `topic^{tree}`).
  ///
  /// Throws [InvalidValueException] when [revSpec] is not parseable.
  /// Throws [NotFoundException] when [revSpec] resolves to nothing.
  factory AnnotatedCommit.fromRevSpec(Repository repo, String revSpec) =>
      AnnotatedCommit._(annotatedCommitFromRevSpec(repo._handle, revSpec));

  /// Resolves the annotated commit for the commit [id].
  ///
  /// Prefer [AnnotatedCommit.fromRevSpec] or [AnnotatedCommit.fromRef]
  /// when the input came from a human-readable source so downstream
  /// operations can report it by name.
  ///
  /// Throws [NotFoundException] when [id] does not name a commit in
  /// [repo].
  factory AnnotatedCommit.lookup(Repository repo, Oid id) =>
      AnnotatedCommit._(annotatedCommitLookup(repo._handle, id.bytes));

  /// Resolves the annotated commit for [reference].
  ///
  /// Records the ref's full name alongside its target commit so
  /// merge and rebase report it by name (e.g. `merging branch
  /// 'feature'`). Throws [NotFoundException] when the ref's target
  /// is unreachable.
  factory AnnotatedCommit.fromRef(Repository repo, Reference reference) =>
      AnnotatedCommit._(
        annotatedCommitFromRef(repo._handle, reference._handle),
      );

  AnnotatedCommit._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// The commit this annotated commit points at.
  Oid get id => Oid._(annotatedCommitId(_handle));

  /// The ref name used to resolve this annotated commit, or `null`
  /// when it was constructed from a raw id or a revspec.
  String? get ref => annotatedCommitRef(_handle);

  /// Releases the native annotated-commit handle.
  void dispose() {
    _finalizer.detach(this);
    annotatedCommitFree(_handle);
  }
}
