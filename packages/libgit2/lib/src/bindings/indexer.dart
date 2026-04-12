import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

typedef IndexerProgressRecord = ({
  int totalObjects,
  int indexedObjects,
  int receivedObjects,
  int localObjects,
  int totalDeltas,
  int indexedDeltas,
  int receivedBytes,
});

int indexerNew(
  String directoryPath, {
  int mode = 0,
  int odbHandle = 0,
  bool verify = false,
}) {
  return using((arena) {
    final out = arena<Pointer<Indexer>>();
    final cPath = directoryPath.toNativeUtf8(allocator: arena).cast<Char>();
    final opts = arena<IndexerOptions>();
    checkCode(git_indexer_options_init(opts, GIT_INDEXER_OPTIONS_VERSION));
    opts.ref.verify = verify ? 1 : 0;
    checkCode(
      git_indexer_new(
        out,
        cPath,
        mode,
        odbHandle == 0
            ? nullptr.cast<Odb>()
            : Pointer<Odb>.fromAddress(odbHandle),
        opts,
      ),
    );
    return out.value.address;
  });
}

IndexerProgressRecord indexerAppend(int handle, Uint8List data) {
  return using((arena) {
    final bytes = arena<Uint8>(data.length);
    for (var i = 0; i < data.length; i++) {
      bytes[i] = data[i];
    }
    final stats = arena<IndexerProgress>();
    checkCode(
      git_indexer_append(_indexer(handle), bytes.cast(), data.length, stats),
    );
    return _progress(stats);
  });
}

IndexerProgressRecord indexerCommit(int handle) {
  return using((arena) {
    final stats = arena<IndexerProgress>();
    checkCode(git_indexer_commit(_indexer(handle), stats));
    return _progress(stats);
  });
}

String indexerName(int handle) {
  final ptr = git_indexer_name(_indexer(handle));
  if (ptr == nullptr) return '';
  return ptr.cast<Utf8>().toDartString();
}

void indexerFree(int handle) => git_indexer_free(_indexer(handle));

IndexerProgressRecord _progress(Pointer<IndexerProgress> stats) {
  final s = stats.ref;
  return (
    totalObjects: s.total_objects,
    indexedObjects: s.indexed_objects,
    receivedObjects: s.received_objects,
    localObjects: s.local_objects,
    totalDeltas: s.total_deltas,
    indexedDeltas: s.indexed_deltas,
    receivedBytes: s.received_bytes,
  );
}

Pointer<Indexer> _indexer(int handle) => Pointer<Indexer>.fromAddress(handle);
