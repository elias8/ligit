part of 'api.dart';

/// A streaming packfile indexer.
///
/// Assembles a `.pack` / `.idx` pair inside a directory from an
/// incoming stream of packfile bytes. Feed chunks through [append]
/// as they arrive, finalize with [commit], then read the resulting
/// packfile's canonical [name]. Must be [dispose]d when done.
///
/// ```dart
/// final indexer = Indexer('/tmp/pack-dir');
/// try {
///   for (final chunk in packStream) {
///     indexer.append(chunk);
///   }
///   final progress = indexer.commit();
///   print('${indexer.name}: ${progress.totalObjects} objects');
/// } finally {
///   indexer.dispose();
/// }
/// ```
@immutable
final class Indexer {
  static final _finalizer = Finalizer<int>(indexerFree);

  final int _handle;

  /// Creates a new indexer that writes into [directoryPath].
  ///
  /// [mode] sets file permissions on the resulting packfile; `0`
  /// picks the default. [odb] lets the indexer resolve thin-pack
  /// bases against an existing object database — pass `null` when
  /// no thin pack is expected. When [verify] is true a connectivity
  /// check runs against the completed pack before finalizing.
  factory Indexer(
    String directoryPath, {
    int mode = 0,
    Odb? odb,
    bool verify = false,
  }) => Indexer._(
    indexerNew(
      directoryPath,
      mode: mode,
      odbHandle: odb?._handle ?? 0,
      verify: verify,
    ),
  );

  Indexer._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Unique name of the resulting packfile.
  ///
  /// Derived from the packfile's content; only valid after [commit].
  String get name => indexerName(_handle);

  /// Feeds [data] into the indexer.
  ///
  /// Returns the latest progress snapshot.
  IndexerProgress append(Uint8List data) => _wrap(indexerAppend(_handle, data));

  /// Resolves pending deltas and writes the pack index to disk.
  ///
  /// Returns the final progress snapshot. [name] becomes valid
  /// after this call.
  IndexerProgress commit() => _wrap(indexerCommit(_handle));

  /// Releases the indexer and its resources.
  void dispose() {
    _finalizer.detach(this);
    indexerFree(_handle);
  }

  static IndexerProgress _wrap(IndexerProgressRecord r) {
    return IndexerProgress._(
      totalObjects: r.totalObjects,
      indexedObjects: r.indexedObjects,
      receivedObjects: r.receivedObjects,
      localObjects: r.localObjects,
      totalDeltas: r.totalDeltas,
      indexedDeltas: r.indexedDeltas,
      receivedBytes: r.receivedBytes,
    );
  }
}

/// Snapshot of packfile indexing progress.
///
/// Reported by every call that advances or finalizes an [Indexer],
/// and by fetch and clone operations that download a packfile.
/// Values are cumulative since the start of the indexing run.
@immutable
final class IndexerProgress {
  /// Number of objects in the packfile being indexed.
  final int totalObjects;

  /// Received objects that have been hashed so far.
  final int indexedObjects;

  /// Objects that have been downloaded.
  final int receivedObjects;

  /// Locally-available objects that were injected to fix a thin
  /// pack.
  final int localObjects;

  /// Number of deltas in the packfile being indexed.
  final int totalDeltas;

  /// Received deltas that have been indexed.
  final int indexedDeltas;

  /// Size of the packfile received so far, in bytes.
  final int receivedBytes;

  const IndexerProgress._({
    required this.totalObjects,
    required this.indexedObjects,
    required this.receivedObjects,
    required this.localObjects,
    required this.totalDeltas,
    required this.indexedDeltas,
    required this.receivedBytes,
  });

  @override
  int get hashCode => Object.hash(
    totalObjects,
    indexedObjects,
    receivedObjects,
    localObjects,
    totalDeltas,
    indexedDeltas,
    receivedBytes,
  );

  @override
  bool operator ==(Object other) =>
      other is IndexerProgress &&
      totalObjects == other.totalObjects &&
      indexedObjects == other.indexedObjects &&
      receivedObjects == other.receivedObjects &&
      localObjects == other.localObjects &&
      totalDeltas == other.totalDeltas &&
      indexedDeltas == other.indexedDeltas &&
      receivedBytes == other.receivedBytes;

  @override
  String toString() =>
      'IndexerProgress($indexedObjects/$totalObjects objects, '
      '$indexedDeltas/$totalDeltas deltas, $receivedBytes bytes)';
}
