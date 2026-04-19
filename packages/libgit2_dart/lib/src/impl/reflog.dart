part of 'api.dart';

/// The reflog of a single reference.
///
/// A reflog records every value a reference has pointed at, together
/// with the committer that moved it and an optional message. Load one
/// through [Reflog.read], mutate it with [append] or [drop], and call
/// [write] to persist the changes to disk.
///
/// Instances own native memory and must be [dispose]d when no longer
/// needed.
///
/// ```dart
/// final log = Reflog.read(repo, 'HEAD');
/// try {
///   for (var i = 0; i < log.length; i++) {
///     print(log[i]);
///   }
/// } finally {
///   log.dispose();
/// }
/// ```
@immutable
final class Reflog {
  static final _finalizer = Finalizer<int>(reflogFree);

  final int _handle;

  /// Reads the reflog for the reference named [name] in [repo].
  ///
  /// Returns an empty [Reflog] when the reference has no reflog file
  /// yet.
  factory Reflog.read(Repository repo, String name) {
    return Reflog._(reflogRead(repo._handle, name));
  }

  Reflog._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// The number of entries in this reflog.
  int get length => reflogEntryCount(_handle);

  /// Returns the entry at [index].
  ///
  /// Index `0` returns the most recently created entry. The returned
  /// [ReflogEntry] is a value copy and remains valid after [dispose].
  ///
  /// Throws [RangeError] when [index] is outside `[0, length)`.
  ReflogEntry operator [](int index) {
    final count = length;
    if (index < 0 || index >= count) {
      throw RangeError.index(index, this, 'index', null, count);
    }
    final entryHandle = reflogEntryByIndex(_handle, index);
    final sigHandle = reflogEntryCommitter(entryHandle);
    final sig = signatureRead(sigHandle);
    return ReflogEntry._(
      oldId: Oid._(reflogEntryIdOld(entryHandle)),
      newId: Oid._(reflogEntryIdNew(entryHandle)),
      committer: Signature._(
        name: sig.name,
        email: sig.email,
        when: DateTime.fromMillisecondsSinceEpoch(sig.time * 1000, isUtc: true),
        offset: sig.offset,
      ),
      message: reflogEntryMessage(entryHandle),
    );
  }

  /// Appends an in-memory entry recording that the reference now
  /// points at [newId].
  ///
  /// [committer] is the actor that performed the update and
  /// [message] is an optional one-line description. Changes are held
  /// in memory until [write] is called.
  void append({
    required Oid newId,
    required Signature committer,
    String? message,
  }) {
    final record = committer._record;
    reflogAppend(
      _handle,
      id: newId._bytes,
      committerName: record.name,
      committerEmail: record.email,
      time: record.time,
      offset: record.offset,
      message: message,
    );
  }

  /// Releases the native reflog handle.
  void dispose() {
    _finalizer.detach(this);
    reflogFree(_handle);
  }

  /// Removes the entry at [index].
  ///
  /// When [rewritePreviousEntry] is `true` the previous entry's new
  /// OID is patched with this entry's new OID so no gap is left in
  /// the log history.
  ///
  /// Throws [NotFoundException] when no entry exists at [index].
  void drop(int index, {bool rewritePreviousEntry = false}) {
    reflogDrop(_handle, index, rewritePreviousEntry: rewritePreviousEntry);
  }

  /// Writes the in-memory reflog to disk using an atomic file lock.
  void write() => reflogWrite(_handle);
}

/// A single entry in a [Reflog].
///
/// [ReflogEntry] is a pure Dart value type: every field is copied out
/// of the underlying entry at construction time, so the value remains
/// valid after the parent [Reflog] is disposed.
@immutable
final class ReflogEntry {
  /// The [Oid] the reference pointed at before this entry was
  /// recorded.
  final Oid oldId;

  /// The [Oid] the reference was moved to when this entry was
  /// recorded.
  final Oid newId;

  /// The actor that recorded this entry.
  final Signature committer;

  /// The log message recorded with this entry, or `null` when none
  /// was provided.
  final String? message;

  const ReflogEntry._({
    required this.oldId,
    required this.newId,
    required this.committer,
    this.message,
  });

  @override
  int get hashCode => Object.hash(oldId, newId, committer, message);

  @override
  bool operator ==(Object other) =>
      other is ReflogEntry &&
      oldId == other.oldId &&
      newId == other.newId &&
      committer == other.committer &&
      message == other.message;

  @override
  String toString() => 'ReflogEntry($oldId -> $newId by $committer)';
}

/// Reflog operations on [Repository].
extension RepositoryReflog on Repository {
  /// Deletes the reflog for the reference named [name].
  void deleteReflog(String name) => reflogDelete(_handle, name);

  /// Renames the reflog from [oldName] to [newName].
  ///
  /// The reflog at [oldName] is expected to already exist.
  ///
  /// Throws [InvalidValueException] when [newName] is not a valid
  /// reference name.
  void renameReflog(String oldName, String newName) {
    reflogRename(_handle, oldName, newName);
  }
}
