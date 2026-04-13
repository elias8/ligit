import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

typedef OdbObjectRecord = ({Uint8List id, int type, int size, Uint8List data});

int odbNew() {
  return using((arena) {
    final out = arena<Pointer<Odb>>();
    checkCode(git_odb_new(out));
    return out.value.address;
  });
}

int odbOpen(String objectsDir) {
  return using((arena) {
    final out = arena<Pointer<Odb>>();
    final cPath = objectsDir.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_odb_open(out, cPath));
    return out.value.address;
  });
}

void odbAddDiskAlternate(int handle, String path) {
  using((arena) {
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_odb_add_disk_alternate(_odb(handle), cPath));
  });
}

void odbFree(int handle) => git_odb_free(_odb(handle));

void odbRefresh(int handle) {
  checkCode(git_odb_refresh(_odb(handle)));
}

int odbRead(int handle, Uint8List oid) {
  return using((arena) {
    final out = arena<Pointer<OdbObject>>();
    final id = _allocOid(arena, oid);
    checkCode(git_odb_read(out, _odb(handle), id));
    return out.value.address;
  });
}

int odbReadPrefix(int handle, Uint8List shortId, int length) {
  return using((arena) {
    final out = arena<Pointer<OdbObject>>();
    final id = _allocOid(arena, shortId);
    checkCode(git_odb_read_prefix(out, _odb(handle), id, length));
    return out.value.address;
  });
}

({int size, int type}) odbReadHeader(int handle, Uint8List oid) {
  return using((arena) {
    final lenOut = arena<Size>();
    final typeOut = arena<Int>();
    final id = _allocOid(arena, oid);
    checkCode(git_odb_read_header(lenOut, typeOut, _odb(handle), id));
    return (size: lenOut.value, type: typeOut.value);
  });
}

bool odbExists(int handle, Uint8List oid) {
  return using((arena) {
    final id = _allocOid(arena, oid);
    return git_odb_exists(_odb(handle), id) == 1;
  });
}

bool odbExistsExt(int handle, Uint8List oid, int flags) {
  return using((arena) {
    final id = _allocOid(arena, oid);
    return git_odb_exists_ext(_odb(handle), id, flags) == 1;
  });
}

Uint8List? odbExistsPrefix(int handle, Uint8List shortId, int length) {
  return using((arena) {
    final out = arena<Oid>();
    final id = _allocOid(arena, shortId);
    final code = git_odb_exists_prefix(out, _odb(handle), id, length);
    if (code == ErrorCode.enotfound.value) return null;
    checkCode(code);
    return _oidFromStruct(out);
  });
}

void odbForeach(int handle, int Function(Uint8List oid) onObject) {
  using((arena) {
    final cb =
        NativeCallable<Int Function(Pointer<Oid>, Pointer<Void>)>.isolateLocal((
          Pointer<Oid> id,
          Pointer<Void> _,
        ) {
          try {
            return onObject(_oidFromStruct(id));
          } on Object {
            return -1;
          }
        }, exceptionalReturn: -1);
    try {
      checkCode(
        git_odb_foreach(_odb(handle), cb.nativeFunction.cast(), nullptr),
      );
    } finally {
      cb.close();
    }
  });
}

Uint8List odbWrite(int handle, Uint8List data, int type) {
  return using((arena) {
    final out = arena<Oid>();
    final bytes = arena<Uint8>(data.length);
    for (var i = 0; i < data.length; i++) {
      bytes[i] = data[i];
    }
    checkCode(
      git_odb_write(
        out,
        _odb(handle),
        bytes.cast<Void>(),
        data.length,
        ObjectT.fromValue(type),
      ),
    );
    return _oidFromStruct(out);
  });
}

Uint8List odbHash(Uint8List data, int type) {
  return using((arena) {
    final out = arena<Oid>();
    final bytes = arena<Uint8>(data.length);
    for (var i = 0; i < data.length; i++) {
      bytes[i] = data[i];
    }
    checkCode(
      git_odb_hash(
        out,
        bytes.cast<Void>(),
        data.length,
        ObjectT.fromValue(type),
      ),
    );
    return _oidFromStruct(out);
  });
}

Uint8List odbHashFile(String path, int type) {
  return using((arena) {
    final out = arena<Oid>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_odb_hashfile(out, cPath, ObjectT.fromValue(type)));
    return _oidFromStruct(out);
  });
}

int odbNumBackends(int handle) => git_odb_num_backends(_odb(handle));

void odbObjectFree(int handle) =>
    git_odb_object_free(Pointer<OdbObject>.fromAddress(handle));

OdbObjectRecord odbObjectRead(int handle) {
  final ptr = Pointer<OdbObject>.fromAddress(handle);
  final id = git_odb_object_id(ptr);
  final data = git_odb_object_data(ptr);
  final size = git_odb_object_size(ptr);
  final type = git_odb_object_type(ptr).value;
  final idBytes = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    idBytes[i] = id.ref.id[i];
  }
  final dataBytes = Uint8List(size);
  final src = data.cast<Uint8>();
  for (var i = 0; i < size; i++) {
    dataBytes[i] = src[i];
  }
  return (id: idBytes, type: type, size: size, data: dataBytes);
}

int odbObjectDup(int sourceHandle) {
  return using((arena) {
    final out = arena<Pointer<OdbObject>>();
    checkCode(
      git_odb_object_dup(out, Pointer<OdbObject>.fromAddress(sourceHandle)),
    );
    return out.value.address;
  });
}

Pointer<Oid> _allocOid(Allocator arena, Uint8List bytes) {
  final out = arena<Oid>();
  for (var i = 0; i < bytes.length; i++) {
    out.ref.id[i] = bytes[i];
  }
  return out;
}

Uint8List _oidFromStruct(Pointer<Oid> ptr) {
  final out = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    out[i] = ptr.ref.id[i];
  }
  return out;
}

Uint8List _oidFromBytes(Oid value) {
  final out = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    out[i] = value.id[i];
  }
  return out;
}

void odbAddBackend(int handle, int backendAddress, int priority) {
  checkCode(
    git_odb_add_backend(
      _odb(handle),
      Pointer<OdbBackend>.fromAddress(backendAddress),
      priority,
    ),
  );
}

void odbAddAlternate(int handle, int backendAddress, int priority) {
  checkCode(
    git_odb_add_alternate(
      _odb(handle),
      Pointer<OdbBackend>.fromAddress(backendAddress),
      priority,
    ),
  );
}

int odbGetBackend(int handle, int position) {
  return using((arena) {
    final out = arena<Pointer<OdbBackend>>();
    checkCode(git_odb_get_backend(out, _odb(handle), position));
    return out.value.address;
  });
}

void odbSetCommitGraph(int handle, int commitGraphAddress) {
  checkCode(
    git_odb_set_commit_graph(
      _odb(handle),
      commitGraphAddress == 0
          ? nullptr.cast<CommitGraph>()
          : Pointer<CommitGraph>.fromAddress(commitGraphAddress),
    ),
  );
}

List<({Uint8List id, int length, int type})> odbExpandIds(
  int handle,
  List<({Uint8List id, int length, int type})> shortIds,
) {
  return using((arena) {
    final count = shortIds.length;
    final array = arena<OdbExpandId>(count);
    for (var i = 0; i < count; i++) {
      final entry = shortIds[i];
      final slot = (array + i).ref;
      for (var j = 0; j < 20; j++) {
        slot.id.id[j] = j < entry.id.length ? entry.id[j] : 0;
      }
      slot.length = entry.length;
      slot.typeAsInt = entry.type;
    }
    checkCode(git_odb_expand_ids(_odb(handle), array, count));
    return [
      for (var i = 0; i < count; i++)
        (
          id: _oidFromBytes(array[i].id),
          length: array[i].length,
          type: array[i].typeAsInt,
        ),
    ];
  });
}

int odbOpenWstream(int handle, int size, int type) {
  return using((arena) {
    final out = arena<Pointer<OdbStream>>();
    checkCode(
      git_odb_open_wstream(out, _odb(handle), size, ObjectT.fromValue(type)),
    );
    return out.value.address;
  });
}

({int handle, int size, int type}) odbOpenRstream(int handle, Uint8List oid) {
  return using((arena) {
    final out = arena<Pointer<OdbStream>>();
    final lenOut = arena<Size>();
    final typeOut = arena<Int>();
    final id = _allocOid(arena, oid);
    checkCode(
      git_odb_open_rstream(out, lenOut, typeOut.cast(), _odb(handle), id),
    );
    return (handle: out.value.address, size: lenOut.value, type: typeOut.value);
  });
}

void odbStreamWrite(int streamHandle, Uint8List data) {
  using((arena) {
    final bytes = arena<Uint8>(data.length);
    for (var i = 0; i < data.length; i++) {
      bytes[i] = data[i];
    }
    checkCode(
      git_odb_stream_write(
        Pointer<OdbStream>.fromAddress(streamHandle),
        bytes.cast<Char>(),
        data.length,
      ),
    );
  });
}

Uint8List odbStreamRead(int streamHandle, int max) {
  return using((arena) {
    final buf = arena<Uint8>(max);
    final code = git_odb_stream_read(
      Pointer<OdbStream>.fromAddress(streamHandle),
      buf.cast<Char>(),
      max,
    );
    if (code < 0) checkCode(code);
    final result = Uint8List(code);
    for (var i = 0; i < code; i++) {
      result[i] = buf[i];
    }
    return result;
  });
}

Uint8List odbStreamFinalizeWrite(int streamHandle) {
  return using((arena) {
    final out = arena<Oid>();
    checkCode(
      git_odb_stream_finalize_write(
        out,
        Pointer<OdbStream>.fromAddress(streamHandle),
      ),
    );
    return _oidFromStruct(out);
  });
}

void odbStreamFree(int streamHandle) =>
    git_odb_stream_free(Pointer<OdbStream>.fromAddress(streamHandle));

void odbWriteMultiPackIndex(int handle) {
  checkCode(git_odb_write_multi_pack_index(_odb(handle)));
}

int odbWritePack(int handle) {
  return using((arena) {
    final out = arena<Pointer<OdbWritepack>>();
    checkCode(
      git_odb_write_pack(out, _odb(handle), nullptr.cast(), nullptr.cast()),
    );
    return out.value.address;
  });
}

Pointer<Odb> _odb(int handle) => Pointer<Odb>.fromAddress(handle);
