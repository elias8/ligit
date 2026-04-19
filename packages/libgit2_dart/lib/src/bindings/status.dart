import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show Status, StatusOpt, StatusShow;

const statusOptDefaults = GIT_STATUS_OPT_DEFAULTS;

int statusFile(int repoHandle, String path) {
  return using((arena) {
    final out = arena<UnsignedInt>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_status_file(out, _repo(repoHandle), cPath));
    return out.value;
  });
}

bool statusShouldIgnore(int repoHandle, String path) {
  return using((arena) {
    final out = arena<Int>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_status_should_ignore(out, _repo(repoHandle), cPath));
    return out.value == 1;
  });
}

int statusListNew(
  int repoHandle, {
  StatusShow show = StatusShow.indexAndWorkdir,
  int flags = GIT_STATUS_OPT_DEFAULTS,
  List<String> pathspec = const [],
  int? baselineTreeHandle,
  int renameThreshold = 50,
}) {
  return using((arena) {
    final out = arena<Pointer<StatusList>>();
    final opts = arena<StatusOptions>();
    checkCode(git_status_options_init(opts, GIT_STATUS_OPTIONS_VERSION));
    opts.ref.showAsInt = show.value;
    opts.ref.flags = flags;
    opts.ref.rename_threshold = renameThreshold;
    if (pathspec.isNotEmpty) {
      final ptrs = arena<Pointer<Char>>(pathspec.length);
      for (var i = 0; i < pathspec.length; i++) {
        ptrs[i] = pathspec[i].toNativeUtf8(allocator: arena).cast<Char>();
      }
      opts.ref.pathspec.strings = ptrs;
      opts.ref.pathspec.count = pathspec.length;
    }
    if (baselineTreeHandle != null) {
      opts.ref.baseline = Pointer<Tree>.fromAddress(baselineTreeHandle);
    }
    checkCode(git_status_list_new(out, _repo(repoHandle), opts));
    return out.value.address;
  });
}

int statusListEntryCount(int handle) =>
    git_status_list_entrycount(_list(handle));

({int flags, String path})? statusListEntry(int handle, int index) {
  final ptr = git_status_byindex(_list(handle), index);
  if (ptr == nullptr) return null;
  final entry = ptr.ref;
  final flags = entry.statusAsInt;
  String path;
  if (entry.index_to_workdir != nullptr) {
    final delta = entry.index_to_workdir.ref;
    path = delta.new_file.path.cast<Utf8>().toDartString();
  } else if (entry.head_to_index != nullptr) {
    final delta = entry.head_to_index.ref;
    path = delta.new_file.path.cast<Utf8>().toDartString();
  } else {
    path = '';
  }
  return (flags: flags, path: path);
}

void statusListFree(int handle) => git_status_list_free(_list(handle));

int statusForeach(
  int repoHandle,
  int Function(String path, int statusFlags) callback,
) {
  final cb = _statusCallable(callback);
  try {
    final code = git_status_foreach(
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

int statusForeachExt(
  int repoHandle,
  int Function(String path, int statusFlags) callback, {
  StatusShow show = StatusShow.indexAndWorkdir,
  int flags = GIT_STATUS_OPT_DEFAULTS,
  List<String> pathspec = const [],
  int? baselineTreeHandle,
  int renameThreshold = 50,
}) {
  return using((arena) {
    final opts = arena<StatusOptions>();
    checkCode(git_status_options_init(opts, GIT_STATUS_OPTIONS_VERSION));
    opts.ref.showAsInt = show.value;
    opts.ref.flags = flags;
    opts.ref.rename_threshold = renameThreshold;
    if (pathspec.isNotEmpty) {
      final ptrs = arena<Pointer<Char>>(pathspec.length);
      for (var i = 0; i < pathspec.length; i++) {
        ptrs[i] = pathspec[i].toNativeUtf8(allocator: arena).cast<Char>();
      }
      opts.ref.pathspec.strings = ptrs;
      opts.ref.pathspec.count = pathspec.length;
    }
    if (baselineTreeHandle != null) {
      opts.ref.baseline = Pointer<Tree>.fromAddress(baselineTreeHandle);
    }
    final cb = _statusCallable(callback);
    try {
      final code = git_status_foreach_ext(
        _repo(repoHandle),
        opts,
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

NativeCallable<Int Function(Pointer<Char>, UnsignedInt, Pointer<Void>)>
_statusCallable(int Function(String path, int statusFlags) callback) {
  return NativeCallable<
    Int Function(Pointer<Char>, UnsignedInt, Pointer<Void>)
  >.isolateLocal((Pointer<Char> path, int flags, Pointer<Void> _) {
    try {
      return callback(path.cast<Utf8>().toDartString(), flags);
    } on Object {
      return -1;
    }
  }, exceptionalReturn: -1);
}

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);

Pointer<StatusList> _list(int handle) =>
    Pointer<StatusList>.fromAddress(handle);
