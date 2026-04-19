part of 'api.dart';

/// Basic type of any Git branch.
typedef BranchType = BranchT;

/// Git branch management.
///
/// A [Branch] is a reference that lives under `refs/heads/` (local) or
/// `refs/remotes/` (remote-tracking). The underlying handle is the
/// same as [Reference]; [Branch] exposes the operations libgit2
/// offers only for branches, such as upstream tracking and HEAD
/// detection.
///
/// ```dart
/// final branch = Branch.lookup(repo, 'main', BranchType.local);
/// try {
///   if (branch.isHead) print('on main');
///   branch.setUpstream('origin/main');
/// } finally {
///   branch.dispose();
/// }
/// ```
@immutable
final class Branch {
  static final _finalizer = Finalizer<int>(referenceFree);

  final int _handle;
  final String _repoPath;

  /// The branch name.
  ///
  /// The branch part of the underlying reference name — e.g. `main`,
  /// not `refs/heads/main`.
  final String name;

  /// Looks up a branch by its [name] in [repo].
  ///
  /// [type] selects which namespace to search: [BranchType.local] for
  /// `refs/heads/` or [BranchType.remote] for `refs/remotes/`. [name]
  /// is validated for consistency (see [Tag.create] for rules about
  /// valid names).
  ///
  /// Throws [NotFoundException] when no matching branch exists, or
  /// [InvalidValueException] when [name] is malformed.
  factory Branch.lookup(Repository repo, String name, BranchType type) {
    final handle = branchLookup(repo._handle, name, type);
    return Branch._(handle, repo.path, branchName(handle));
  }

  /// Creates a new branch pointing at a target commit.
  ///
  /// A new direct reference is written in the `refs/heads/` namespace
  /// pointing to [target]. If [force] is `true` and a reference with
  /// the given [name] already exists, it is replaced.
  ///
  /// [name] is validated for consistency (see [Tag.create] for rules
  /// about valid names) and should also not conflict with an already
  /// existing branch name. [target] must belong to [repo].
  ///
  /// Throws [InvalidValueException] when [name] is malformed.
  factory Branch.create({
    required Repository repo,
    required String name,
    required Commit target,
    bool force = false,
  }) {
    final handle = branchCreate(
      repoHandle: repo._handle,
      name: name,
      commitHandle: target._handle,
      force: force,
    );
    return Branch._(handle, repo.path, branchName(handle));
  }

  /// Creates a new branch pointing at a target commit.
  ///
  /// Behaves like [Branch.create] but takes an [AnnotatedCommit],
  /// which lets callers specify which extended sha syntax string was
  /// supplied by the user, allowing for more exact reflog messages.
  factory Branch.createFromAnnotated({
    required Repository repo,
    required String name,
    required AnnotatedCommit target,
    bool force = false,
  }) {
    final handle = branchCreateFromAnnotated(
      repoHandle: repo._handle,
      name: name,
      annotatedHandle: target._handle,
      force: force,
    );
    return Branch._(handle, repo.path, branchName(handle));
  }

  Branch._(this._handle, this._repoPath, this.name) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Determines whether [name] is a valid branch name.
  ///
  /// A name is valid when, prefixed with `refs/heads/`, it is a valid
  /// reference name and additional branch name restrictions are
  /// satisfied (for example, it cannot start with a `-`).
  static bool nameIsValid(String name) => branchNameIsValid(name);

  /// Whether HEAD points at this branch.
  bool get isHead => branchIsHead(_handle);

  /// Whether any HEAD points at this branch.
  ///
  /// Iterates every known linked repository (usually in the form of
  /// worktrees) and reports whether any HEAD points at this branch.
  bool get isCheckedOut => branchIsCheckedOut(_handle);

  /// Returns the upstream of this branch.
  ///
  /// This branch must be local. The returned [Branch] corresponds to
  /// its remote-tracking branch. See
  /// [RepositoryBranch.upstreamNameFor] for details on the resolution.
  ///
  /// Throws [NotFoundException] when no remote-tracking reference
  /// exists.
  Branch upstream() {
    final handle = branchUpstream(_handle);
    return Branch._(handle, _repoPath, branchName(handle));
  }

  /// Sets this branch's upstream.
  ///
  /// Updates the configuration to set the branch named [upstreamName]
  /// as the upstream of this branch. Pass `null` to unset the
  /// upstream information.
  ///
  /// The actual tracking reference must have already been created for
  /// the operation to succeed.
  ///
  /// Throws [NotFoundException] when no branch named [upstreamName]
  /// exists.
  void setUpstream(String? upstreamName) {
    branchSetUpstream(_handle, upstreamName);
  }

  /// Moves and renames this local branch reference to [newName].
  ///
  /// [newName] is validated for consistency (see [Tag.create] for
  /// rules about valid names). If [force] is `true`, an existing
  /// branch with the same name is overwritten.
  ///
  /// If the move succeeds this instance no longer refers to a valid
  /// branch and must be [dispose]d; the returned [Branch] is the new
  /// reference for the renamed branch.
  ///
  /// Throws [InvalidValueException] when [newName] is malformed.
  Branch rename(String newName, {bool force = false}) {
    final handle = branchMove(_handle, newName, force: force);
    return Branch._(handle, _repoPath, branchName(handle));
  }

  /// Deletes this branch reference.
  ///
  /// If the deletion succeeds this instance no longer refers to a
  /// valid branch and should be [dispose]d immediately.
  void delete() => branchDelete(_handle);

  /// Releases the native branch handle.
  void dispose() {
    _finalizer.detach(this);
    referenceFree(_handle);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Branch && _repoPath == other._repoPath && name == other.name);

  @override
  int get hashCode => Object.hash(_repoPath, name);

  @override
  String toString() => 'Branch($name)';
}

/// Branch operations on [Repository].
extension RepositoryBranch on Repository {
  /// Returns every branch matching [filter].
  ///
  /// Loops over the requested branches and returns a fresh [Branch]
  /// for each. [filter] may be [BranchType.local], [BranchType.remote]
  /// or [BranchType.all] (the default). Callers must [Branch.dispose]
  /// every returned instance.
  List<Branch> branches({BranchType filter = BranchType.all}) {
    final iterHandle = branchIteratorNew(_handle, filter);
    try {
      final result = <Branch>[];
      while (true) {
        final next = branchNext(iterHandle);
        if (next == null) break;
        result.add(Branch._(next.handle, path, branchName(next.handle)));
      }
      return result;
    } finally {
      branchIteratorFree(iterHandle);
    }
  }

  /// Returns the upstream name of a local branch.
  ///
  /// Given a local branch [branchRefname], returns its remote-tracking
  /// branch information as a full reference name — e.g. `feature/nice`
  /// becomes `refs/remotes/origin/feature/nice`, depending on that
  /// branch's configuration.
  ///
  /// Throws [NotFoundException] when no remote-tracking reference
  /// exists.
  String upstreamNameFor(String branchRefname) {
    return branchUpstreamName(_handle, branchRefname);
  }

  /// Returns the remote name of a remote-tracking branch.
  ///
  /// Returns the name of the remote whose fetch refspec matches
  /// [branchRefname]. E.g. given `refs/remotes/test/master`, this
  /// extracts the `test` part.
  ///
  /// Throws [NotFoundException] when no matching remote was found, or
  /// [AmbiguousException] when the branch maps to several remotes.
  String remoteNameFor(String branchRefname) {
    return branchRemoteName(_handle, branchRefname);
  }

  /// Returns the configured `branch.<name>.merge` for the local branch
  /// [branchRefname].
  ///
  /// This branch must be local.
  String upstreamMergeFor(String branchRefname) {
    return branchUpstreamMerge(_handle, branchRefname);
  }

  /// Returns the configured `branch.<name>.remote` for the local
  /// branch [branchRefname].
  ///
  /// This branch must be local.
  String upstreamRemoteFor(String branchRefname) {
    return branchUpstreamRemote(_handle, branchRefname);
  }
}
