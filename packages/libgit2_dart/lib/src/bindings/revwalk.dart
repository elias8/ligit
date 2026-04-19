import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show Sort;

int revwalkNew(int repoHandle) {
  return using((arena) {
    final out = arena<Pointer<Revwalk>>();
    checkCode(git_revwalk_new(out, _repo(repoHandle)));
    return out.value.address;
  });
}

void revwalkReset(int handle) => checkCode(git_revwalk_reset(_walk(handle)));

void revwalkPush(int handle, Uint8List id) {
  using((arena) {
    final oid = _allocOid(arena, id);
    checkCode(git_revwalk_push(_walk(handle), oid));
  });
}

void revwalkPushGlob(int handle, String pattern) {
  using((arena) {
    final cPattern = pattern.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_revwalk_push_glob(_walk(handle), cPattern));
  });
}

void revwalkPushHead(int handle) {
  checkCode(git_revwalk_push_head(_walk(handle)));
}

void revwalkPushRef(int handle, String refname) {
  using((arena) {
    final cName = refname.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_revwalk_push_ref(_walk(handle), cName));
  });
}

void revwalkPushRange(int handle, String range) {
  using((arena) {
    final cRange = range.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_revwalk_push_range(_walk(handle), cRange));
  });
}

void revwalkHide(int handle, Uint8List id) {
  using((arena) {
    final oid = _allocOid(arena, id);
    checkCode(git_revwalk_hide(_walk(handle), oid));
  });
}

void revwalkHideGlob(int handle, String pattern) {
  using((arena) {
    final cPattern = pattern.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_revwalk_hide_glob(_walk(handle), cPattern));
  });
}

void revwalkHideHead(int handle) {
  checkCode(git_revwalk_hide_head(_walk(handle)));
}

void revwalkHideRef(int handle, String refname) {
  using((arena) {
    final cName = refname.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_revwalk_hide_ref(_walk(handle), cName));
  });
}

Uint8List? revwalkNext(int handle) {
  return using((arena) {
    final out = arena<Oid>();
    final result = git_revwalk_next(out, _walk(handle));
    if (result == ErrorCode.iterover.value) return null;
    checkCode(result);
    return _oidBytes(out);
  });
}

void revwalkSorting(int handle, int sortMode) {
  checkCode(git_revwalk_sorting(_walk(handle), sortMode));
}

void revwalkSimplifyFirstParent(int handle) {
  checkCode(git_revwalk_simplify_first_parent(_walk(handle)));
}

void revwalkFree(int handle) => git_revwalk_free(_walk(handle));

int revwalkRepository(int handle) =>
    git_revwalk_repository(_walk(handle)).address;

void Function()? revwalkAddHideCb(
  int handle,
  int Function(Uint8List commitId)? callback,
) {
  if (callback == null) {
    checkCode(git_revwalk_add_hide_cb(_walk(handle), nullptr.cast(), nullptr));
    return null;
  }
  final cb =
      NativeCallable<Int Function(Pointer<Oid>, Pointer<Void>)>.isolateLocal((
        Pointer<Oid> id,
        Pointer<Void> _,
      ) {
        try {
          return callback(_oidBytes(id));
        } on Object {
          return -1;
        }
      }, exceptionalReturn: -1);
  checkCode(
    git_revwalk_add_hide_cb(_walk(handle), cb.nativeFunction.cast(), nullptr),
  );
  return cb.close;
}

Pointer<Revwalk> _walk(int handle) => Pointer<Revwalk>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);

Pointer<Oid> _allocOid(Allocator arena, Uint8List bytes) {
  final out = arena<Oid>();
  for (var i = 0; i < bytes.length; i++) {
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
