import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

int mailmapNew() {
  return using((arena) {
    final out = arena<Pointer<Mailmap>>();
    checkCode(git_mailmap_new(out));
    return out.value.address;
  });
}

void mailmapFree(int handle) => git_mailmap_free(_mailmap(handle));

int mailmapFromBuffer(String content) {
  return using((arena) {
    final out = arena<Pointer<Mailmap>>();
    final bytes = content.toNativeUtf8(allocator: arena);
    checkCode(git_mailmap_from_buffer(out, bytes.cast<Char>(), bytes.length));
    return out.value.address;
  });
}

int mailmapFromRepository(int repoHandle) {
  return using((arena) {
    final out = arena<Pointer<Mailmap>>();
    checkCode(git_mailmap_from_repository(out, _repo(repoHandle)));
    return out.value.address;
  });
}

void mailmapAddEntry(
  int handle, {
  String? realName,
  String? realEmail,
  String? replaceName,
  required String replaceEmail,
}) {
  using((arena) {
    final rn = realName == null
        ? nullptr.cast<Char>()
        : realName.toNativeUtf8(allocator: arena).cast<Char>();
    final re = realEmail == null
        ? nullptr.cast<Char>()
        : realEmail.toNativeUtf8(allocator: arena).cast<Char>();
    final pn = replaceName == null
        ? nullptr.cast<Char>()
        : replaceName.toNativeUtf8(allocator: arena).cast<Char>();
    final pe = replaceEmail.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_mailmap_add_entry(_mailmap(handle), rn, re, pn, pe));
  });
}

({String name, String email}) mailmapResolve(
  int? handle,
  String name,
  String email,
) {
  return using((arena) {
    final nameOut = arena<Pointer<Char>>();
    final emailOut = arena<Pointer<Char>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cEmail = email.toNativeUtf8(allocator: arena).cast<Char>();
    final mm = handle == null ? nullptr.cast<Mailmap>() : _mailmap(handle);
    checkCode(git_mailmap_resolve(nameOut, emailOut, mm, cName, cEmail));
    return (
      name: nameOut.value.cast<Utf8>().toDartString(),
      email: emailOut.value.cast<Utf8>().toDartString(),
    );
  });
}

int mailmapResolveSignature(int handle, int sigHandle) {
  return using((arena) {
    final out = arena<Pointer<Signature>>();
    checkCode(
      git_mailmap_resolve_signature(
        out,
        _mailmap(handle),
        Pointer<Signature>.fromAddress(sigHandle),
      ),
    );
    return out.value.address;
  });
}

Pointer<Mailmap> _mailmap(int handle) => Pointer<Mailmap>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
