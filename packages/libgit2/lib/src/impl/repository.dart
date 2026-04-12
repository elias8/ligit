part of 'api.dart';

/// The type of object id used by a repository.
typedef ObjectIdType = OidT;

/// A Git repository on disk.
///
/// Open an existing repository with [open], [openBare], [openExt], or
/// [Worktree]-backed [openFromWorktree]; create a new one with [init]
/// or [initExt]; or clone a remote one with [Repository.clone]. Use
/// [discover] to search upward for a `.git` directory without opening
/// it. Call [dispose] when finished.
///
/// Two instances that refer to the same `.git` directory compare
/// equal, regardless of which factory produced them.
///
/// ```dart
/// final repo = Repository.init('/tmp/myrepo');
/// try {
///   print(repo.path);
///   if (!repo.isEmpty) {
///     final head = repo.head();
///     try {
///       print(head.name);
///     } finally {
///       head.dispose();
///     }
///   }
/// } finally {
///   repo.dispose();
/// }
/// ```
@immutable
final class Repository {
  static final _finalizer = Finalizer<int>(repositoryFree);

  final int _handle;

  /// The path to the `.git` directory, or the root for bare
  /// repositories.
  ///
  /// Normalized at construction time so that two instances pointing
  /// at the same directory compare equal regardless of trailing
  /// slashes.
  final String path;

  /// Creates a new repository at [path].
  ///
  /// When [bare] is `true` the repository has no working directory
  /// and the git data is stored directly at [path] instead of inside
  /// a `.git` subdirectory.
  factory Repository.init(String path, {bool bare = false}) {
    final handle = repositoryInit(path, bare: bare);
    return Repository._(handle, repositoryPath(handle));
  }

  /// Creates a new repository at [path] with extended options.
  ///
  /// Automatically detects the case sensitivity of the file system
  /// and whether it supports file mode bits correctly. [flags] is a
  /// combination of `GIT_REPOSITORY_INIT_*` values controlling
  /// init-time behavior. [mode] is either a `GIT_REPOSITORY_INIT_SHARED_*`
  /// constant or a custom mode for shared permissions.
  /// [workdirPath] selects an alternate working directory — when
  /// relative, it is evaluated relative to [path]. [description]
  /// seeds the repository's `description` file. [templatePath]
  /// points at the template directory to copy from. [initialHead]
  /// names the initial HEAD branch (prefixed with `refs/heads/` when
  /// it does not start with `refs/`). [originUrl], when non-null,
  /// adds an `origin` remote after initialization.
  factory Repository.initExt(
    String path, {
    required int flags,
    required int mode,
    String? workdirPath,
    String? description,
    String? templatePath,
    String? initialHead,
    String? originUrl,
  }) {
    final handle = repositoryInitExt(
      path,
      flags: flags,
      mode: mode,
      workdirPath: workdirPath,
      description: description,
      templatePath: templatePath,
      initialHead: initialHead,
      originUrl: originUrl,
    );
    return Repository._(handle, repositoryPath(handle));
  }

  /// Opens an existing repository at [path].
  ///
  /// [path] may point to either a git repository folder or an
  /// existing work directory; the kind is detected automatically.
  factory Repository.open(String path) {
    final handle = repositoryOpen(path);
    return Repository._(handle, repositoryPath(handle));
  }

  /// Opens a bare repository at [path].
  ///
  /// A fast open path intended for server-side scenarios where
  /// [path] is known to point directly at the bare repository's
  /// root directory.
  factory Repository.openBare(String path) {
    final handle = repositoryOpenBare(path);
    return Repository._(handle, repositoryPath(handle));
  }

  /// Opens the working directory of [worktree] as a normal
  /// repository.
  factory Repository.openFromWorktree(Worktree worktree) {
    final handle = repositoryOpenFromWorktree(worktree._handle);
    return Repository._(handle, repositoryPath(handle));
  }

  /// Opens a repository with extended controls.
  ///
  /// [path] is the start path for the search; it may be `null` when
  /// [flags] includes [RepositoryOpenFlag.fromEnv]. [flags] is a
  /// combination of [RepositoryOpenFlag] values. [ceilingDirs] is an
  /// optional path-list of directories at which the upward search
  /// should stop.
  ///
  /// Throws [NotFoundException] when no repository is found.
  factory Repository.openExt(
    String? path, {
    required int flags,
    String? ceilingDirs,
  }) {
    final handle = repositoryOpenExt(path, flags, ceilingDirs);
    return Repository._(handle, repositoryPath(handle));
  }

  /// Clones the repository at [url] into [localPath] and opens the
  /// new repository.
  ///
  /// Set [bare] to create a bare repository. [local] overrides the
  /// local-transport heuristic used for `file://` and plain
  /// filesystem paths. [checkoutBranch] picks an initial HEAD
  /// branch; when `null` the remote's default branch is checked
  /// out. [checkoutStrategy] is forwarded to the checkout step;
  /// pass an empty set to leave the working tree untouched.
  /// [checkoutPaths] limits the initial checkout to matching paths.
  factory Repository.clone({
    required String url,
    required String localPath,
    bool bare = false,
    CloneLocal local = CloneLocal.localAuto,
    String? checkoutBranch,
    Set<CheckoutStrategy> checkoutStrategy = const {CheckoutStrategy.safe},
    List<String> checkoutPaths = const [],
  }) {
    var bits = 0;
    for (final s in checkoutStrategy) {
      bits |= s.value;
    }
    final handle = clone_bindings.clone(
      url,
      localPath,
      bare: bare,
      local: local.value,
      checkoutBranch: checkoutBranch,
      checkoutStrategy: bits,
      checkoutPaths: checkoutPaths,
    );
    return Repository._(handle, repositoryPath(handle));
  }

  Repository._(this._handle, String rawPath)
    : path = rawPath.endsWith('/')
          ? rawPath.substring(0, rawPath.length - 1)
          : rawPath {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// The shared common directory for this repository.
  ///
  /// For bare repositories this is the root. For linked worktrees
  /// this is the parent repository's gitdir. Otherwise it is the
  /// gitdir.
  String get commonDir => repositoryCommonDir(_handle);

  @override
  int get hashCode => path.hashCode;

  /// The configured identity used for writing reflogs.
  ///
  /// Either field may be `null` when no identity has been set; in
  /// that case the identity is taken from the repository's
  /// configuration.
  ({String? name, String? email}) get ident => repositoryIdent(_handle);

  /// Whether this repository is bare (has no working directory).
  bool get isBare => repositoryIsBare(_handle);

  /// Whether this repository is empty.
  ///
  /// An empty repository has just been initialized and contains no
  /// references apart from HEAD, which points at the unborn default
  /// branch.
  bool get isEmpty => repositoryIsEmpty(_handle);

  /// Whether HEAD is detached — pointing directly at a commit rather
  /// than a branch.
  bool get isHeadDetached => repositoryHeadDetached(_handle);

  /// Whether the current branch is unborn.
  ///
  /// An unborn branch is one named from HEAD but which does not yet
  /// exist in the refs namespace, because it has no commit to point
  /// to.
  bool get isHeadUnborn => repositoryHeadUnborn(_handle);

  /// Whether this repository is a shallow clone.
  bool get isShallow => repositoryIsShallow(_handle);

  /// Whether this repository is a linked worktree.
  bool get isWorktree => repositoryIsWorktree(_handle);

  /// The prepared merge, revert, or cherry-pick message, or `null`
  /// when no prepared message exists.
  ///
  /// `git revert`, `git cherry-pick`, and `git merge` with `-n` stop
  /// just short of committing and save their prepared message so the
  /// next commit can present it to the user. Remove it with
  /// [removeMessage] once the commit has been made.
  String? get message => repositoryMessage(_handle);

  /// The active namespace for this repository, or `null` when none
  /// is set.
  ///
  /// See `man gitnamespaces` for details.
  String? get namespace => repositoryGetNamespace(_handle);

  /// The current operational state of this repository, reflecting
  /// any ongoing operation such as merge, revert, or cherry-pick.
  RepositoryState get state => repositoryState(_handle);

  /// The path to the working directory, or `null` for bare
  /// repositories.
  String? get workDir => repositoryWorkDir(_handle);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Repository && other.path == path);

  /// The parents of the next commit made in this repository's
  /// current state.
  ///
  /// On a clean repository this is just HEAD; during a merge it is
  /// HEAD plus every `MERGE_HEAD` entry. Callers must [Commit.dispose]
  /// each returned [Commit].
  List<Commit> commitParents() {
    final handles = repositoryCommitParents(_handle);
    return [
      for (final handle in handles) Commit._(handle, Oid._(commitId(handle))),
    ];
  }

  /// Opens the configuration for this repository.
  ///
  /// Returns the merged multi-level configuration, including global
  /// and system configurations when available. Callers must
  /// [Config.dispose] the returned instance. For a consistent
  /// read-only view, use [configSnapshot] instead.
  // ignore: use_to_and_as_if_applicable
  Config config() => Config.fromRepository(this);

  /// Opens a snapshot of this repository's configuration.
  ///
  /// The contents of the snapshot do not change even if the
  /// underlying config files are modified. Callers must
  /// [Config.dispose] the returned instance.
  // ignore: use_to_and_as_if_applicable
  Config configSnapshot() => Config.snapshotFromRepository(this);

  /// Opens the reference database backend for this repository.
  ///
  /// Callers must [RefDb.dispose] the returned instance.
  RefDb refDb() => RefDb._(repositoryRefdb(_handle));

  /// Opens the index file for this repository.
  ///
  /// Callers must [Index.dispose] the returned instance.
  Index index() => Index._(repositoryIndex(_handle));

  /// The object-id type used throughout this repository.
  ObjectIdType get oidType =>
      ObjectIdType.fromValue(repositoryOidType(_handle));

  /// Invokes [callback] for each entry in `FETCH_HEAD`.
  ///
  /// [callback] receives the reference name, the remote URL, the
  /// recorded [Oid], and whether the line was tagged for merging.
  /// Returning a non-zero value stops iteration and is surfaced as
  /// this call's return.
  ///
  /// Throws [NotFoundException] when no `FETCH_HEAD` file exists.
  int forEachFetchHead(
    int Function({
      required String refName,
      required String remoteUrl,
      required Oid oid,
      required bool isMerge,
    })
    callback,
  ) {
    return repositoryFetchheadForeach(
      _handle,
      ({
        required refName,
        required remoteUrl,
        required oid,
        required isMerge,
      }) => callback(
        refName: refName,
        remoteUrl: remoteUrl,
        oid: Oid._(oid),
        isMerge: isMerge,
      ),
    );
  }

  /// Invokes [callback] for each commit id in `MERGE_HEAD` when a
  /// merge is in progress.
  ///
  /// Returning a non-zero value stops iteration and is surfaced as
  /// this call's return.
  ///
  /// Throws [NotFoundException] when no `MERGE_HEAD` file exists.
  int forEachMergeHead(int Function(Oid oid) callback) {
    return repositoryMergeheadForeach(
      _handle,
      (bytes) => callback(Oid._(bytes)),
    );
  }

  /// Detaches HEAD, pointing it directly at the currently
  /// checked-out commit.
  ///
  /// When HEAD already points at a tag, the tag is peeled and HEAD
  /// is pointed at the resulting commit.
  ///
  /// Throws [UnbornBranchException] when HEAD points at an unborn
  /// branch.
  void detachHead() => repositoryDetachHead(_handle);

  /// Releases the native repository handle.
  void dispose() {
    _finalizer.detach(this);
    repositoryFree(_handle);
  }

  /// Hashes the file at [filePath] using the repository's filtering
  /// rules.
  ///
  /// [objectType] selects the object type header (typically blob).
  /// [asPath] overrides the path used for attribute lookups; when
  /// `null` and [filePath] is inside the working directory, it is
  /// used as-is. Pass an empty string to skip filters entirely.
  Oid hashFile(String filePath, int objectType, {String? asPath}) {
    final bytes = repositoryHashFile(_handle, filePath, objectType, asPath);
    return Oid._(bytes);
  }

  /// Whether the worktree named [name] has a detached HEAD.
  bool isHeadDetachedForWorktree(String name) {
    return repositoryHeadDetachedForWorktree(_handle, name);
  }

  /// Resolves HEAD to a direct reference.
  ///
  /// Callers must [Reference.dispose] the returned reference.
  ///
  /// Throws [UnbornBranchException] when HEAD points at an unborn
  /// branch. Throws [NotFoundException] when HEAD is missing.
  Reference head() {
    final handle = repositoryHead(_handle);
    return Reference._(handle, path, referenceName(handle));
  }

  /// Resolves HEAD for the worktree named [name].
  ///
  /// Callers must [Reference.dispose] the returned reference.
  Reference headForWorktree(String name) {
    final handle = repositoryHeadForWorktree(_handle, name);
    return Reference._(handle, path, referenceName(handle));
  }

  /// The filesystem path for the given layout [item], or `null` when
  /// the item does not exist for this repository.
  ///
  /// Honors the repository's common directory, gitdir, and so on.
  String? itemPath(RepositoryItem item) => repositoryItemPath(_handle, item);

  /// Removes the prepared commit message file from the repository.
  ///
  /// This is the file exposed by [message].
  void removeMessage() => repositoryMessageRemove(_handle);

  /// Resolves [spec] as a revision range expression such as
  /// `main..topic` or `main...topic`.
  ///
  /// Callers must [RevSpec.dispose] the returned value.
  ///
  /// Throws [NotFoundException] when an endpoint cannot be resolved.
  /// Throws [AmbiguousException] when an endpoint is ambiguous.
  /// Throws [InvalidValueException] when [spec] is not parseable.
  RevSpec revParseRange(String spec) {
    final result = rp.revParseRange(_handle, spec);
    final from = GitObject._(
      result.fromHandle,
      Oid._(objectId(result.fromHandle)),
    );
    final to = result.toHandle == 0
        ? null
        : GitObject._(result.toHandle, Oid._(objectId(result.toHandle)));
    return RevSpec._(
      from: from,
      to: to,
      flags: _decodeRevSpecFlags(result.flags),
    );
  }

  /// Resolves [spec] to a single object using the extended SHA
  /// syntax `git-rev-parse` accepts (for example `HEAD`, `HEAD~2`,
  /// `main@{yesterday}`, `topic^{tree}`).
  ///
  /// Callers must [GitObject.dispose] the returned object.
  ///
  /// Throws [NotFoundException] when [spec] resolves to nothing.
  /// Throws [AmbiguousException] when [spec] is ambiguous.
  /// Throws [InvalidValueException] when [spec] is not parseable.
  GitObject revParseSingle(String spec) {
    final handle = rp.revParseSingle(_handle, spec);
    return GitObject._(handle, Oid._(objectId(handle)));
  }

  /// Resolves [spec] and, when the expression names a reference
  /// (`@{-n}`, `<branch>@{upstream}`), also returns that reference.
  ///
  /// Callers must [GitObject.dispose] the returned object, and
  /// [Reference.dispose] the reference when non-null.
  ///
  /// Throws the same exceptions as [revParseSingle].
  ({GitObject object, Reference? reference}) revParseExt(String spec) {
    final result = rp.revParseExt(_handle, spec);
    final object = GitObject._(
      result.objectHandle,
      Oid._(objectId(result.objectHandle)),
    );
    final reference = result.referenceHandle == 0
        ? null
        : Reference._(
            result.referenceHandle,
            path,
            referenceName(result.referenceHandle),
          );
    return (object: object, reference: reference);
  }

  /// Points HEAD at the branch or reference named [refname].
  ///
  /// [refname] must be a canonical reference name such as
  /// `refs/heads/main`. If the reference points at a branch, HEAD
  /// will point at that branch, attaching to it (possibly as unborn
  /// if the branch does not yet exist). Otherwise HEAD is detached
  /// and points at the resolved commit.
  void setHead(String refname) => repositorySetHead(_handle, refname);

  /// Points HEAD directly at the commit identified by [target],
  /// detaching it from any branch.
  ///
  /// Throws [NotFoundException] when [target] is not found.
  void setHeadDetached(Oid target) {
    repositorySetHeadDetached(_handle, target._bytes);
  }

  /// Points HEAD directly at the commit referenced by [target],
  /// preserving the extended sha expression carried by [target] in
  /// the reflog message.
  ///
  /// Use this instead of [setHeadDetached] when the commit was
  /// resolved from a human-readable source so the recorded reflog
  /// entry retains that context.
  void setHeadDetachedFromAnnotated(AnnotatedCommit target) {
    repositorySetHeadDetachedFromAnnotated(_handle, target._handle);
  }

  /// Sets the identity used for writing reflogs.
  ///
  /// Pass `null` for both [name] and [email] to unset the identity
  /// and fall back to the repository's configuration.
  void setIdent({String? name, String? email}) {
    repositorySetIdent(_handle, name: name, email: email);
  }

  /// Sets the active namespace for this repository.
  ///
  /// Namespace-qualified reference names are rewritten on read and
  /// write so that each namespace gets its own isolated set of
  /// refs. [namespace] should not include the `refs/` folder — e.g.
  /// pass `foo` to namespace all references under
  /// `refs/namespaces/foo/`.
  void setNamespace(String namespace) {
    repositorySetNamespace(_handle, namespace);
  }

  /// Sets the working directory for this repository.
  ///
  /// The working directory does not need to be the same one that
  /// contains the `.git` folder. Setting a working directory on a
  /// bare repository turns it into a normal repository.
  ///
  /// When [updateGitlink] is `true` a `.git` gitlink file in the
  /// new working directory is created or updated to point at this
  /// repository, and `core.worktree` is set in the config.
  void setWorkDir(String path, {bool updateGitlink = false}) {
    repositorySetWorkDir(_handle, path, updateGitlink: updateGitlink);
  }

  /// Removes all metadata associated with an ongoing command, such
  /// as merge, revert, or cherry-pick — including `MERGE_HEAD` and
  /// `MERGE_MSG`.
  void stateCleanup() => repositoryStateCleanup(_handle);

  @override
  String toString() => 'Repository($path)';

  /// Searches upward from [startPath] for a repository and returns
  /// the path to its `.git` directory, or `null` when none is found.
  ///
  /// Detects bare repositories automatically. When [acrossFs] is
  /// `false` (the default) the search stops at filesystem boundaries.
  /// [ceilingDirs] is an optional path-list of absolute paths at
  /// which the search should stop.
  static String? discover(
    String startPath, {
    bool acrossFs = false,
    String? ceilingDirs,
  }) {
    return repositoryDiscover(
      startPath,
      acrossFs: acrossFs,
      ceilingDirs: ceilingDirs,
    );
  }
}
