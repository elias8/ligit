part of 'api.dart';

/// The Git object database: a content-addressable store keyed by
/// [Oid].
///
/// An [Odb] queries the backends it owns for reads and writes. Open
/// the database installed on a repository through
/// [RepositoryOdbExt.odb], load one rooted at an `objects/` directory
/// with [Odb.fromObjectsDir], or start an empty instance with
/// [Odb.inMemory] and attach backends via [OdbBackendOps.addBackend].
/// Must be [dispose]d when done.
///
/// ```dart
/// final odb = Odb.fromObjectsDir('/path/to/.git/objects');
/// try {
///   if (odb.contains(oid)) {
///     final obj = odb.read(oid);
///     try {
///       print('${obj.type} ${obj.size}');
///     } finally {
///       obj.dispose();
///     }
///   }
/// } finally {
///   odb.dispose();
/// }
/// ```
@immutable
final class Odb {
  static final _finalizer = Finalizer<int>(odbFree);

  final int _handle;

  /// Creates a new object database with no backends.
  ///
  /// Before the returned [Odb] can be used for reads or writes a
  /// backend must be attached with [OdbBackendOps.addBackend].
  factory Odb.inMemory() => Odb._(odbNew());

  /// Creates an object database rooted at [objectsDir] with the
  /// default loose and packed backends attached.
  ///
  /// [objectsDir] is the `objects/` folder of a `.git` directory.
  factory Odb.fromObjectsDir(String objectsDir) => Odb._(odbOpen(objectsDir));

  Odb._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Returns the [Oid] [data] would have if written as an object of
  /// [type], without touching any database.
  static Oid hash(Uint8List data, ObjectType type) =>
      Oid._(odbHash(data, type.value));

  /// Returns the [Oid] the file at [path] would have if written as
  /// an object of [type], without touching any database.
  static Oid hashFile(String path, ObjectType type) =>
      Oid._(odbHashFile(path, type.value));

  /// Number of backends attached to this database.
  int get backendCount => odbNumBackends(_handle);

  /// Adds the directory at [path] as an on-disk alternate store.
  ///
  /// [path] must point to an `objects/` directory, not to a full
  /// repository.
  void addDiskAlternate(String path) => odbAddDiskAlternate(_handle, path);

  /// Reloads the underlying backend indexes from disk.
  ///
  /// Call when the object databases may have changed on disk while
  /// this instance was open.
  void refresh() => odbRefresh(_handle);

  /// Whether the object [oid] is present in any backend.
  bool contains(Oid oid) => odbExists(_handle, oid._bytes);

  /// Resolves the prefix [shortId] of [length] hex characters to a
  /// full [Oid], or returns null when no object matches.
  ///
  /// Throws [AmbiguousException] when multiple objects match.
  Oid? containsPrefix(Oid shortId, int length) {
    final bytes = odbExistsPrefix(_handle, shortId._bytes, length);
    return bytes == null ? null : Oid._(bytes);
  }

  /// Reads the size and type of the object at [oid] without loading
  /// its contents.
  ({int size, ObjectType type}) header(Oid oid) {
    final r = odbReadHeader(_handle, oid._bytes);
    return (size: r.size, type: ObjectType.fromValue(r.type));
  }

  /// Reads the object at [oid], querying every attached backend.
  ///
  /// Callers must [OdbObject.dispose] the returned object.
  OdbObject read(Oid oid) => OdbObject._(odbRead(_handle, oid._bytes));

  /// Reads the object whose id starts with the first [length] hex
  /// characters of [shortId].
  ///
  /// Callers must [OdbObject.dispose] the returned object.
  OdbObject readPrefix(Oid shortId, int length) =>
      OdbObject._(odbReadPrefix(_handle, shortId._bytes, length));

  /// Writes [data] of [type] directly into the database and returns
  /// the resulting [Oid].
  ///
  /// For large objects prefer [openWriteStream] over this method.
  Oid write(Uint8List data, ObjectType type) =>
      Oid._(odbWrite(_handle, data, type.value));

  /// Invokes [onObject] for every object in this database.
  ///
  /// Returning a non-zero value from [onObject] stops iteration.
  void foreach(int Function(Oid oid) onObject) =>
      odbForeach(_handle, (bytes) => onObject(Oid._(bytes)));

  /// Installs the commit-graph identified by [commitGraphAddress].
  ///
  /// Pass `0` to clear any previously installed commit-graph.
  /// Ownership of the commit-graph transfers to this database.
  void setCommitGraph(int commitGraphAddress) =>
      odbSetCommitGraph(_handle, commitGraphAddress);

  /// Resolves every short id in [shortIds] to its full [Oid].
  ///
  /// Each input supplies the candidate bytes, the number of valid
  /// nibbles (4-bit packets), and the expected [ObjectType] — use
  /// [ObjectType.any] to accept any type. Entries that could not be
  /// resolved come back with a `length` of zero.
  List<({Oid id, int length, ObjectType type})> expandIds(
    List<({Uint8List id, int length, ObjectType type})> shortIds,
  ) {
    final raw = odbExpandIds(_handle, [
      for (final s in shortIds)
        (id: s.id, length: s.length, type: s.type.value),
    ]);
    return [
      for (final r in raw)
        (id: Oid._(r.id), length: r.length, type: ObjectType.fromValue(r.type)),
    ];
  }

  /// Opens a stream that reads the object at [oid] incrementally.
  ///
  /// Most backends store compressed or delta-encoded blobs and
  /// therefore do not support streaming reads; expect the stream to
  /// fail for those objects. Callers must [OdbReadStream.dispose]
  /// the returned stream.
  OdbReadStream openReadStream(Oid oid) {
    final r = odbOpenRstream(_handle, oid._bytes);
    return OdbReadStream._(r.handle, r.size, ObjectType.fromValue(r.type));
  }

  /// Opens a stream that writes a new object of [type] and [size]
  /// bytes.
  ///
  /// The type and total length must be supplied up front. Callers
  /// must [OdbWriteStream.dispose] the returned stream.
  OdbWriteStream openWriteStream(int size, ObjectType type) =>
      OdbWriteStream._(odbOpenWstream(_handle, size, type.value));

  /// Writes a `multi-pack-index` file covering every `.pack` in this
  /// database, enabling O(log n) lookups across them.
  void writeMultiPackIndex() => odbWriteMultiPackIndex(_handle);

  /// Releases the object database.
  void dispose() {
    _finalizer.detach(this);
    odbFree(_handle);
  }
}

/// Incremental read over an object stored in an [Odb].
///
/// Returned by [Odb.openReadStream]. Drain the object through [read]
/// and [dispose] the stream when done.
@immutable
final class OdbReadStream {
  final int _handle;

  /// Total size of the streamed object in bytes.
  final int size;

  /// Type of the streamed object.
  final ObjectType type;

  static final _finalizer = Finalizer<int>(odbStreamFree);

  OdbReadStream._(this._handle, this.size, this.type) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Reads up to [max] bytes from the stream.
  ///
  /// Returns an empty buffer once the object is fully drained.
  Uint8List read(int max) => odbStreamRead(_handle, max);

  /// Releases the stream.
  void dispose() {
    _finalizer.detach(this);
    odbStreamFree(_handle);
  }
}

/// Incremental write of a new object into an [Odb].
///
/// Returned by [Odb.openWriteStream]. Feed the object's bytes
/// through [write] then call [finalize] to commit and obtain the
/// resulting [Oid]. [dispose] releases the stream whether or not it
/// was finalized; writing more bytes than the declared size fails.
@immutable
final class OdbWriteStream {
  final int _handle;

  static final _finalizer = Finalizer<int>(odbStreamFree);

  OdbWriteStream._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Writes [data] to the stream.
  void write(Uint8List data) => odbStreamWrite(_handle, data);

  /// Commits the stream and returns the [Oid] of the new object.
  ///
  /// [dispose] must still be called afterwards.
  Oid finalize() => Oid._(odbStreamFinalizeWrite(_handle));

  /// Releases the stream.
  void dispose() {
    _finalizer.detach(this);
    odbStreamFree(_handle);
  }
}

/// An object read out of an [Odb]: id, type, size, and bytes.
///
/// Returned by [Odb.read] and [Odb.readPrefix]. The byte data is
/// copied into Dart memory at construction so this instance stays
/// valid after [Odb.dispose]. Must be [dispose]d when done.
@immutable
final class OdbObject {
  static final _finalizer = Finalizer<int>(odbObjectFree);

  /// The object's [Oid].
  final Oid id;

  /// Git object type — commit, tree, blob, or tag.
  final ObjectType type;

  /// Size of the raw object in bytes.
  final int size;

  /// Raw, uncompressed object bytes, without the object header.
  final Uint8List data;

  final int _handle;

  OdbObject._raw({
    required int handle,
    required this.id,
    required this.type,
    required this.size,
    required this.data,
  }) : _handle = handle {
    _finalizer.attach(this, _handle, detach: this);
  }

  factory OdbObject._(int handle) {
    final r = odbObjectRead(handle);
    return OdbObject._raw(
      handle: handle,
      id: Oid._(r.id),
      type: ObjectType.fromValue(r.type),
      size: r.size,
      data: r.data,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OdbObject &&
          id == other.id &&
          type == other.type &&
          size == other.size);

  @override
  int get hashCode => Object.hash(id, type, size);

  /// Releases the object.
  void dispose() {
    _finalizer.detach(this);
    odbObjectFree(_handle);
  }
}

/// Object-database operations on [Repository].
extension RepositoryOdbExt on Repository {
  /// Returns the object database attached to this repository.
  ///
  /// Callers must [Odb.dispose] the returned instance.
  Odb odb() => Odb._(repositoryOdb(_handle));
}

/// Wraps an [Odb] as a standalone [Repository].
extension OdbAsRepository on Odb {
  /// Wraps this database as a repository with no workdir or
  /// `.git` directory.
  ///
  /// Suitable for APIs that require a [Repository] but only read
  /// from or write to the object database. The returned instance
  /// reports an empty path and must be [Repository.dispose]d.
  Repository asRepository() {
    final handle = repositoryWrapOdb(_handle);
    return Repository._(handle, repositoryPath(handle));
  }
}
