part of 'api.dart';

/// Builds a Git packfile out of individual objects, trees, commits,
/// or revision walks.
///
/// Creation is a two-step flow: insert objects in recency order
/// (commits, then trees, then blobs) using the `insert*` methods,
/// then produce the pack with [write], [writeToBuffer], or
/// [foreach]. Delta ordering and generation are handled internally,
/// with thread tuning available via [setThreads]. Must be [dispose]d
/// when done.
///
/// ```dart
/// final pb = PackBuilder.forRepository(repo);
/// try {
///   pb.insertCommit(commitId);
///   pb.write(path: '/tmp/packs');
///   print(pb.name);
/// } finally {
///   pb.dispose();
/// }
/// ```
@immutable
final class PackBuilder {
  static final _finalizer = Finalizer<int>(packbuilderFree);

  final int _handle;

  /// Creates a packbuilder that packs objects from [repo].
  factory PackBuilder.forRepository(Repository repo) =>
      PackBuilder._(packbuilderNew(repo._handle));

  PackBuilder._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Total number of objects this packbuilder will write out.
  int get objectCount => packbuilderObjectCount(_handle);

  /// Number of objects already written out.
  int get written => packbuilderWritten(_handle);

  /// Unique name for the resulting packfile.
  ///
  /// Derived from the packfile's content and only correct after a
  /// successful [write] or [writeToBuffer].
  String get name => packbuilderName(_handle);

  /// Sets the number of worker threads used for deltification.
  ///
  /// By default no threads are spawned. Pass `0` to autodetect the
  /// number of CPUs. Returns the number of threads that will
  /// actually be used.
  int setThreads(int count) => packbuilderSetThreads(_handle, count);

  /// Inserts a single object identified by [oid].
  ///
  /// For an optimal pack, insert objects in recency order — commits
  /// followed by trees and blobs.
  void insert(Oid oid, {String? name}) =>
      packbuilderInsert(_handle, oid._bytes, name: name);

  /// Inserts the root tree at [oid] together with every tree and
  /// blob it references.
  void insertTree(Oid oid) => packbuilderInsertTree(_handle, oid._bytes);

  /// Inserts the commit at [oid] along with its complete tree.
  void insertCommit(Oid oid) => packbuilderInsertCommit(_handle, oid._bytes);

  /// Inserts every commit produced by [walk] and all the objects
  /// they reference.
  void insertWalk(Revwalk walk) => packbuilderInsertWalk(_handle, walk._handle);

  /// Inserts the object at [oid] and recursively every object it
  /// references.
  void insertRecursive(Oid oid, {String? name}) =>
      packbuilderInsertRecur(_handle, oid._bytes, name: name);

  /// Writes the pack and its index to [path].
  ///
  /// When [path] is null the pack is written into the repository's
  /// default pack directory. [mode] sets file permissions on the
  /// resulting files; `0` picks the default.
  void write({String? path, int mode = 0}) =>
      packbuilderWrite(_handle, path: path, mode: mode);

  /// Writes the pack to an in-memory buffer and returns its bytes.
  ///
  /// The buffer is a valid packfile even without an attached index.
  Uint8List writeToBuffer() => packbuilderWriteBuf(_handle);

  /// Builds the pack and invokes [onObject] with each packed
  /// object's bytes.
  ///
  /// Returning a non-zero value from [onObject] aborts the build.
  void foreach(int Function(Uint8List buffer) onObject) =>
      packbuilderForeach(_handle, onObject);

  /// Installs a progress [callback] fired during packbuilding.
  ///
  /// The callback receives the current [PackbuilderStage] value, the
  /// current object index, and the total object count. Returning a
  /// non-zero value aborts the pack operation. Pass `null` to clear
  /// a previously installed callback.
  ///
  /// Runs inline with pack building, so heavy work may affect
  /// performance.
  ///
  /// Returns a disposer that must be invoked once the packbuilder
  /// operation completes (typically right before [dispose]), or
  /// `null` when [callback] is null.
  void Function()? setProgressCallback(
    int Function(int stage, int current, int total)? callback,
  ) => packbuilderSetCallbacks(_handle, callback);

  /// Releases the packbuilder and all associated data.
  void dispose() {
    _finalizer.detach(this);
    packbuilderFree(_handle);
  }
}
