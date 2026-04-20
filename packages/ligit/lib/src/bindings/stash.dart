import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart'
    show StashApplyFlags, StashApplyProgress, StashFlags;

Uint8List stashSave(
  int repoHandle,
  int stasherHandle, {
  String? message,
  int flags = 0,
}) {
  return using((arena) {
    final out = arena<Oid>();
    final cMessage = message == null
        ? nullptr.cast<Char>()
        : message.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_stash_save(
        out,
        _repo(repoHandle),
        Pointer<Signature>.fromAddress(stasherHandle),
        cMessage,
        flags,
      ),
    );
    return _oidBytes(out);
  });
}

Uint8List stashSaveWithOpts(
  int repoHandle,
  int stasherHandle, {
  String? message,
  int flags = 0,
  List<String> paths = const [],
}) {
  return using((arena) {
    final out = arena<Oid>();
    final opts = arena<StashSaveOptions>();
    checkCode(
      git_stash_save_options_init(opts, GIT_STASH_SAVE_OPTIONS_VERSION),
    );
    opts.ref.flags = flags;
    opts.ref.stasher = Pointer<Signature>.fromAddress(stasherHandle);
    opts.ref.message = message == null
        ? nullptr.cast<Char>()
        : message.toNativeUtf8(allocator: arena).cast<Char>();
    if (paths.isNotEmpty) {
      final ptrs = arena<Pointer<Char>>(paths.length);
      for (var i = 0; i < paths.length; i++) {
        ptrs[i] = paths[i].toNativeUtf8(allocator: arena).cast<Char>();
      }
      opts.ref.paths.strings = ptrs;
      opts.ref.paths.count = paths.length;
    }
    checkCode(git_stash_save_with_opts(out, _repo(repoHandle), opts));
    return _oidBytes(out);
  });
}

void stashApply(int repoHandle, int index, {int flags = 0}) {
  using((arena) {
    final opts = arena<StashApplyOptions>();
    checkCode(
      git_stash_apply_options_init(opts, GIT_STASH_APPLY_OPTIONS_VERSION),
    );
    opts.ref.flags = flags;
    checkCode(git_stash_apply(_repo(repoHandle), index, opts));
  });
}

void stashPop(int repoHandle, int index, {int flags = 0}) {
  using((arena) {
    final opts = arena<StashApplyOptions>();
    checkCode(
      git_stash_apply_options_init(opts, GIT_STASH_APPLY_OPTIONS_VERSION),
    );
    opts.ref.flags = flags;
    checkCode(git_stash_pop(_repo(repoHandle), index, opts));
  });
}

int stashForeach(
  int repoHandle,
  int Function(int index, String message, Uint8List stashId) callback,
) {
  final cb =
      NativeCallable<
        Int Function(Size, Pointer<Char>, Pointer<Oid>, Pointer<Void>)
      >.isolateLocal((
        int index,
        Pointer<Char> message,
        Pointer<Oid> oid,
        Pointer<Void> _,
      ) {
        try {
          final id = Uint8List(20);
          for (var i = 0; i < 20; i++) {
            id[i] = oid.ref.id[i];
          }
          return callback(
            index,
            message == nullptr ? '' : message.cast<Utf8>().toDartString(),
            id,
          );
        } on Object {
          return -1;
        }
      }, exceptionalReturn: -1);
  try {
    final code = git_stash_foreach(
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

void stashDrop(int repoHandle, int index) {
  checkCode(git_stash_drop(_repo(repoHandle), index));
}

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);

Uint8List _oidBytes(Pointer<Oid> ptr) {
  final out = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    out[i] = ptr.ref.id[i];
  }
  return out;
}
