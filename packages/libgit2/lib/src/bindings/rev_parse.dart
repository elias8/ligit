import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show RevspecT;

int revParseSingle(int repoHandle, String spec) {
  return using((arena) {
    final out = arena<Pointer<Object>>();
    final cSpec = spec.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_revparse_single(out, _repo(repoHandle), cSpec));
    return out.value.address;
  });
}

({int objectHandle, int referenceHandle}) revParseExt(
  int repoHandle,
  String spec,
) {
  return using((arena) {
    final objOut = arena<Pointer<Object>>();
    final refOut = arena<Pointer<Reference>>();
    final cSpec = spec.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_revparse_ext(objOut, refOut, _repo(repoHandle), cSpec));
    return (
      objectHandle: objOut.value.address,
      referenceHandle: refOut.value.address,
    );
  });
}

({int fromHandle, int toHandle, int flags}) revParseRange(
  int repoHandle,
  String spec,
) {
  return using((arena) {
    final revspec = arena<Revspec>();
    final cSpec = spec.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_revparse(revspec, _repo(repoHandle), cSpec));
    return (
      fromHandle: revspec.ref.from.address,
      toHandle: revspec.ref.to.address,
      flags: revspec.ref.flags,
    );
  });
}

Pointer<Repository> _repo(int handle) {
  return Pointer<Repository>.fromAddress(handle);
}
