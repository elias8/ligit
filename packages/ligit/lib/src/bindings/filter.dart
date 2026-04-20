import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show FilterFlag, FilterMode;

int filterListLoad(
  int repoHandle,
  String path,
  int mode, {
  int blobHandle = 0,
  int flags = 0,
}) {
  return using((arena) {
    final out = arena<Pointer<FilterList>>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_filter_list_load(
        out,
        _repo(repoHandle),
        blobHandle == 0
            ? nullptr.cast<Blob>()
            : Pointer<Blob>.fromAddress(blobHandle),
        cPath,
        FilterMode.fromValue(mode),
        flags,
      ),
    );
    return out.value.address;
  });
}

int filterListLoadExt(
  int repoHandle,
  String path,
  int mode, {
  int blobHandle = 0,
  int flags = 0,
  Uint8List? attrCommitId,
}) {
  return using((arena) {
    final out = arena<Pointer<FilterList>>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final opts = arena<FilterOptions>();
    opts.ref.version = GIT_FILTER_OPTIONS_VERSION;
    opts.ref.flags = flags;
    if (attrCommitId != null) {
      for (var i = 0; i < attrCommitId.length; i++) {
        opts.ref.attr_commit_id.id[i] = attrCommitId[i];
      }
    }
    checkCode(
      git_filter_list_load_ext(
        out,
        _repo(repoHandle),
        blobHandle == 0
            ? nullptr.cast<Blob>()
            : Pointer<Blob>.fromAddress(blobHandle),
        cPath,
        FilterMode.fromValue(mode),
        opts,
      ),
    );
    return out.value.address;
  });
}

void filterListFree(int handle) => git_filter_list_free(_filters(handle));

bool filterListContains(int handle, String name) {
  return using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    return git_filter_list_contains(_filters(handle), cName) == 1;
  });
}

Uint8List filterListApplyToBuffer(int handle, Uint8List data) {
  return using((arena) {
    final out = arena<Buf>();
    final bytes = arena<Uint8>(data.length);
    for (var i = 0; i < data.length; i++) {
      bytes[i] = data[i];
    }
    checkCode(
      git_filter_list_apply_to_buffer(
        out,
        _filters(handle),
        bytes.cast<Char>(),
        data.length,
      ),
    );
    try {
      return _readBuf(out);
    } finally {
      git_buf_dispose(out);
    }
  });
}

Uint8List filterListApplyToFile(int handle, int repoHandle, String path) {
  return using((arena) {
    final out = arena<Buf>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_filter_list_apply_to_file(
        out,
        _filters(handle),
        _repo(repoHandle),
        cPath,
      ),
    );
    try {
      return _readBuf(out);
    } finally {
      git_buf_dispose(out);
    }
  });
}

void filterListStreamBuffer(
  int handle,
  Uint8List data,
  void Function(Uint8List chunk) onChunk,
) {
  using((arena) {
    final bytes = arena<Uint8>(data.length);
    for (var i = 0; i < data.length; i++) {
      bytes[i] = data[i];
    }
    _runWithStream(arena, onChunk, (stream) {
      checkCode(
        git_filter_list_stream_buffer(
          _filters(handle),
          bytes.cast<Char>(),
          data.length,
          stream,
        ),
      );
    });
  });
}

void filterListStreamBlob(
  int handle,
  int blobHandle,
  void Function(Uint8List chunk) onChunk,
) {
  using((arena) {
    _runWithStream(arena, onChunk, (stream) {
      checkCode(
        git_filter_list_stream_blob(
          _filters(handle),
          Pointer<Blob>.fromAddress(blobHandle),
          stream,
        ),
      );
    });
  });
}

void filterListStreamFile(
  int handle,
  int repoHandle,
  String path,
  void Function(Uint8List chunk) onChunk,
) {
  using((arena) {
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    _runWithStream(arena, onChunk, (stream) {
      checkCode(
        git_filter_list_stream_file(
          _filters(handle),
          _repo(repoHandle),
          cPath,
          stream,
        ),
      );
    });
  });
}

void _runWithStream(
  Allocator arena,
  void Function(Uint8List chunk) onChunk,
  void Function(Pointer<Writestream> stream) action,
) {
  final stream = arena<Writestream>();
  final writeCb =
      NativeCallable<
        Int Function(Pointer<Writestream>, Pointer<Char>, Size)
      >.isolateLocal((Pointer<Writestream> _, Pointer<Char> buffer, int len) {
        try {
          final src = buffer.cast<Uint8>();
          final data = Uint8List(len);
          for (var i = 0; i < len; i++) {
            data[i] = src[i];
          }
          onChunk(data);
          return 0;
        } on Object {
          return -1;
        }
      }, exceptionalReturn: -1);
  final closeCb =
      NativeCallable<Int Function(Pointer<Writestream>)>.isolateLocal(
        (Pointer<Writestream> _) => 0,
        exceptionalReturn: 0,
      );
  final freeCb =
      NativeCallable<Void Function(Pointer<Writestream>)>.isolateLocal(
        (Pointer<Writestream> _) {},
      );
  stream.ref.write = writeCb.nativeFunction;
  stream.ref.close = closeCb.nativeFunction;
  stream.ref.free = freeCb.nativeFunction;
  try {
    action(stream);
  } finally {
    writeCb.close();
    closeCb.close();
    freeCb.close();
  }
}

Uint8List filterListApplyToBlob(int handle, int blobHandle) {
  return using((arena) {
    final out = arena<Buf>();
    checkCode(
      git_filter_list_apply_to_blob(
        out,
        _filters(handle),
        Pointer<Blob>.fromAddress(blobHandle),
      ),
    );
    try {
      return _readBuf(out);
    } finally {
      git_buf_dispose(out);
    }
  });
}

Uint8List _readBuf(Pointer<Buf> buf) {
  final bytes = buf.ref.ptr.cast<Uint8>();
  final len = buf.ref.size;
  final data = Uint8List(len);
  for (var i = 0; i < len; i++) {
    data[i] = bytes[i];
  }
  return data;
}

Pointer<FilterList> _filters(int handle) =>
    Pointer<FilterList>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
