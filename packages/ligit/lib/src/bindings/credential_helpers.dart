import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';

typedef CredentialUserpassPayloadData = ({String username, String password});

Pointer<CredentialUserpassPayload> allocUserpassPayload(
  Allocator arena,
  CredentialUserpassPayloadData data,
) {
  final username = data.username.toNativeUtf8(allocator: arena).cast<Char>();
  final password = data.password.toNativeUtf8(allocator: arena).cast<Char>();
  return CredentialUserpassPayload.$allocate(
    arena,
    username: username,
    password: password,
  );
}

Pointer<
  NativeFunction<
    Int Function(
      Pointer<Pointer<Credential>>,
      Pointer<Char>,
      Pointer<Char>,
      UnsignedInt,
      Pointer<Void>,
    )
  >
>
credentialUserpassAddress() => Native.addressOf(git_credential_userpass);
