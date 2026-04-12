import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show ReferenceT;

int referenceLookup(int repoHandle, String name) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_reference_lookup(out, _repo(repoHandle), cName));
    return out.value.address;
  });
}

Uint8List referenceNameToId(int repoHandle, String name) {
  return using((arena) {
    final out = arena<Oid>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_reference_name_to_id(out, _repo(repoHandle), cName));
    return _oidBytes(out);
  });
}

int referenceDwim(int repoHandle, String shorthand) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    final cShort = shorthand.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_reference_dwim(out, _repo(repoHandle), cShort));
    return out.value.address;
  });
}

int referenceSymbolicCreate({
  required int repoHandle,
  required String name,
  required String target,
  required bool force,
  String? logMessage,
}) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cTarget = target.toNativeUtf8(allocator: arena).cast<Char>();
    final cLog = logMessage == null
        ? nullptr.cast<Char>()
        : logMessage.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_reference_symbolic_create(
        out,
        _repo(repoHandle),
        cName,
        cTarget,
        force ? 1 : 0,
        cLog,
      ),
    );
    return out.value.address;
  });
}

int referenceSymbolicCreateMatching({
  required int repoHandle,
  required String name,
  required String target,
  required bool force,
  String? currentValue,
  String? logMessage,
}) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cTarget = target.toNativeUtf8(allocator: arena).cast<Char>();
    final cCurrent = currentValue == null
        ? nullptr.cast<Char>()
        : currentValue.toNativeUtf8(allocator: arena).cast<Char>();
    final cLog = logMessage == null
        ? nullptr.cast<Char>()
        : logMessage.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_reference_symbolic_create_matching(
        out,
        _repo(repoHandle),
        cName,
        cTarget,
        force ? 1 : 0,
        cCurrent,
        cLog,
      ),
    );
    return out.value.address;
  });
}

int referenceCreate({
  required int repoHandle,
  required String name,
  required Uint8List oidBytes,
  required bool force,
  String? logMessage,
}) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final oid = _allocOid(arena, oidBytes);
    final cLog = logMessage == null
        ? nullptr.cast<Char>()
        : logMessage.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_reference_create(
        out,
        _repo(repoHandle),
        cName,
        oid,
        force ? 1 : 0,
        cLog,
      ),
    );
    return out.value.address;
  });
}

int referenceCreateMatching({
  required int repoHandle,
  required String name,
  required Uint8List oidBytes,
  required bool force,
  Uint8List? currentOidBytes,
  String? logMessage,
}) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final oid = _allocOid(arena, oidBytes);
    final currentOid = currentOidBytes == null
        ? nullptr.cast<Oid>()
        : _allocOid(arena, currentOidBytes);
    final cLog = logMessage == null
        ? nullptr.cast<Char>()
        : logMessage.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_reference_create_matching(
        out,
        _repo(repoHandle),
        cName,
        oid,
        force ? 1 : 0,
        currentOid,
        cLog,
      ),
    );
    return out.value.address;
  });
}

Uint8List? referenceTarget(int handle) {
  final ptr = git_reference_target(_ref(handle));
  if (ptr == nullptr) return null;
  return _oidBytes(ptr);
}

Uint8List? referenceTargetPeel(int handle) {
  final ptr = git_reference_target_peel(_ref(handle));
  if (ptr == nullptr) return null;
  return _oidBytes(ptr);
}

String? referenceSymbolicTarget(int handle) {
  final ptr = git_reference_symbolic_target(_ref(handle));
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

ReferenceT referenceType(int handle) => git_reference_type(_ref(handle));

String referenceName(int handle) {
  return git_reference_name(_ref(handle)).cast<Utf8>().toDartString();
}

int referenceResolve(int handle) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    checkCode(git_reference_resolve(out, _ref(handle)));
    return out.value.address;
  });
}

int referenceOwner(int handle) => git_reference_owner(_ref(handle)).address;

int referenceSymbolicSetTarget(
  int handle,
  String target, {
  String? logMessage,
}) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    final cTarget = target.toNativeUtf8(allocator: arena).cast<Char>();
    final cLog = logMessage == null
        ? nullptr.cast<Char>()
        : logMessage.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_reference_symbolic_set_target(out, _ref(handle), cTarget, cLog),
    );
    return out.value.address;
  });
}

int referenceSetTarget(int handle, Uint8List oidBytes, {String? logMessage}) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    final oid = _allocOid(arena, oidBytes);
    final cLog = logMessage == null
        ? nullptr.cast<Char>()
        : logMessage.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_reference_set_target(out, _ref(handle), oid, cLog));
    return out.value.address;
  });
}

int referenceRename(
  int handle,
  String newName, {
  required bool force,
  String? logMessage,
}) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    final cName = newName.toNativeUtf8(allocator: arena).cast<Char>();
    final cLog = logMessage == null
        ? nullptr.cast<Char>()
        : logMessage.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_reference_rename(out, _ref(handle), cName, force ? 1 : 0, cLog),
    );
    return out.value.address;
  });
}

void referenceDelete(int handle) {
  checkCode(git_reference_delete(_ref(handle)));
}

void referenceRemove(int repoHandle, String name) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_reference_remove(_repo(repoHandle), cName));
  });
}

List<String> referenceList(int repoHandle) {
  return using((arena) {
    final arr = arena<Strarray>();
    try {
      checkCode(git_reference_list(arr, _repo(repoHandle)));
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

int referenceDup(int handle) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    checkCode(git_reference_dup(out, _ref(handle)));
    return out.value.address;
  });
}

void referenceFree(int handle) => git_reference_free(_ref(handle));

int referenceCmp(int aHandle, int bHandle) {
  return git_reference_cmp(_ref(aHandle), _ref(bHandle));
}

int referenceIteratorNew(int repoHandle) {
  return using((arena) {
    final out = arena<Pointer<ReferenceIterator>>();
    checkCode(git_reference_iterator_new(out, _repo(repoHandle)));
    return out.value.address;
  });
}

int referenceIteratorGlobNew(int repoHandle, String glob) {
  return using((arena) {
    final out = arena<Pointer<ReferenceIterator>>();
    final cGlob = glob.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_reference_iterator_glob_new(out, _repo(repoHandle), cGlob));
    return out.value.address;
  });
}

int referenceNext(int iteratorHandle) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    final code = git_reference_next(out, _iter(iteratorHandle));
    if (code == ErrorCode.iterover.value) return 0;
    checkCode(code);
    return out.value.address;
  });
}

String? referenceNextName(int iteratorHandle) {
  return using((arena) {
    final out = arena<Pointer<Char>>();
    final code = git_reference_next_name(out, _iter(iteratorHandle));
    if (code == ErrorCode.iterover.value) return null;
    checkCode(code);
    return out.value.cast<Utf8>().toDartString();
  });
}

void referenceIteratorFree(int iteratorHandle) {
  git_reference_iterator_free(_iter(iteratorHandle));
}

bool referenceHasLog(int repoHandle, String name) {
  return using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final code = git_reference_has_log(_repo(repoHandle), cName);
    checkCode(code);
    return code == 1;
  });
}

void referenceEnsureLog(int repoHandle, String name) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_reference_ensure_log(_repo(repoHandle), cName));
  });
}

bool referenceIsBranch(int handle) {
  return git_reference_is_branch(_ref(handle)) == 1;
}

bool referenceIsRemote(int handle) {
  return git_reference_is_remote(_ref(handle)) == 1;
}

bool referenceIsTag(int handle) => git_reference_is_tag(_ref(handle)) == 1;

bool referenceIsNote(int handle) => git_reference_is_note(_ref(handle)) == 1;

String referenceNormalizeName(String name, int flags) {
  const bufferSize = 1024;
  return using((arena) {
    final buffer = arena<Char>(bufferSize);
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_reference_normalize_name(buffer, bufferSize, cName, flags));
    return buffer.cast<Utf8>().toDartString();
  });
}

int referencePeel(int handle, ObjectT type) {
  return using((arena) {
    final out = arena<Pointer<Object>>();
    checkCode(git_reference_peel(out, _ref(handle), type));
    return out.value.address;
  });
}

bool referenceNameIsValid(String name) {
  return using((arena) {
    final out = arena<Int>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_reference_name_is_valid(out, cName));
    return out.value == 1;
  });
}

String referenceShorthand(int handle) {
  return git_reference_shorthand(_ref(handle)).cast<Utf8>().toDartString();
}

int referenceForeach(
  int repoHandle,
  int Function(int referenceHandle) callback,
) {
  final cb =
      NativeCallable<
        Int Function(Pointer<Reference>, Pointer<Void>)
      >.isolateLocal((Pointer<Reference> ref, Pointer<Void> _) {
        try {
          return callback(ref.address);
        } on Object {
          return -1;
        } finally {
          git_reference_free(ref);
        }
      }, exceptionalReturn: -1);
  try {
    final code = git_reference_foreach(
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

int referenceForeachName(int repoHandle, int Function(String name) callback) {
  final cb =
      NativeCallable<Int Function(Pointer<Char>, Pointer<Void>)>.isolateLocal((
        Pointer<Char> name,
        Pointer<Void> _,
      ) {
        try {
          return callback(name.cast<Utf8>().toDartString());
        } on Object {
          return -1;
        }
      }, exceptionalReturn: -1);
  try {
    final code = git_reference_foreach_name(
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

int referenceForeachGlob(
  int repoHandle,
  String glob,
  int Function(String name) callback,
) {
  return using((arena) {
    final cb =
        NativeCallable<Int Function(Pointer<Char>, Pointer<Void>)>.isolateLocal(
          (Pointer<Char> name, Pointer<Void> _) {
            try {
              return callback(name.cast<Utf8>().toDartString());
            } on Object {
              return -1;
            }
          },
          exceptionalReturn: -1,
        );
    try {
      final cGlob = glob.toNativeUtf8(allocator: arena).cast<Char>();
      final code = git_reference_foreach_glob(
        _repo(repoHandle),
        cGlob,
        cb.nativeFunction.cast(),
        nullptr.cast(),
      );
      if (code < 0) checkCode(code);
      return code;
    } finally {
      cb.close();
    }
  });
}

Pointer<Reference> _ref(int handle) => Pointer<Reference>.fromAddress(handle);

Pointer<ReferenceIterator> _iter(int handle) {
  return Pointer<ReferenceIterator>.fromAddress(handle);
}

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
