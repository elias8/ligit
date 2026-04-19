import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

int reflogRead(int repoHandle, String name) {
  return using((arena) {
    final out = arena<Pointer<Reflog>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_reflog_read(out, _repo(repoHandle), cName));
    return out.value.address;
  });
}

void reflogWrite(int handle) => checkCode(git_reflog_write(_reflog(handle)));

void reflogAppend(
  int handle, {
  required Uint8List id,
  required String committerName,
  required String committerEmail,
  required int time,
  required int offset,
  String? message,
}) {
  using((arena) {
    final oid = _allocOid(arena, id);
    final cName = committerName.toNativeUtf8(allocator: arena).cast<Char>();
    final cEmail = committerEmail.toNativeUtf8(allocator: arena).cast<Char>();
    final sigOut = arena<Pointer<Signature>>();
    checkCode(git_signature_new(sigOut, cName, cEmail, time, offset));
    final sig = sigOut.value;
    try {
      final cMsg = message == null
          ? nullptr
          : message.toNativeUtf8(allocator: arena).cast<Char>();
      checkCode(git_reflog_append(_reflog(handle), oid, sig, cMsg));
    } finally {
      git_signature_free(sig);
    }
  });
}

void reflogRename(int repoHandle, String oldName, String newName) {
  using((arena) {
    final cOld = oldName.toNativeUtf8(allocator: arena).cast<Char>();
    final cNew = newName.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_reflog_rename(_repo(repoHandle), cOld, cNew));
  });
}

void reflogDelete(int repoHandle, String name) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_reflog_delete(_repo(repoHandle), cName));
  });
}

int reflogEntryCount(int handle) => git_reflog_entrycount(_reflog(handle));

int reflogEntryByIndex(int handle, int index) {
  return git_reflog_entry_byindex(_reflog(handle), index).address;
}

void reflogDrop(int handle, int index, {bool rewritePreviousEntry = false}) {
  checkCode(
    git_reflog_drop(_reflog(handle), index, rewritePreviousEntry ? 1 : 0),
  );
}

Uint8List reflogEntryIdOld(int entryHandle) {
  return _oidBytes(git_reflog_entry_id_old(_entry(entryHandle)));
}

Uint8List reflogEntryIdNew(int entryHandle) {
  return _oidBytes(git_reflog_entry_id_new(_entry(entryHandle)));
}

int reflogEntryCommitter(int entryHandle) {
  return git_reflog_entry_committer(_entry(entryHandle)).address;
}

String? reflogEntryMessage(int entryHandle) {
  final ptr = git_reflog_entry_message(_entry(entryHandle));
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

void reflogFree(int handle) => git_reflog_free(_reflog(handle));

Pointer<Reflog> _reflog(int handle) => Pointer<Reflog>.fromAddress(handle);

Pointer<ReflogEntry> _entry(int handle) =>
    Pointer<ReflogEntry>.fromAddress(handle);

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
