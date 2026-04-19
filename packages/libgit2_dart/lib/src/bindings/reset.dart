import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show Reset;

void reset(int repoHandle, int targetHandle, Reset type) {
  checkCode(
    git_reset(
      _repo(repoHandle),
      Pointer<Object>.fromAddress(targetHandle),
      type,
      nullptr.cast<CheckoutOptions>(),
    ),
  );
}

void resetFromAnnotated(int repoHandle, int annotatedCommitHandle, Reset type) {
  checkCode(
    git_reset_from_annotated(
      _repo(repoHandle),
      Pointer<AnnotatedCommit>.fromAddress(annotatedCommitHandle),
      type,
      nullptr.cast<CheckoutOptions>(),
    ),
  );
}

void resetDefault(int repoHandle, int? targetHandle, List<String> pathspecs) {
  using((arena) {
    final target = targetHandle == null
        ? nullptr.cast<Object>()
        : Pointer<Object>.fromAddress(targetHandle);
    final arr = arena<Strarray>();
    final ptrs = arena<Pointer<Char>>(pathspecs.length);
    for (var i = 0; i < pathspecs.length; i++) {
      ptrs[i] = pathspecs[i].toNativeUtf8(allocator: arena).cast<Char>();
    }
    arr.ref.strings = ptrs;
    arr.ref.count = pathspecs.length;
    checkCode(git_reset_default(_repo(repoHandle), target, arr));
  });
}

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
