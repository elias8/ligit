import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show AttrValue;

const attrCheckFileThenIndex = GIT_ATTR_CHECK_FILE_THEN_INDEX;

const attrCheckIndexThenFile = GIT_ATTR_CHECK_INDEX_THEN_FILE;

const attrCheckIndexOnly = GIT_ATTR_CHECK_INDEX_ONLY;

const attrCheckNoSystem = GIT_ATTR_CHECK_NO_SYSTEM;

const attrCheckIncludeHead = GIT_ATTR_CHECK_INCLUDE_HEAD;

const attrCheckIncludeCommit = GIT_ATTR_CHECK_INCLUDE_COMMIT;

AttrValue attrValue(String value) {
  return using((arena) {
    final cValue = value.toNativeUtf8(allocator: arena).cast<Char>();
    return git_attr_value(cValue);
  });
}

({AttrValue kind, String? value}) attrGet(
  int repoHandle,
  String path,
  String name, {
  int flags = 0,
}) {
  return using((arena) {
    final out = arena<Pointer<Char>>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_attr_get(out, _repo(repoHandle), flags, cPath, cName));
    return _readAttr(out.value);
  });
}

({AttrValue kind, String? value}) attrGetExt(
  int repoHandle,
  String path,
  String name, {
  int flags = 0,
  Uint8List? commitId,
}) {
  return using((arena) {
    final out = arena<Pointer<Char>>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final opts = arena<AttrOptions>();
    opts.ref.version = GIT_ATTR_OPTIONS_VERSION;
    opts.ref.flags = flags;
    if (commitId != null) {
      for (var i = 0; i < commitId.length; i++) {
        opts.ref.attr_commit_id.id[i] = commitId[i];
      }
    }
    checkCode(git_attr_get_ext(out, _repo(repoHandle), opts, cPath, cName));
    return _readAttr(out.value);
  });
}

List<({AttrValue kind, String? value})> attrGetMany(
  int repoHandle,
  String path,
  List<String> names, {
  int flags = 0,
}) {
  return using((arena) {
    final values = arena<Pointer<Char>>(names.length);
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final nameArray = arena<Pointer<Char>>(names.length);
    for (var i = 0; i < names.length; i++) {
      nameArray[i] = names[i].toNativeUtf8(allocator: arena).cast<Char>();
    }
    checkCode(
      git_attr_get_many(
        values,
        _repo(repoHandle),
        flags,
        cPath,
        names.length,
        nameArray,
      ),
    );
    return [for (var i = 0; i < names.length; i++) _readAttr(values[i])];
  });
}

List<({AttrValue kind, String? value})> attrGetManyExt(
  int repoHandle,
  String path,
  List<String> names, {
  int flags = 0,
  Uint8List? commitId,
}) {
  return using((arena) {
    final values = arena<Pointer<Char>>(names.length);
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final nameArray = arena<Pointer<Char>>(names.length);
    for (var i = 0; i < names.length; i++) {
      nameArray[i] = names[i].toNativeUtf8(allocator: arena).cast<Char>();
    }
    final opts = arena<AttrOptions>();
    opts.ref.version = GIT_ATTR_OPTIONS_VERSION;
    opts.ref.flags = flags;
    if (commitId != null) {
      for (var i = 0; i < commitId.length; i++) {
        opts.ref.attr_commit_id.id[i] = commitId[i];
      }
    }
    checkCode(
      git_attr_get_many_ext(
        values,
        _repo(repoHandle),
        opts,
        cPath,
        names.length,
        nameArray,
      ),
    );
    return [for (var i = 0; i < names.length; i++) _readAttr(values[i])];
  });
}

int attrForeach(
  int repoHandle,
  String path,
  int Function(String name, String? value) callback, {
  int flags = 0,
}) {
  return using((arena) {
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final cb =
        NativeCallable<
          Int Function(Pointer<Char>, Pointer<Char>, Pointer<Void>)
        >.isolateLocal((
          Pointer<Char> name,
          Pointer<Char> value,
          Pointer<Void> _,
        ) {
          try {
            return callback(
              name.cast<Utf8>().toDartString(),
              value == nullptr ? null : value.cast<Utf8>().toDartString(),
            );
          } on Object {
            return -1;
          }
        }, exceptionalReturn: -1);
    try {
      final code = git_attr_foreach(
        _repo(repoHandle),
        flags,
        cPath,
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

int attrForeachExt(
  int repoHandle,
  String path,
  int Function(String name, String? value) callback, {
  int flags = 0,
  Uint8List? commitId,
}) {
  return using((arena) {
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final opts = arena<AttrOptions>();
    opts.ref.version = GIT_ATTR_OPTIONS_VERSION;
    opts.ref.flags = flags;
    if (commitId != null) {
      for (var i = 0; i < commitId.length; i++) {
        opts.ref.attr_commit_id.id[i] = commitId[i];
      }
    }
    final cb =
        NativeCallable<
          Int Function(Pointer<Char>, Pointer<Char>, Pointer<Void>)
        >.isolateLocal((
          Pointer<Char> name,
          Pointer<Char> value,
          Pointer<Void> _,
        ) {
          try {
            return callback(
              name.cast<Utf8>().toDartString(),
              value == nullptr ? null : value.cast<Utf8>().toDartString(),
            );
          } on Object {
            return -1;
          }
        }, exceptionalReturn: -1);
    try {
      final code = git_attr_foreach_ext(
        _repo(repoHandle),
        opts,
        cPath,
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

void attrCacheFlush(int repoHandle) {
  checkCode(git_attr_cache_flush(_repo(repoHandle)));
}

void attrAddMacro(int repoHandle, String name, String values) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cValues = values.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_attr_add_macro(_repo(repoHandle), cName, cValues));
  });
}

({AttrValue kind, String? value}) _readAttr(Pointer<Char> ptr) {
  final kind = ptr == nullptr ? AttrValue.unspecified : git_attr_value(ptr);
  return (
    kind: kind,
    value: kind == AttrValue.string ? ptr.cast<Utf8>().toDartString() : null,
  );
}

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
