import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

int transactionNew(int repoHandle) {
  return using((arena) {
    final out = arena<Pointer<Transaction>>();
    checkCode(git_transaction_new(out, _repo(repoHandle)));
    return out.value.address;
  });
}

void transactionLockRef(int handle, String refname) {
  using((arena) {
    final cName = refname.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_transaction_lock_ref(_tx(handle), cName));
  });
}

void transactionSetTarget(
  int handle,
  String refname,
  Uint8List target, {
  int signatureHandle = 0,
  String? message,
}) {
  using((arena) {
    final cName = refname.toNativeUtf8(allocator: arena).cast<Char>();
    final cMsg = message == null
        ? nullptr.cast<Char>()
        : message.toNativeUtf8(allocator: arena).cast<Char>();
    final oid = arena<Oid>();
    for (var i = 0; i < target.length; i++) {
      oid.ref.id[i] = target[i];
    }
    final sig = signatureHandle == 0
        ? nullptr.cast<Signature>()
        : Pointer<Signature>.fromAddress(signatureHandle);
    checkCode(git_transaction_set_target(_tx(handle), cName, oid, sig, cMsg));
  });
}

void transactionSetSymbolicTarget(
  int handle,
  String refname,
  String target, {
  int signatureHandle = 0,
  String? message,
}) {
  using((arena) {
    final cName = refname.toNativeUtf8(allocator: arena).cast<Char>();
    final cTarget = target.toNativeUtf8(allocator: arena).cast<Char>();
    final cMsg = message == null
        ? nullptr.cast<Char>()
        : message.toNativeUtf8(allocator: arena).cast<Char>();
    final sig = signatureHandle == 0
        ? nullptr.cast<Signature>()
        : Pointer<Signature>.fromAddress(signatureHandle);
    checkCode(
      git_transaction_set_symbolic_target(
        _tx(handle),
        cName,
        cTarget,
        sig,
        cMsg,
      ),
    );
  });
}

void transactionSetReflog(int handle, String refname, int reflogHandle) {
  using((arena) {
    final cName = refname.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_transaction_set_reflog(
        _tx(handle),
        cName,
        Pointer<Reflog>.fromAddress(reflogHandle),
      ),
    );
  });
}

void transactionRemove(int handle, String refname) {
  using((arena) {
    final cName = refname.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_transaction_remove(_tx(handle), cName));
  });
}

void transactionCommit(int handle) {
  checkCode(git_transaction_commit(_tx(handle)));
}

void transactionFree(int handle) {
  git_transaction_free(_tx(handle));
}

Pointer<Transaction> _tx(int handle) =>
    Pointer<Transaction>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
