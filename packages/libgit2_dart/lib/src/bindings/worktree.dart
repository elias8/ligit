import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show WorktreePrune;

List<String> worktreeList(int repoHandle) {
  return using((arena) {
    final arr = arena<Strarray>();
    try {
      checkCode(git_worktree_list(arr, _repo(repoHandle)));
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

int worktreeLookup(int repoHandle, String name) {
  return using((arena) {
    final out = arena<Pointer<Worktree>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_worktree_lookup(out, _repo(repoHandle), cName));
    return out.value.address;
  });
}

int worktreeOpenFromRepository(int repoHandle) {
  return using((arena) {
    final out = arena<Pointer<Worktree>>();
    checkCode(git_worktree_open_from_repository(out, _repo(repoHandle)));
    return out.value.address;
  });
}

void worktreeFree(int handle) => git_worktree_free(_worktree(handle));

bool worktreeValidate(int handle) {
  return git_worktree_validate(_worktree(handle)) == 0;
}

int worktreeAdd(
  int repoHandle,
  String name,
  String path, {
  bool lock = false,
  bool checkoutExisting = false,
  int? referenceHandle,
}) {
  return using((arena) {
    final out = arena<Pointer<Worktree>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final opts = arena<WorktreeAddOptions>();
    checkCode(
      git_worktree_add_options_init(opts, GIT_WORKTREE_ADD_OPTIONS_VERSION),
    );
    opts.ref.lock = lock ? 1 : 0;
    opts.ref.checkout_existing = checkoutExisting ? 1 : 0;
    if (referenceHandle != null) {
      opts.ref.ref = Pointer<Reference>.fromAddress(referenceHandle);
    }
    checkCode(git_worktree_add(out, _repo(repoHandle), cName, cPath, opts));
    return out.value.address;
  });
}

void worktreeLock(int handle, {String? reason}) {
  using((arena) {
    final cReason = reason == null
        ? nullptr.cast<Char>()
        : reason.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_worktree_lock(_worktree(handle), cReason));
  });
}

bool worktreeUnlock(int handle) {
  final result = git_worktree_unlock(_worktree(handle));
  if (result < 0) checkCode(result);
  return result == 0;
}

({bool locked, String? reason}) worktreeIsLocked(int handle) {
  return using((arena) {
    final buf = arena<Buf>();
    try {
      final result = git_worktree_is_locked(buf, _worktree(handle));
      if (result < 0) checkCode(result);
      if (result == 0) return (locked: false, reason: null);
      final ptr = buf.ref.ptr;
      final reason = ptr == nullptr || buf.ref.size == 0
          ? null
          : ptr.cast<Utf8>().toDartString(length: buf.ref.size);
      return (locked: true, reason: reason);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

String worktreeName(int handle) {
  return git_worktree_name(_worktree(handle)).cast<Utf8>().toDartString();
}

String worktreePath(int handle) {
  return git_worktree_path(_worktree(handle)).cast<Utf8>().toDartString();
}

bool worktreeIsPrunable(int handle, {int flags = 0}) {
  return using((arena) {
    final opts = arena<WorktreePruneOptions>();
    checkCode(
      git_worktree_prune_options_init(opts, GIT_WORKTREE_PRUNE_OPTIONS_VERSION),
    );
    opts.ref.flags = flags;
    final result = git_worktree_is_prunable(_worktree(handle), opts);
    if (result < 0) checkCode(result);
    return result == 1;
  });
}

void worktreePrune(int handle, {int flags = 0}) {
  using((arena) {
    final opts = arena<WorktreePruneOptions>();
    checkCode(
      git_worktree_prune_options_init(opts, GIT_WORKTREE_PRUNE_OPTIONS_VERSION),
    );
    opts.ref.flags = flags;
    checkCode(git_worktree_prune(_worktree(handle), opts));
  });
}

Pointer<Worktree> _worktree(int handle) =>
    Pointer<Worktree>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
