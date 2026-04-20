import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show ObjectT;

int tagLookup(int repoHandle, Uint8List oidBytes) {
  return using((arena) {
    final out = arena<Pointer<Tag>>();
    final oid = _allocOid(arena, oidBytes);
    checkCode(git_tag_lookup(out, _repo(repoHandle), oid));
    return out.value.address;
  });
}

int tagLookupPrefix(int repoHandle, Uint8List oidBytes, int prefixLength) {
  return using((arena) {
    final out = arena<Pointer<Tag>>();
    final oid = _allocOid(arena, oidBytes);
    checkCode(git_tag_lookup_prefix(out, _repo(repoHandle), oid, prefixLength));
    return out.value.address;
  });
}

void tagFree(int handle) => git_tag_free(_tag(handle));

Uint8List tagId(int handle) => _oidBytes(git_tag_id(_tag(handle)));

int tagOwner(int handle) => git_tag_owner(_tag(handle)).address;

int tagTarget(int handle) {
  return using((arena) {
    final out = arena<Pointer<Object>>();
    checkCode(git_tag_target(out, _tag(handle)));
    return out.value.address;
  });
}

Uint8List tagTargetId(int handle) {
  return _oidBytes(git_tag_target_id(_tag(handle)));
}

ObjectT tagTargetType(int handle) => git_tag_target_type(_tag(handle));

String tagName(int handle) {
  return git_tag_name(_tag(handle)).cast<Utf8>().toDartString();
}

({String name, String email, int time, int offset})? tagTagger(int handle) {
  final sig = git_tag_tagger(_tag(handle));
  if (sig == nullptr) return null;
  return _readSig(sig);
}

String? tagMessage(int handle) {
  final ptr = git_tag_message(_tag(handle));
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

Uint8List tagCreate({
  required int repoHandle,
  required String tagName,
  required int targetHandle,
  required ({String name, String email, int time, int offset}) tagger,
  required String message,
  required bool force,
}) {
  return using((arena) {
    final out = arena<Oid>();
    final cName = tagName.toNativeUtf8(allocator: arena).cast<Char>();
    final cMessage = message.toNativeUtf8(allocator: arena).cast<Char>();
    final taggerPtr = _allocSignature(arena, tagger);
    try {
      checkCode(
        git_tag_create(
          out,
          _repo(repoHandle),
          cName,
          _object(targetHandle),
          taggerPtr,
          cMessage,
          force ? 1 : 0,
        ),
      );
      return _oidBytes(out);
    } finally {
      git_signature_free(taggerPtr);
    }
  });
}

Uint8List tagAnnotationCreate({
  required int repoHandle,
  required String tagName,
  required int targetHandle,
  required ({String name, String email, int time, int offset}) tagger,
  required String message,
}) {
  return using((arena) {
    final out = arena<Oid>();
    final cName = tagName.toNativeUtf8(allocator: arena).cast<Char>();
    final cMessage = message.toNativeUtf8(allocator: arena).cast<Char>();
    final taggerPtr = _allocSignature(arena, tagger);
    try {
      checkCode(
        git_tag_annotation_create(
          out,
          _repo(repoHandle),
          cName,
          _object(targetHandle),
          taggerPtr,
          cMessage,
        ),
      );
      return _oidBytes(out);
    } finally {
      git_signature_free(taggerPtr);
    }
  });
}

Uint8List tagCreateFromBuffer(
  int repoHandle,
  String buffer, {
  required bool force,
}) {
  return using((arena) {
    final out = arena<Oid>();
    final cBuffer = buffer.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_tag_create_from_buffer(
        out,
        _repo(repoHandle),
        cBuffer,
        force ? 1 : 0,
      ),
    );
    return _oidBytes(out);
  });
}

Uint8List tagCreateLightweight({
  required int repoHandle,
  required String tagName,
  required int targetHandle,
  required bool force,
}) {
  return using((arena) {
    final out = arena<Oid>();
    final cName = tagName.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_tag_create_lightweight(
        out,
        _repo(repoHandle),
        cName,
        _object(targetHandle),
        force ? 1 : 0,
      ),
    );
    return _oidBytes(out);
  });
}

void tagDelete(int repoHandle, String tagName) {
  using((arena) {
    final cName = tagName.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_tag_delete(_repo(repoHandle), cName));
  });
}

List<String> tagList(int repoHandle) {
  return using((arena) {
    final arr = arena<Strarray>();
    try {
      checkCode(git_tag_list(arr, _repo(repoHandle)));
      final count = arr.ref.count;
      final result = <String>[];
      for (var i = 0; i < count; i++) {
        final strPtr = (arr.ref.strings + i).value;
        result.add(strPtr.cast<Utf8>().toDartString());
      }
      return result;
    } finally {
      git_strarray_dispose(arr);
    }
  });
}

List<String> tagListMatch(int repoHandle, String pattern) {
  return using((arena) {
    final arr = arena<Strarray>();
    final cPattern = pattern.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      checkCode(git_tag_list_match(arr, cPattern, _repo(repoHandle)));
      final count = arr.ref.count;
      final result = <String>[];
      for (var i = 0; i < count; i++) {
        final strPtr = (arr.ref.strings + i).value;
        result.add(strPtr.cast<Utf8>().toDartString());
      }
      return result;
    } finally {
      git_strarray_dispose(arr);
    }
  });
}

int tagPeel(int handle) {
  return using((arena) {
    final out = arena<Pointer<Object>>();
    checkCode(git_tag_peel(out, _tag(handle)));
    return out.value.address;
  });
}

int tagDup(int handle) {
  return using((arena) {
    final out = arena<Pointer<Tag>>();
    checkCode(git_tag_dup(out, _tag(handle)));
    return out.value.address;
  });
}

bool tagNameIsValid(String name) {
  return using((arena) {
    final out = arena<Int>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_tag_name_is_valid(out, cName));
    return out.value == 1;
  });
}

Pointer<Signature> _allocSignature(
  Allocator arena,
  ({String name, String email, int time, int offset}) data,
) {
  final out = arena<Pointer<Signature>>();
  final cName = data.name.toNativeUtf8(allocator: arena).cast<Char>();
  final cEmail = data.email.toNativeUtf8(allocator: arena).cast<Char>();
  checkCode(git_signature_new(out, cName, cEmail, data.time, data.offset));
  return out.value;
}

({String name, String email, int time, int offset}) _readSig(
  Pointer<Signature> sig,
) {
  return (
    name: sig.ref.name.cast<Utf8>().toDartString(),
    email: sig.ref.email.cast<Utf8>().toDartString(),
    time: sig.ref.when.time,
    offset: sig.ref.when.offset,
  );
}

int tagForeach(
  int repoHandle,
  int Function(String name, Uint8List targetId) callback,
) {
  final cb =
      NativeCallable<
        Int Function(Pointer<Char>, Pointer<Oid>, Pointer<Void>)
      >.isolateLocal((Pointer<Char> name, Pointer<Oid> oid, Pointer<Void> _) {
        try {
          return callback(name.cast<Utf8>().toDartString(), _oidBytes(oid));
        } on Object {
          return -1;
        }
      }, exceptionalReturn: -1);
  try {
    final code = git_tag_foreach(
      _repo(repoHandle),
      cb.nativeFunction.cast(),
      nullptr.cast(),
    );
    if (code < 0) checkCode(code);
    return code;
  } finally {
    cb.close();
  }
}

Pointer<Tag> _tag(int handle) => Pointer<Tag>.fromAddress(handle);

Pointer<Object> _object(int handle) => Pointer<Object>.fromAddress(handle);

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
