part of 'api.dart';

/// A file revision stored in the object database.
///
/// [Blob] exposes the content written to the repository under a given
/// [Oid]. Instances are OID-keyed: two [Blob]s for the same id compare
/// equal regardless of which lookup or creation produced them.
///
/// Instances own native memory and must be [dispose]d.
///
/// ```dart
/// final blob = Blob.fromBuffer(repo, utf8.encode('hello\n'));
/// print(blob.size);        // 6
/// print(blob.isBinary);    // false
/// print(blob.content);     // [104, 101, 108, 108, 111, 10]
/// blob.dispose();
/// ```
@immutable
final class Blob {
  static final _finalizer = Finalizer<int>(blobFree);

  final int _handle;

  /// The OID this blob is stored under.
  final Oid id;

  /// Looks up the blob at [id] in [repo].
  ///
  /// Throws [NotFoundException] when no blob with that id exists.
  factory Blob.lookup(Repository repo, Oid id) {
    final handle = blobLookup(repo._handle, id.bytes);
    return Blob._(handle, Oid._(blobId(handle)));
  }

  /// Looks up the blob identified by the first [prefixLength] hex
  /// characters of [oid].
  ///
  /// [prefixLength] must be at least [Oid.minPrefixLength] and long
  /// enough to resolve a single object.
  ///
  /// Throws [AmbiguousException] when multiple blobs share the
  /// prefix. Throws [NotFoundException] when no blob matches.
  factory Blob.lookupPrefix(Repository repo, Oid oid, int prefixLength) {
    final handle = blobLookupPrefix(repo._handle, oid.bytes, prefixLength);
    return Blob._(handle, Oid._(blobId(handle)));
  }

  /// Writes [bytes] to the object database as a new blob.
  factory Blob.fromBuffer(Repository repo, Uint8List bytes) {
    final oidBytes = blobCreateFromBuffer(repo._handle, bytes);
    return Blob.lookup(repo, Oid._(oidBytes));
  }

  /// Reads the file at [relativePath] inside [repo]'s working
  /// directory and writes it to the object database as a new blob.
  ///
  /// [repo] must not be bare.
  ///
  /// Throws [BareRepoException] when [repo] is bare. Throws
  /// [Libgit2Exception] when the file cannot be read.
  factory Blob.fromWorkDir(Repository repo, String relativePath) {
    final oidBytes = blobCreateFromWorkDir(repo._handle, relativePath);
    return Blob.lookup(repo, Oid._(oidBytes));
  }

  /// Reads the file at [path] on disk (not necessarily inside the
  /// working directory) and writes it to the object database as a
  /// new blob.
  ///
  /// Throws [Libgit2Exception] when the file cannot be read.
  factory Blob.fromDisk(Repository repo, String path) {
    final oidBytes = blobCreateFromDisk(repo._handle, path);
    return Blob.lookup(repo, Oid._(oidBytes));
  }

  /// Streams [chunks] into the object database as a new blob.
  ///
  /// [hintPath] (when non-null) selects the checkout filters that
  /// apply as the bytes are written. If the stream fails mid-write
  /// the partial write is discarded.
  factory Blob.fromStream(
    Repository repo,
    Iterable<Uint8List> chunks, {
    String? hintPath,
  }) {
    final stream = blobCreateFromStream(repo._handle, hintPath: hintPath);
    try {
      for (final chunk in chunks) {
        blobStreamWrite(stream, chunk);
      }
      final oid = blobCreateFromStreamCommit(stream);
      return Blob.lookup(repo, Oid._(oid));
    } on Object {
      blobStreamCancel(stream);
      rethrow;
    }
  }

  Blob._(this._handle, this.id) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// The raw content of this blob.
  ///
  /// Always a fresh copy. Mutating the returned buffer has no effect
  /// on the object stored in the repository.
  Uint8List get content => blobRawContent(_handle);

  /// The size in bytes of this blob's content.
  int get size => blobRawSize(_handle);

  /// Whether libgit2 classifies this blob as binary.
  ///
  /// The heuristic looks for NUL bytes and checks the ratio of
  /// printable to non-printable characters in the first 8000 bytes.
  bool get isBinary => blobIsBinary(_handle);

  /// Returns an in-memory copy of this blob.
  ///
  /// The copy owns native memory independent of the original and
  /// must be [dispose]d on its own.
  Blob dup() {
    final handle = blobDup(_handle);
    return Blob._(handle, id);
  }

  /// Runs the configured content filters over this blob as if it
  /// were being checked out to [asPath].
  ///
  /// [flags] combines [BlobFilterFlag] values. [attrCommitId] selects
  /// the commit whose `.gitattributes` should drive filter decisions
  /// when [flags] contains [BlobFilterFlag.attributesFromCommit].
  Uint8List filter(
    String asPath, {
    Set<BlobFilterFlag> flags = const {},
    Oid? attrCommitId,
  }) {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    return blobFilter(
      _handle,
      asPath,
      flags: bits,
      attrCommitId: attrCommitId?._bytes,
    );
  }

  /// Releases the native blob handle.
  void dispose() {
    _finalizer.detach(this);
    blobFree(_handle);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Blob && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Blob(${id.shortSha()})';

  /// Whether [data] looks binary by the same heuristic libgit2 applies
  /// to stored blobs.
  ///
  /// Useful when classifying bytes that have not yet been written to
  /// the object database.
  static bool isDataBinary(Uint8List data) => blobDataIsBinary(data);
}
