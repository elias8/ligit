import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show ConfigLevel;

String? configFindGlobal() => _findWithBuf(git_config_find_global);

String? configFindXdg() => _findWithBuf(git_config_find_xdg);

String? configFindSystem() => _findWithBuf(git_config_find_system);

String? configFindProgramData() => _findWithBuf(git_config_find_programdata);

int configOpenDefault() {
  return using((arena) {
    final out = arena<Pointer<Config>>();
    checkCode(git_config_open_default(out));
    return out.value.address;
  });
}

int configNew() {
  return using((arena) {
    final out = arena<Pointer<Config>>();
    checkCode(git_config_new(out));
    return out.value.address;
  });
}

int configOpenOnDisk(String path) {
  return using((arena) {
    final out = arena<Pointer<Config>>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_config_open_ondisk(out, cPath));
    return out.value.address;
  });
}

int configOpenLevel(int parentHandle, ConfigLevel level) {
  return using((arena) {
    final out = arena<Pointer<Config>>();
    checkCode(git_config_open_level(out, _cfg(parentHandle), level));
    return out.value.address;
  });
}

int configOpenGlobal(int configHandle) {
  return using((arena) {
    final out = arena<Pointer<Config>>();
    checkCode(git_config_open_global(out, _cfg(configHandle)));
    return out.value.address;
  });
}

void configAddFileOnDisk(
  int configHandle,
  String path,
  ConfigLevel level, {
  int? repoHandle,
  bool force = false,
}) {
  using((arena) {
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final repo = repoHandle == null
        ? nullptr.cast<Repository>()
        : Pointer<Repository>.fromAddress(repoHandle);
    checkCode(
      git_config_add_file_ondisk(
        _cfg(configHandle),
        cPath,
        level,
        repo,
        force ? 1 : 0,
      ),
    );
  });
}

int configSnapshot(int configHandle) {
  return using((arena) {
    final out = arena<Pointer<Config>>();
    checkCode(git_config_snapshot(out, _cfg(configHandle)));
    return out.value.address;
  });
}

void configFree(int handle) => git_config_free(_cfg(handle));

int? configGetInt64(int handle, String name) {
  return using((arena) {
    final out = arena<Int64>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final result = git_config_get_int64(out, _cfg(handle), cName);
    if (result == ErrorCode.enotfound.value) return null;
    checkCode(result);
    return out.value;
  });
}

int? configGetInt32(int handle, String name) {
  return using((arena) {
    final out = arena<Int32>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final result = git_config_get_int32(out, _cfg(handle), cName);
    if (result == ErrorCode.enotfound.value) return null;
    checkCode(result);
    return out.value;
  });
}

bool? configGetBool(int handle, String name) {
  return using((arena) {
    final out = arena<Int>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final result = git_config_get_bool(out, _cfg(handle), cName);
    if (result == ErrorCode.enotfound.value) return null;
    checkCode(result);
    return out.value != 0;
  });
}

String? configGetString(int handle, String name) {
  return using((arena) {
    final buf = arena<Buf>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      final result = git_config_get_string_buf(buf, _cfg(handle), cName);
      if (result == ErrorCode.enotfound.value) return null;
      checkCode(result);
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

String? configGetPath(int handle, String name) {
  return using((arena) {
    final buf = arena<Buf>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      final result = git_config_get_path(buf, _cfg(handle), cName);
      if (result == ErrorCode.enotfound.value) return null;
      checkCode(result);
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

({
  String name,
  String value,
  String backendType,
  String originPath,
  int includeDepth,
  ConfigLevel level,
})?
configGetEntry(int handle, String name) {
  return using((arena) {
    final out = arena<Pointer<ConfigEntry>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final result = git_config_get_entry(out, _cfg(handle), cName);
    if (result == ErrorCode.enotfound.value) return null;
    checkCode(result);
    final entry = out.value;
    try {
      return (
        name: entry.ref.name.cast<Utf8>().toDartString(),
        value: entry.ref.value.cast<Utf8>().toDartString(),
        backendType: entry.ref.backend_type == nullptr
            ? ''
            : entry.ref.backend_type.cast<Utf8>().toDartString(),
        originPath: entry.ref.origin_path == nullptr
            ? ''
            : entry.ref.origin_path.cast<Utf8>().toDartString(),
        includeDepth: entry.ref.include_depth,
        level: entry.ref.level,
      );
    } finally {
      git_config_entry_free(entry);
    }
  });
}

void configSetInt64(int handle, String name, int value) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_config_set_int64(_cfg(handle), cName, value));
  });
}

void configSetInt32(int handle, String name, int value) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_config_set_int32(_cfg(handle), cName, value));
  });
}

void configSetBool(int handle, String name, {required bool value}) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_config_set_bool(_cfg(handle), cName, value ? 1 : 0));
  });
}

void configSetString(int handle, String name, String value) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cValue = value.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_config_set_string(_cfg(handle), cName, cValue));
  });
}

void configSetMultivar(int handle, String name, String pattern, String value) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cPattern = pattern.toNativeUtf8(allocator: arena).cast<Char>();
    final cValue = value.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_config_set_multivar(_cfg(handle), cName, cPattern, cValue));
  });
}

void configDeleteEntry(int handle, String name) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_config_delete_entry(_cfg(handle), cName));
  });
}

void configDeleteMultivar(int handle, String name, String pattern) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cPattern = pattern.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_config_delete_multivar(_cfg(handle), cName, cPattern));
  });
}

List<({String name, String value})> configList(int handle, {String? pattern}) {
  return using((arena) {
    final iter = arena<Pointer<ConfigIterator>>();
    if (pattern == null) {
      checkCode(git_config_iterator_new(iter, _cfg(handle)));
    } else {
      final cPattern = pattern.toNativeUtf8(allocator: arena).cast<Char>();
      checkCode(git_config_iterator_glob_new(iter, _cfg(handle), cPattern));
    }
    final result = <({String name, String value})>[];
    try {
      final entryOut = arena<Pointer<ConfigEntry>>();
      while (true) {
        final rc = git_config_next(entryOut, iter.value);
        if (rc == ErrorCode.iterover.value) break;
        checkCode(rc);
        final entry = entryOut.value;
        result.add((
          name: entry.ref.name.cast<Utf8>().toDartString(),
          value: entry.ref.value.cast<Utf8>().toDartString(),
        ));
      }
      return result;
    } finally {
      git_config_iterator_free(iter.value);
    }
  });
}

List<String> configMultivar(int handle, String name, {String? pattern}) {
  return using((arena) {
    final iter = arena<Pointer<ConfigIterator>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cPattern = pattern == null
        ? nullptr.cast<Char>()
        : pattern.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_config_multivar_iterator_new(iter, _cfg(handle), cName, cPattern),
    );
    final result = <String>[];
    try {
      final entryOut = arena<Pointer<ConfigEntry>>();
      while (true) {
        final rc = git_config_next(entryOut, iter.value);
        if (rc == ErrorCode.iterover.value) break;
        checkCode(rc);
        result.add(entryOut.value.ref.value.cast<Utf8>().toDartString());
      }
      return result;
    } finally {
      git_config_iterator_free(iter.value);
    }
  });
}

typedef ConfigEntryRecord = ({
  String name,
  String value,
  String backendType,
  String originPath,
  int includeDepth,
  ConfigLevel level,
});

int configForeach(
  int handle,
  int Function(ConfigEntryRecord entry) callback, {
  String? pattern,
}) {
  return using((arena) {
    final cb = _foreachCallable(callback);
    try {
      final cfg = _cfg(handle);
      final code = pattern == null
          ? git_config_foreach(cfg, cb.nativeFunction.cast(), nullptr.cast())
          : git_config_foreach_match(
              cfg,
              pattern.toNativeUtf8(allocator: arena).cast<Char>(),
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

int configMultivarForeach(
  int handle,
  String name,
  int Function(ConfigEntryRecord entry) callback, {
  String? pattern,
}) {
  return using((arena) {
    final cb = _foreachCallable(callback);
    try {
      final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
      final cPattern = pattern == null
          ? nullptr.cast<Char>()
          : pattern.toNativeUtf8(allocator: arena).cast<Char>();
      final code = git_config_get_multivar_foreach(
        _cfg(handle),
        cName,
        cPattern,
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

int configBackendForeachMatch(
  int backendHandle,
  String pattern,
  int Function(ConfigEntryRecord entry) callback,
) {
  return using((arena) {
    final cb = _foreachCallable(callback);
    try {
      final code = git_config_backend_foreach_match(
        Pointer<ConfigBackend>.fromAddress(backendHandle),
        pattern.toNativeUtf8(allocator: arena).cast<Char>(),
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

int configLock(int handle) {
  return using((arena) {
    final out = arena<Pointer<Transaction>>();
    checkCode(git_config_lock(out, _cfg(handle)));
    return out.value.address;
  });
}

void configSetWriteOrder(int handle, List<ConfigLevel> levels) {
  using((arena) {
    if (levels.isEmpty) {
      checkCode(git_config_set_writeorder(_cfg(handle), nullptr.cast(), 0));
      return;
    }
    final buf = arena<UnsignedInt>(levels.length);
    for (var i = 0; i < levels.length; i++) {
      buf[i] = levels[i].value;
    }
    checkCode(
      git_config_set_writeorder(_cfg(handle), buf.cast(), levels.length),
    );
  });
}

String? configGetStringDirect(int handle, String name) {
  return using((arena) {
    final out = arena<Pointer<Char>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final result = git_config_get_string(out, _cfg(handle), cName);
    if (result == ErrorCode.enotfound.value) return null;
    checkCode(result);
    if (out.value == nullptr) return null;
    return out.value.cast<Utf8>().toDartString();
  });
}

NativeCallable<Int Function(Pointer<ConfigEntry>, Pointer<Void>)>
_foreachCallable(int Function(ConfigEntryRecord entry) callback) {
  return NativeCallable<
    Int Function(Pointer<ConfigEntry>, Pointer<Void>)
  >.isolateLocal((Pointer<ConfigEntry> entry, Pointer<Void> _) {
    try {
      return callback((
        name: entry.ref.name.cast<Utf8>().toDartString(),
        value: entry.ref.value == nullptr
            ? ''
            : entry.ref.value.cast<Utf8>().toDartString(),
        backendType: entry.ref.backend_type == nullptr
            ? ''
            : entry.ref.backend_type.cast<Utf8>().toDartString(),
        originPath: entry.ref.origin_path == nullptr
            ? ''
            : entry.ref.origin_path.cast<Utf8>().toDartString(),
        includeDepth: entry.ref.include_depth,
        level: entry.ref.level,
      ));
    } on Object {
      return -1;
    }
  }, exceptionalReturn: -1);
}

bool configParseBool(String value) {
  return using((arena) {
    final out = arena<Int>();
    final cValue = value.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_config_parse_bool(out, cValue));
    return out.value != 0;
  });
}

int configParseInt32(String value) {
  return using((arena) {
    final out = arena<Int32>();
    final cValue = value.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_config_parse_int32(out, cValue));
    return out.value;
  });
}

int configParseInt64(String value) {
  return using((arena) {
    final out = arena<Int64>();
    final cValue = value.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_config_parse_int64(out, cValue));
    return out.value;
  });
}

String configParsePath(String value) {
  return using((arena) {
    final buf = arena<Buf>();
    final cValue = value.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      checkCode(git_config_parse_path(buf, cValue));
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

int configFromRepository(int repoHandle) {
  return using((arena) {
    final out = arena<Pointer<Config>>();
    checkCode(
      git_repository_config(out, Pointer<Repository>.fromAddress(repoHandle)),
    );
    return out.value.address;
  });
}

int configSnapshotFromRepository(int repoHandle) {
  return using((arena) {
    final out = arena<Pointer<Config>>();
    checkCode(
      git_repository_config_snapshot(
        out,
        Pointer<Repository>.fromAddress(repoHandle),
      ),
    );
    return out.value.address;
  });
}

String? _findWithBuf(int Function(Pointer<Buf>) finder) {
  return using((arena) {
    final buf = arena<Buf>();
    try {
      final result = finder(buf);
      if (result == ErrorCode.enotfound.value) return null;
      checkCode(result);
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

Pointer<Config> _cfg(int handle) => Pointer<Config>.fromAddress(handle);
