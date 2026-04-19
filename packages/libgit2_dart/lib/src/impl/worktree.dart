part of 'api.dart';

/// Flags controlling prune behavior.
typedef WorktreePruneFlag = WorktreePrune;

/// A linked working tree for a repository.
///
/// Worktrees share an object database with their parent repository
/// but keep their own index, HEAD, and checked-out branch. Create one
/// with [Worktree.add], look one up by name with [Worktree.lookup],
/// or open the worktree backing an existing [Repository] with
/// [Worktree.fromRepository].
///
/// Two instances that refer to the same worktree by name and path
/// compare equal.
///
/// ```dart
/// final wt = Worktree.add(repo, 'feature', '/tmp/myrepo-feature');
/// try {
///   print(wt.path);
///   if (wt.isPrunable()) wt.prune();
/// } finally {
///   wt.dispose();
/// }
/// ```
@immutable
final class Worktree {
  static final _finalizer = Finalizer<int>(worktreeFree);

  final int _handle;

  /// The worktree's name — the label under
  /// `.git/worktrees/<name>`.
  final String name;

  /// Adds a new worktree named [name] at [path] backed by [repo].
  ///
  /// Creates the required bookkeeping inside [repo] and checks out
  /// the current HEAD at [path]. Set [lock] to immediately lock the
  /// new worktree. Pass [reference] to check out a specific
  /// reference instead of HEAD. Set [checkoutExisting] to allow
  /// reusing an existing branch whose name matches [name].
  factory Worktree.add(
    Repository repo,
    String name,
    String path, {
    bool lock = false,
    bool checkoutExisting = false,
    Reference? reference,
  }) {
    final handle = worktreeAdd(
      repo._handle,
      name,
      path,
      lock: lock,
      checkoutExisting: checkoutExisting,
      referenceHandle: reference?._handle,
    );
    return Worktree._(handle, worktreeName(handle));
  }

  /// Opens the worktree backing [repo].
  ///
  /// Use when [repo] is itself a linked worktree; the parent
  /// repository is consulted to resolve the worktree record.
  factory Worktree.fromRepository(Repository repo) {
    final handle = worktreeOpenFromRepository(repo._handle);
    return Worktree._(handle, worktreeName(handle));
  }

  /// Looks up the worktree named [name] in [repo].
  ///
  /// Throws [NotFoundException] when no worktree matches [name].
  factory Worktree.lookup(Repository repo, String name) {
    final handle = worktreeLookup(repo._handle, name);
    return Worktree._(handle, worktreeName(handle));
  }

  Worktree._(this._handle, this.name) {
    _finalizer.attach(this, _handle, detach: this);
  }

  @override
  int get hashCode => Object.hash(name, path);

  /// Whether this worktree is currently locked.
  ///
  /// A worktree may be locked, for example, when the linked working
  /// tree is stored on a portable device that is not available. Use
  /// [lockReason] to read the reason recorded at lock time.
  bool get isLocked => worktreeIsLocked(_handle).locked;

  /// Whether this worktree is valid.
  ///
  /// A worktree is valid when both the linked working directory and
  /// the bookkeeping data in the parent repository are present.
  bool get isValid => worktreeValidate(_handle);

  /// The reason recorded when this worktree was locked, or `null`
  /// when the worktree is unlocked or was locked without a reason.
  String? get lockReason => worktreeIsLocked(_handle).reason;

  /// The filesystem path to the worktree's working directory.
  String get path => worktreePath(_handle);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Worktree && other.name == name && other.path == path);

  /// Releases the native worktree handle.
  void dispose() {
    _finalizer.detach(this);
    worktreeFree(_handle);
  }

  /// Whether this worktree can be pruned.
  ///
  /// A worktree is not prunable when it links to a valid on-disk
  /// worktree or when it is locked. Pass [WorktreePruneFlag.valid]
  /// to override the validity check and [WorktreePruneFlag.locked]
  /// to override the lock check.
  bool isPrunable({Set<WorktreePruneFlag> flags = const {}}) {
    return worktreeIsPrunable(_handle, flags: _encodeFlags(flags));
  }

  /// Locks this worktree, optionally recording [reason].
  void lock({String? reason}) => worktreeLock(_handle, reason: reason);

  /// Prunes this worktree, removing its bookkeeping data from disk.
  ///
  /// Only proceeds when the worktree is prunable; see [isPrunable]
  /// for what [flags] overrides.
  void prune({Set<WorktreePruneFlag> flags = const {}}) {
    worktreePrune(_handle, flags: _encodeFlags(flags));
  }

  @override
  String toString() => 'Worktree($name, $path)';

  /// Unlocks this worktree.
  ///
  /// Returns `true` when the worktree was locked, `false` when it
  /// was already unlocked.
  bool unlock() => worktreeUnlock(_handle);

  static int _encodeFlags(Set<WorktreePruneFlag> flags) {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    return bits;
  }
}

/// Worktree management on [Repository].
extension RepositoryWorktree on Repository {
  /// The names of every linked worktree on this repository.
  List<String> worktreeNames() => worktreeList(_handle);
}
