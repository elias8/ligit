import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show ObjectT;

int objectLookup(int repoHandle, Uint8List oidBytes, ObjectT type) {
  return using((arena) {
    final out = arena<Pointer<Object>>();
    final oid = _allocOid(arena, oidBytes);
    checkCode(git_object_lookup(out, _repo(repoHandle), oid, type));
    return out.value.address;
  });
}

int objectLookupPrefix(
  int repoHandle,
  Uint8List oidBytes,
  int prefixLength,
  ObjectT type,
) {
  return using((arena) {
    final out = arena<Pointer<Object>>();
    final oid = _allocOid(arena, oidBytes);
    checkCode(
      git_object_lookup_prefix(out, _repo(repoHandle), oid, prefixLength, type),
    );
    return out.value.address;
  });
}

int objectLookupByPath(int treeishHandle, String path, ObjectT type) {
  return using((arena) {
    final out = arena<Pointer<Object>>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_object_lookup_bypath(out, _object(treeishHandle), cPath, type),
    );
    return out.value.address;
  });
}

Uint8List objectId(int handle) => _oidBytes(git_object_id(_object(handle)));

String objectShortId(int handle) {
  return using((arena) {
    final buf = arena<Buf>();
    try {
      checkCode(git_object_short_id(buf, _object(handle)));
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

ObjectT objectType(int handle) => git_object_type(_object(handle));

int objectOwner(int handle) => git_object_owner(_object(handle)).address;

void objectFree(int handle) => git_object_free(_object(handle));

String objectTypeToString(ObjectT type) {
  final ptr = git_object_type2string(type);
  if (ptr == nullptr) return '';
  return ptr.cast<Utf8>().toDartString();
}

ObjectT objectStringToType(String name) {
  return using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    return git_object_string2type(cName);
  });
}

bool objectTypeIsLoose(ObjectT type) => git_object_typeisloose(type) == 1;

int objectPeel(int handle, ObjectT targetType) {
  return using((arena) {
    final out = arena<Pointer<Object>>();
    checkCode(git_object_peel(out, _object(handle), targetType));
    return out.value.address;
  });
}

int objectDup(int handle) {
  return using((arena) {
    final out = arena<Pointer<Object>>();
    checkCode(git_object_dup(out, _object(handle)));
    return out.value.address;
  });
}

bool objectRawContentIsValid(Uint8List content, ObjectT type) {
  return using((arena) {
    final valid = arena<Int>();
    final buf = arena<Uint8>(content.length);
    for (var i = 0; i < content.length; i++) {
      buf[i] = content[i];
    }
    checkCode(
      git_object_rawcontent_is_valid(
        valid,
        buf.cast<Char>(),
        content.length,
        type,
      ),
    );
    return valid.value == 1;
  });
}

Pointer<Object> _object(int handle) => Pointer<Object>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);

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
