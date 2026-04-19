import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'buffer.dart' show bufBytes;
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show BlobFilterFlag;

int blobLookup(int repoHandle, Uint8List oidBytes) {
  return using((arena) {
    final out = arena<Pointer<Blob>>();
    final oid = _allocOid(arena, oidBytes);
    checkCode(git_blob_lookup(out, _repo(repoHandle), oid));
    return out.value.address;
  });
}

int blobLookupPrefix(int repoHandle, Uint8List oidBytes, int prefixLength) {
  return using((arena) {
    final out = arena<Pointer<Blob>>();
    final oid = _allocOid(arena, oidBytes);
    checkCode(
      git_blob_lookup_prefix(out, _repo(repoHandle), oid, prefixLength),
    );
    return out.value.address;
  });
}

void blobFree(int handle) => git_blob_free(_blob(handle));

Uint8List blobId(int handle) {
  return _oidBytes(git_blob_id(_blob(handle)));
}

int blobOwner(int handle) {
  return git_blob_owner(_blob(handle)).address;
}

Uint8List blobRawContent(int handle) {
  final blob = _blob(handle);
  final size = git_blob_rawsize(blob);
  final ptr = git_blob_rawcontent(blob);
  if (ptr == nullptr || size == 0) return Uint8List(0);
  return Uint8List.fromList(ptr.cast<Uint8>().asTypedList(size));
}

int blobRawSize(int handle) => git_blob_rawsize(_blob(handle));

Uint8List blobCreateFromWorkDir(int repoHandle, String relativePath) {
  return using((arena) {
    final out = arena<Oid>();
    final cPath = relativePath.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_blob_create_from_workdir(out, _repo(repoHandle), cPath));
    return _oidBytes(out);
  });
}

Uint8List blobCreateFromDisk(int repoHandle, String path) {
  return using((arena) {
    final out = arena<Oid>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_blob_create_from_disk(out, _repo(repoHandle), cPath));
    return _oidBytes(out);
  });
}

Uint8List blobCreateFromBuffer(int repoHandle, Uint8List bytes) {
  return using((arena) {
    final out = arena<Oid>();
    final len = bytes.length;
    final buf = arena<Uint8>(len);
    for (var i = 0; i < len; i++) {
      buf[i] = bytes[i];
    }
    checkCode(
      git_blob_create_from_buffer(
        out,
        _repo(repoHandle),
        buf.cast<Void>(),
        len,
      ),
    );
    return _oidBytes(out);
  });
}

bool blobIsBinary(int handle) => git_blob_is_binary(_blob(handle)) == 1;

bool blobDataIsBinary(Uint8List data) {
  return using((arena) {
    final len = data.length;
    final buf = arena<Uint8>(len);
    for (var i = 0; i < len; i++) {
      buf[i] = data[i];
    }
    return git_blob_data_is_binary(buf.cast<Char>(), len) == 1;
  });
}

int blobDup(int handle) {
  return using((arena) {
    final out = arena<Pointer<Blob>>();
    checkCode(git_blob_dup(out, _blob(handle)));
    return out.value.address;
  });
}

Uint8List blobFilter(
  int handle,
  String asPath, {
  int flags = 0,
  Uint8List? attrCommitId,
}) {
  return using((arena) {
    final out = arena<Buf>();
    final cPath = asPath.toNativeUtf8(allocator: arena).cast<Char>();
    final opts = arena<BlobFilterOptions>();
    checkCode(
      git_blob_filter_options_init(opts, GIT_BLOB_FILTER_OPTIONS_VERSION),
    );
    opts.ref.flags = flags;
    if (attrCommitId != null) {
      for (var i = 0; i < attrCommitId.length; i++) {
        opts.ref.attr_commit_id.id[i] = attrCommitId[i];
      }
    }
    checkCode(git_blob_filter(out, _blob(handle), cPath, opts));
    return bufBytes(out);
  });
}

int blobCreateFromStream(int repoHandle, {String? hintPath}) {
  return using((arena) {
    final out = arena<Pointer<Writestream>>();
    final cHint = hintPath == null
        ? nullptr.cast<Char>()
        : hintPath.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_blob_create_from_stream(out, _repo(repoHandle), cHint));
    return out.value.address;
  });
}

void blobStreamWrite(int streamHandle, Uint8List bytes) {
  using((arena) {
    final stream = _stream(streamHandle);
    final buf = arena<Uint8>(bytes.length);
    for (var i = 0; i < bytes.length; i++) {
      buf[i] = bytes[i];
    }
    final write = stream.ref.write
        .asFunction<int Function(Pointer<Writestream>, Pointer<Char>, int)>();
    checkCode(write(stream, buf.cast<Char>(), bytes.length));
  });
}

Uint8List blobCreateFromStreamCommit(int streamHandle) {
  return using((arena) {
    final out = arena<Oid>();
    checkCode(git_blob_create_from_stream_commit(out, _stream(streamHandle)));
    return _oidBytes(out);
  });
}

void blobStreamCancel(int streamHandle) {
  final stream = _stream(streamHandle);
  final free = stream.ref.free
      .asFunction<void Function(Pointer<Writestream>)>();
  free(stream);
}

Pointer<Blob> _blob(int handle) => Pointer<Blob>.fromAddress(handle);

Pointer<Writestream> _stream(int handle) =>
    Pointer<Writestream>.fromAddress(handle);

Pointer<Repository> _repo(int handle) {
  return Pointer<Repository>.fromAddress(handle);
}

Pointer<Oid> _allocOid(Allocator arena, Uint8List bytes) {
  final out = arena<Oid>();
  for (var i = 0; i < 20; i++) {
    out.ref.id[i] = bytes[i];
  }
  return out;
}

Uint8List _oidBytes(Pointer<Oid> ptr) {
  final out = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    out[i] = ptr.ref.id[i];
  }
  return out;
}
