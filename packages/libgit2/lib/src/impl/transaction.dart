part of 'api.dart';

/// An atomic reference-update transaction.
///
/// A [Transaction] queues reference mutations and commits them in
/// one shot. Lock each reference you intend to touch with
/// [lockReference], stage the updates with [setTarget],
/// [setSymbolicTarget], [setReflog], or [remove], then [commit] to
/// apply them all. [dispose] unlocks any still-locked references
/// without writing.
///
/// The transaction owns a native handle and must be [dispose]d.
///
/// ```dart
/// final tx = Transaction(repo);
/// tx.lockReference('refs/heads/main');
/// tx.setTarget('refs/heads/main', newHeadId);
/// tx.commit();
/// tx.dispose();
/// ```
@immutable
final class Transaction {
  static final _finalizer = Finalizer<int>(transactionFree);

  final int _handle;

  /// Creates a new transaction on [repo].
  factory Transaction(Repository repo) =>
      Transaction._(transactionNew(repo._handle));

  Transaction._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Locks [refname] in preparation for updating it.
  ///
  /// Must run for every reference this transaction reads or
  /// mutates.
  void lockReference(String refname) => transactionLockRef(_handle, refname);

  /// Stages setting the direct target of the locked [refname] to
  /// [target].
  ///
  /// Pass [signature] to override the reflog identity (otherwise
  /// the repository's configured identity is used). [message] is
  /// the reflog message.
  ///
  /// Throws [NotFoundException] when [refname] is not locked.
  void setTarget(
    String refname,
    Oid target, {
    Signature? signature,
    String? message,
  }) {
    final sigHandle = signature == null
        ? 0
        : signatureNew(
            signature.name,
            signature.email,
            signature._record.time,
            signature._record.offset,
          );
    try {
      transactionSetTarget(
        _handle,
        refname,
        target._bytes,
        signatureHandle: sigHandle,
        message: message,
      );
    } finally {
      if (sigHandle != 0) signatureFree(sigHandle);
    }
  }

  /// Stages setting the symbolic target of [refname] to [target].
  ///
  /// See [setTarget] for the signature and message parameters.
  void setSymbolicTarget(
    String refname,
    String target, {
    Signature? signature,
    String? message,
  }) {
    final sigHandle = signature == null
        ? 0
        : signatureNew(
            signature.name,
            signature.email,
            signature._record.time,
            signature._record.offset,
          );
    try {
      transactionSetSymbolicTarget(
        _handle,
        refname,
        target,
        signatureHandle: sigHandle,
        message: message,
      );
    } finally {
      if (sigHandle != 0) signatureFree(sigHandle);
    }
  }

  /// Replaces the reflog of [refname] with [reflog].
  ///
  /// When combined with [setTarget] in the same transaction, the
  /// target update itself is not written to the reflog; only the
  /// supplied entries end up recorded.
  void setReflog(String refname, Reflog reflog) {
    transactionSetReflog(_handle, refname, reflog._handle);
  }

  /// Queues removal of the locked reference [refname].
  ///
  /// Throws [NotFoundException] when [refname] is not locked.
  void remove(String refname) => transactionRemove(_handle, refname);

  /// Applies every queued update atomically.
  ///
  /// Updates run in order; the first failure aborts the rest and
  /// leaves already-applied updates in place.
  void commit() => transactionCommit(_handle);

  /// Releases the native transaction handle, unlocking any
  /// still-locked references without writing them.
  void dispose() {
    _finalizer.detach(this);
    transactionFree(_handle);
  }
}

/// Locks a [Config] via a [Transaction] for atomic multi-write.
extension ConfigLockExt on Config {
  /// Locks the highest-priority writable backend of this config and
  /// returns a [Transaction] that commits or rolls back the pending
  /// writes.
  Transaction lock() => Transaction._(configLock(_handle));
}
