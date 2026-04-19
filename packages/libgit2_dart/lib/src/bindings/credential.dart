import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show CredentialT;

int credentialUserpassPlaintextNew(String username, String password) {
  return using((arena) {
    final out = arena<Pointer<Credential>>();
    final cUser = username.toNativeUtf8(allocator: arena).cast<Char>();
    final cPass = password.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_credential_userpass_plaintext_new(out, cUser, cPass));
    return out.value.address;
  });
}

int credentialDefaultNew() {
  return using((arena) {
    final out = arena<Pointer<Credential>>();
    checkCode(git_credential_default_new(out));
    return out.value.address;
  });
}

int credentialUsernameNew(String username) {
  return using((arena) {
    final out = arena<Pointer<Credential>>();
    final cUser = username.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_credential_username_new(out, cUser));
    return out.value.address;
  });
}

int credentialSshKeyNew(
  String username,
  String privateKeyPath, {
  String? publicKeyPath,
  String? passphrase,
}) {
  return using((arena) {
    final out = arena<Pointer<Credential>>();
    final cUser = username.toNativeUtf8(allocator: arena).cast<Char>();
    final cPriv = privateKeyPath.toNativeUtf8(allocator: arena).cast<Char>();
    final cPub = publicKeyPath == null
        ? nullptr.cast<Char>()
        : publicKeyPath.toNativeUtf8(allocator: arena).cast<Char>();
    final cPass = passphrase == null
        ? nullptr.cast<Char>()
        : passphrase.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_credential_ssh_key_new(out, cUser, cPub, cPriv, cPass));
    return out.value.address;
  });
}

int credentialSshKeyMemoryNew(
  String username,
  String privateKey, {
  String? publicKey,
  String? passphrase,
}) {
  return using((arena) {
    final out = arena<Pointer<Credential>>();
    final cUser = username.toNativeUtf8(allocator: arena).cast<Char>();
    final cPriv = privateKey.toNativeUtf8(allocator: arena).cast<Char>();
    final cPub = publicKey == null
        ? nullptr.cast<Char>()
        : publicKey.toNativeUtf8(allocator: arena).cast<Char>();
    final cPass = passphrase == null
        ? nullptr.cast<Char>()
        : passphrase.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_credential_ssh_key_memory_new(out, cUser, cPub, cPriv, cPass),
    );
    return out.value.address;
  });
}

int credentialSshKeyFromAgent(String username) {
  return using((arena) {
    final out = arena<Pointer<Credential>>();
    final cUser = username.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_credential_ssh_key_from_agent(out, cUser));
    return out.value.address;
  });
}

void credentialFree(int handle) => git_credential_free(_cred(handle));

bool credentialHasUsername(int handle) =>
    git_credential_has_username(_cred(handle)) == 1;

String? credentialGetUsername(int handle) {
  final ptr = git_credential_get_username(_cred(handle));
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

Pointer<Credential> _cred(int handle) =>
    Pointer<Credential>.fromAddress(handle);
