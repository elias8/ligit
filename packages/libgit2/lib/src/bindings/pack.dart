import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show PackbuilderStage;

int packbuilderNew(int repoHandle) {
  return using((arena) {
    final out = arena<Pointer<Packbuilder>>();
    checkCode(git_packbuilder_new(out, _repo(repoHandle)));
    return out.value.address;
  });
}

void packbuilderFree(int handle) => git_packbuilder_free(_pb(handle));

int packbuilderSetThreads(int handle, int threads) =>
    git_packbuilder_set_threads(_pb(handle), threads);

void packbuilderInsert(int handle, Uint8List oid, {String? name}) {
  using((arena) {
    final id = _allocOid(arena, oid);
    final cName = name == null
        ? nullptr.cast<Char>()
        : name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_packbuilder_insert(_pb(handle), id, cName));
  });
}

void packbuilderInsertTree(int handle, Uint8List oid) {
  using((arena) {
    final id = _allocOid(arena, oid);
    checkCode(git_packbuilder_insert_tree(_pb(handle), id));
  });
}

void packbuilderInsertCommit(int handle, Uint8List oid) {
  using((arena) {
    final id = _allocOid(arena, oid);
    checkCode(git_packbuilder_insert_commit(_pb(handle), id));
  });
}

void packbuilderInsertWalk(int handle, int revwalkHandle) {
  checkCode(
    git_packbuilder_insert_walk(
      _pb(handle),
      Pointer<Revwalk>.fromAddress(revwalkHandle),
    ),
  );
}

void packbuilderInsertRecur(int handle, Uint8List oid, {String? name}) {
  using((arena) {
    final id = _allocOid(arena, oid);
    final cName = name == null
        ? nullptr.cast<Char>()
        : name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_packbuilder_insert_recur(_pb(handle), id, cName));
  });
}

void packbuilderWrite(int handle, {String? path, int mode = 0}) {
  using((arena) {
    final cPath = path == null
        ? nullptr.cast<Char>()
        : path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_packbuilder_write(_pb(handle), cPath, mode, nullptr, nullptr),
    );
  });
}

Uint8List packbuilderWriteBuf(int handle) {
  return using((arena) {
    final buf = arena<Buf>();
    checkCode(git_packbuilder_write_buf(buf, _pb(handle)));
    try {
      final bytes = buf.ref.ptr.cast<Uint8>();
      final len = buf.ref.size;
      final data = Uint8List(len);
      for (var i = 0; i < len; i++) {
        data[i] = bytes[i];
      }
      return data;
    } finally {
      git_buf_dispose(buf);
    }
  });
}

int packbuilderObjectCount(int handle) =>
    git_packbuilder_object_count(_pb(handle));

int packbuilderWritten(int handle) => git_packbuilder_written(_pb(handle));

String packbuilderName(int handle) {
  final ptr = git_packbuilder_name(_pb(handle));
  if (ptr == nullptr) return '';
  return ptr.cast<Utf8>().toDartString();
}

void packbuilderForeach(int handle, int Function(Uint8List buffer) onObject) {
  using((arena) {
    final cb =
        NativeCallable<
          Int Function(Pointer<Void>, Size, Pointer<Void>)
        >.isolateLocal((Pointer<Void> buf, int size, Pointer<Void> _) {
          try {
            final data = Uint8List(size);
            final src = buf.cast<Uint8>();
            for (var i = 0; i < size; i++) {
              data[i] = src[i];
            }
            return onObject(data);
          } on Object {
            return -1;
          }
        }, exceptionalReturn: -1);
    try {
      checkCode(
        git_packbuilder_foreach(_pb(handle), cb.nativeFunction.cast(), nullptr),
      );
    } finally {
      cb.close();
    }
  });
}

Pointer<Oid> _allocOid(Allocator arena, Uint8List bytes) {
  final out = arena<Oid>();
  for (var i = 0; i < bytes.length; i++) {
    out.ref.id[i] = bytes[i];
  }
  return out;
}

void Function()? packbuilderSetCallbacks(
  int handle,
  int Function(int stage, int current, int total)? callback,
) {
  if (callback == null) {
    checkCode(
      git_packbuilder_set_callbacks(_pb(handle), nullptr.cast(), nullptr),
    );
    return null;
  }
  final cb =
      NativeCallable<
        Int Function(Int, Uint32, Uint32, Pointer<Void>)
      >.isolateLocal((int stage, int current, int total, Pointer<Void> _) {
        try {
          return callback(stage, current, total);
        } on Object {
          return -1;
        }
      }, exceptionalReturn: -1);
  checkCode(
    git_packbuilder_set_callbacks(
      _pb(handle),
      cb.nativeFunction.cast(),
      nullptr,
    ),
  );
  return cb.close;
}

Pointer<Packbuilder> _pb(int handle) =>
    Pointer<Packbuilder>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
