part of 'api.dart';

/// Type of a single rebase step scheduled inside a rebase plan.
typedef RebaseOperationType = RebaseOperationT;

/// A rebase in progress.
///
/// Replays commits from one branch onto another, one step at a time.
/// Start a new rebase with [Rebase.start] or attach to an existing
/// one with [Rebase.open]; step through the plan with [next]; commit
/// each step with [commitStep]; then [finish] or [abort].
///
/// Owns a native resource; call [dispose] when finished.
///
/// ```dart
/// final branch = AnnotatedCommit.lookup(repo, featureTip);
/// final onto = AnnotatedCommit.lookup(repo, mainTip);
/// final rebase = Rebase.start(repo: repo, branch: branch, onto: onto);
/// try {
///   while (true) {
///     try {
///       rebase.next();
///       rebase.commitStep(committer: me);
///     } on Libgit2Exception catch (e) {
///       if (e.code == Libgit2Error.iterover) break;
///       rethrow;
///     }
///   }
///   rebase.finish(signature: me);
/// } finally {
///   rebase.dispose();
/// }
/// ```
@immutable
final class Rebase {
  /// Sentinel [currentOperationIndex] returns when no rebase step
  /// is yet in progress.
  static const noOperation = rebaseNoOperation;

  static final _finalizer = Finalizer<int>(rebaseFree);

  final int _handle;

  /// Starts a rebase that replays the changes in [branch] relative
  /// to [upstream] onto [onto].
  ///
  /// Pass null for [branch] to rebase the current branch, null for
  /// [upstream] to rebase every reachable commit, and null for
  /// [onto] to rebase onto [upstream]. Step through the plan with
  /// [next].
  factory Rebase.start({
    required Repository repo,
    AnnotatedCommit? branch,
    AnnotatedCommit? upstream,
    AnnotatedCommit? onto,
    bool inMemory = false,
    bool quiet = false,
    String? rewriteNotesRef,
  }) => Rebase._(
    rebaseInit(
      repo._handle,
      branchHandle: branch?._handle ?? 0,
      upstreamHandle: upstream?._handle ?? 0,
      ontoHandle: onto?._handle ?? 0,
      inMemory: inMemory,
      quiet: quiet,
      rewriteNotesRef: rewriteNotesRef,
    ),
  );

  /// Opens an existing rebase already in progress on [repo].
  ///
  /// The rebase may have been started by a previous [Rebase.start]
  /// call or by another git client.
  factory Rebase.open(Repository repo) => Rebase._(rebaseOpen(repo._handle));

  Rebase._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Name of the reference HEAD pointed at when the rebase began.
  String get origHeadName => rebaseOrigHeadName(_handle);

  /// [Oid] HEAD pointed at when the rebase began.
  Oid get origHeadId => Oid._(rebaseOrigHeadId(_handle));

  /// Name of the `onto` target.
  String get ontoName => rebaseOntoName(_handle);

  /// [Oid] of the `onto` target.
  Oid get ontoId => Oid._(rebaseOntoId(_handle));

  /// Total number of operations scheduled in this rebase.
  int get operationCount => rebaseOperationEntryCount(_handle);

  /// Index of the operation currently being applied, or
  /// [noOperation] when [next] has not yet been called.
  int get currentOperationIndex => rebaseOperationCurrent(_handle);

  /// Returns the operation at [position], or null when out of range.
  RebaseOperation? operationAt(int position) {
    final r = rebaseOperationByIndex(_handle, position);
    return r == null ? null : RebaseOperation._(r);
  }

  /// Every scheduled rebase operation, in order.
  Iterable<RebaseOperation> get operations sync* {
    for (var i = 0; i < operationCount; i++) {
      final r = rebaseOperationByIndex(_handle, i);
      if (r == null) return;
      yield RebaseOperation._(r);
    }
  }

  /// Performs the next rebase operation and returns it.
  ///
  /// For any operation that applies a patch — everything except
  /// [RebaseOperationType.exec] — the patch is applied and the
  /// index and working directory are updated. Resolve any conflicts
  /// that arise before calling [commitStep].
  RebaseOperation next() => RebaseOperation._(rebaseNext(_handle));

  /// Returns the index produced by the last [next] call — the one
  /// that will be committed by the next [commitStep].
  ///
  /// Only applicable for in-memory rebases ([Rebase.start] with
  /// `inMemory: true`); for on-disk rebases the changes live in the
  /// repository's own index. Useful for resolving conflicts before
  /// committing. Callers must [Index.dispose] the returned index.
  Index inMemoryIndex() => Index._(rebaseInmemoryIndex(_handle));

  /// Commits the patch applied by the most recent [next] call.
  ///
  /// Any conflicts introduced by the last [next] must have been
  /// resolved. Pass null for [author] to keep the author from the
  /// original commit; [committer] identifies the user performing the
  /// rebase. [message] and [messageEncoding] override the original
  /// commit's metadata — either leave both null to reuse the
  /// original values, or pass [message] and, optionally, an
  /// [messageEncoding] (defaulting to UTF-8).
  ///
  /// Returns the [Oid] of the newly created commit.
  Oid commitStep({
    Signature? author,
    required Signature committer,
    String? messageEncoding,
    String? message,
  }) => Oid._(
    rebaseCommit(
      _handle,
      author: author?._record,
      committer: committer._record,
      messageEncoding: messageEncoding,
      message: message,
    ),
  );

  /// Aborts the in-progress rebase, resetting the repository and
  /// working directory to their pre-rebase state.
  void abort() => rebaseAbort(_handle);

  /// Finalizes the rebase after every operation has been committed.
  ///
  /// [signature] identifies the user finishing the rebase and is
  /// recorded in the reflog.
  void finish({Signature? signature}) =>
      rebaseFinish(_handle, signature: signature?._record);

  /// Releases the resources held by this rebase.
  void dispose() {
    _finalizer.detach(this);
    rebaseFree(_handle);
  }
}

/// A single instruction in a rebase plan.
@immutable
final class RebaseOperation {
  /// Kind of step this operation represents.
  final RebaseOperationType type;

  /// [Oid] of the commit this step replays; the zero [Oid] for
  /// [RebaseOperationType.exec] steps.
  final Oid id;

  /// Executable to run for [RebaseOperationType.exec] steps, or
  /// null for other types.
  final String? exec;

  const RebaseOperation._raw({
    required this.type,
    required this.id,
    required this.exec,
  });

  factory RebaseOperation._(RebaseOperationRecord r) => RebaseOperation._raw(
    type: RebaseOperationType.fromValue(r.type),
    id: Oid._(r.id),
    exec: r.exec,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RebaseOperation &&
          type == other.type &&
          id == other.id &&
          exec == other.exec);

  @override
  int get hashCode => Object.hash(type, id, exec);
}
