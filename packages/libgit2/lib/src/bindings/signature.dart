import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

int signatureNew(String name, String email, int time, int offset) {
  return using((arena) {
    final out = arena<Pointer<Signature>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cEmail = email.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_signature_new(out, cName, cEmail, time, offset));
    return out.value.address;
  });
}

int signatureNow(String name, String email) {
  return using((arena) {
    final out = arena<Pointer<Signature>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cEmail = email.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_signature_now(out, cName, cEmail));
    return out.value.address;
  });
}

int signatureFromBuffer(String buf) {
  return using((arena) {
    final out = arena<Pointer<Signature>>();
    final cBuf = buf.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_signature_from_buffer(out, cBuf));
    return out.value.address;
  });
}

int signatureDup(int handle) {
  return using((arena) {
    final out = arena<Pointer<Signature>>();
    checkCode(git_signature_dup(out, _sig(handle)));
    return out.value.address;
  });
}

int signatureDefault(int repoHandle) {
  return using((arena) {
    final out = arena<Pointer<Signature>>();
    checkCode(git_signature_default(out, _repo(repoHandle)));
    return out.value.address;
  });
}

({int? author, int? committer}) signatureDefaultFromEnv(
  int repoHandle, {
  bool wantAuthor = true,
  bool wantCommitter = true,
}) {
  return using((arena) {
    final author = wantAuthor ? arena<Pointer<Signature>>() : null;
    final committer = wantCommitter ? arena<Pointer<Signature>>() : null;
    checkCode(
      git_signature_default_from_env(
        author ?? nullptr.cast(),
        committer ?? nullptr.cast(),
        _repo(repoHandle),
      ),
    );
    return (author: author?.value.address, committer: committer?.value.address);
  });
}

void signatureFree(int handle) => git_signature_free(_sig(handle));

({String name, String email, int time, int offset}) signatureRead(int handle) {
  final sig = _sig(handle);
  return (
    name: sig.ref.name.cast<Utf8>().toDartString(),
    email: sig.ref.email.cast<Utf8>().toDartString(),
    time: sig.ref.when.time,
    offset: sig.ref.when.offset,
  );
}

Pointer<Signature> _sig(int handle) => Pointer<Signature>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
