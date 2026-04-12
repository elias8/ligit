import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'buffer.dart' show bufString;
import 'types/result.dart';

int commitLookup(int repoHandle, Uint8List oidBytes) {
  return using((arena) {
    final out = arena<Pointer<Commit>>();
    final oid = _allocOid(arena, oidBytes);
    checkCode(git_commit_lookup(out, _repo(repoHandle), oid));
    return out.value.address;
  });
}

int commitLookupPrefix(int repoHandle, Uint8List oidBytes, int prefixLength) {
  return using((arena) {
    final out = arena<Pointer<Commit>>();
    final oid = _allocOid(arena, oidBytes);
    checkCode(
      git_commit_lookup_prefix(out, _repo(repoHandle), oid, prefixLength),
    );
    return out.value.address;
  });
}

void commitFree(int handle) => git_commit_free(_commit(handle));

Uint8List commitId(int handle) => _oidBytes(git_commit_id(_commit(handle)));

int commitOwner(int handle) => git_commit_owner(_commit(handle)).address;

String? commitMessageEncoding(int handle) {
  final ptr = git_commit_message_encoding(_commit(handle));
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

String commitMessage(int handle) {
  return git_commit_message(_commit(handle)).cast<Utf8>().toDartString();
}

String commitMessageRaw(int handle) {
  return git_commit_message_raw(_commit(handle)).cast<Utf8>().toDartString();
}

String? commitSummary(int handle) {
  final ptr = git_commit_summary(_commit(handle));
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

String? commitBody(int handle) {
  final ptr = git_commit_body(_commit(handle));
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

int commitTime(int handle) => git_commit_time(_commit(handle));

int commitTimeOffset(int handle) => git_commit_time_offset(_commit(handle));

({String name, String email, int time, int offset}) commitCommitter(
  int handle,
) {
  return _readSig(git_commit_committer(_commit(handle)));
}

({String name, String email, int time, int offset}) commitAuthor(int handle) {
  return _readSig(git_commit_author(_commit(handle)));
}

String commitRawHeader(int handle) {
  return git_commit_raw_header(_commit(handle)).cast<Utf8>().toDartString();
}

int commitTree(int handle) {
  return using((arena) {
    final out = arena<Pointer<Tree>>();
    checkCode(git_commit_tree(out, _commit(handle)));
    return out.value.address;
  });
}

Uint8List commitTreeId(int handle) {
  return _oidBytes(git_commit_tree_id(_commit(handle)));
}

int commitParentCount(int handle) => git_commit_parentcount(_commit(handle));

int commitParent(int handle, int n) {
  return using((arena) {
    final out = arena<Pointer<Commit>>();
    checkCode(git_commit_parent(out, _commit(handle), n));
    return out.value.address;
  });
}

Uint8List commitParentId(int handle, int n) {
  final commit = _commit(handle);
  final count = git_commit_parentcount(commit);
  if (n < 0 || n >= count) {
    throw RangeError.index(n, List.filled(count, 0), 'n');
  }
  return _oidBytes(git_commit_parent_id(commit, n));
}

int commitNthGenAncestor(int handle, int n) {
  return using((arena) {
    final out = arena<Pointer<Commit>>();
    checkCode(git_commit_nth_gen_ancestor(out, _commit(handle), n));
    return out.value.address;
  });
}

String? commitHeaderField(int handle, String field) {
  return using((arena) {
    final buf = arena<Buf>();
    final cField = field.toNativeUtf8(allocator: arena).cast<Char>();
    final code = git_commit_header_field(buf, _commit(handle), cField);
    if (code == ErrorCode.enotfound.value) return null;
    try {
      checkCode(code);
      if (buf.ref.ptr == nullptr) return null;
      return buf.ref.ptr.cast<Utf8>().toDartString();
    } finally {
      git_buf_dispose(buf);
    }
  });
}

Uint8List commitCreate({
  required int repoHandle,
  String? updateRef,
  required ({String name, String email, int time, int offset}) author,
  required ({String name, String email, int time, int offset}) committer,
  String? messageEncoding,
  required String message,
  required int treeHandle,
  required List<int> parentHandles,
}) {
  return using((arena) {
    final out = arena<Oid>();
    final cUpdateRef = updateRef == null
        ? nullptr.cast<Char>()
        : updateRef.toNativeUtf8(allocator: arena).cast<Char>();
    final cEncoding = messageEncoding == null
        ? nullptr.cast<Char>()
        : messageEncoding.toNativeUtf8(allocator: arena).cast<Char>();
    final cMessage = message.toNativeUtf8(allocator: arena).cast<Char>();
    final parentCount = parentHandles.length;
    final parents = arena<Pointer<Commit>>(parentCount);
    for (var i = 0; i < parentCount; i++) {
      parents[i] = _commit(parentHandles[i]);
    }
    final authorPtr = _allocSignature(arena, author);
    final committerPtr = _allocSignature(arena, committer);
    try {
      checkCode(
        git_commit_create(
          out,
          _repo(repoHandle),
          cUpdateRef,
          authorPtr,
          committerPtr,
          cEncoding,
          cMessage,
          _tree(treeHandle),
          parentCount,
          parents,
        ),
      );
      return _oidBytes(out);
    } finally {
      git_signature_free(authorPtr);
      git_signature_free(committerPtr);
    }
  });
}

Uint8List commitAmend({
  required int commitHandle,
  String? updateRef,
  ({String name, String email, int time, int offset})? author,
  ({String name, String email, int time, int offset})? committer,
  String? messageEncoding,
  String? message,
  int? treeHandle,
}) {
  return using((arena) {
    final out = arena<Oid>();
    final cUpdateRef = updateRef == null
        ? nullptr.cast<Char>()
        : updateRef.toNativeUtf8(allocator: arena).cast<Char>();
    final cEncoding = messageEncoding == null
        ? nullptr.cast<Char>()
        : messageEncoding.toNativeUtf8(allocator: arena).cast<Char>();
    final cMessage = message == null
        ? nullptr.cast<Char>()
        : message.toNativeUtf8(allocator: arena).cast<Char>();
    final tree = treeHandle == null ? nullptr.cast<Tree>() : _tree(treeHandle);
    final authorPtr = author == null
        ? nullptr.cast<Signature>()
        : _allocSignature(arena, author);
    final committerPtr = committer == null
        ? nullptr.cast<Signature>()
        : _allocSignature(arena, committer);
    try {
      checkCode(
        git_commit_amend(
          out,
          _commit(commitHandle),
          cUpdateRef,
          authorPtr,
          committerPtr,
          cEncoding,
          cMessage,
          tree,
        ),
      );
      return _oidBytes(out);
    } finally {
      if (authorPtr != nullptr) git_signature_free(authorPtr);
      if (committerPtr != nullptr) git_signature_free(committerPtr);
    }
  });
}

({String name, String email, int time, int offset}) commitAuthorWithMailmap(
  int handle,
  int mailmapHandle,
) {
  return using((arena) {
    final out = arena<Pointer<Signature>>();
    checkCode(
      git_commit_author_with_mailmap(
        out,
        _commit(handle),
        mailmapHandle == 0
            ? nullptr.cast<Mailmap>()
            : Pointer<Mailmap>.fromAddress(mailmapHandle),
      ),
    );
    try {
      return _readSig(out.value);
    } finally {
      git_signature_free(out.value);
    }
  });
}

({String name, String email, int time, int offset}) commitCommitterWithMailmap(
  int handle,
  int mailmapHandle,
) {
  return using((arena) {
    final out = arena<Pointer<Signature>>();
    checkCode(
      git_commit_committer_with_mailmap(
        out,
        _commit(handle),
        mailmapHandle == 0
            ? nullptr.cast<Mailmap>()
            : Pointer<Mailmap>.fromAddress(mailmapHandle),
      ),
    );
    try {
      return _readSig(out.value);
    } finally {
      git_signature_free(out.value);
    }
  });
}

String commitCreateBuffer({
  required int repoHandle,
  required ({String name, String email, int time, int offset}) author,
  required ({String name, String email, int time, int offset}) committer,
  String? messageEncoding,
  required String message,
  required int treeHandle,
  required List<int> parentHandles,
}) {
  return using((arena) {
    final out = arena<Buf>();
    final cEncoding = messageEncoding == null
        ? nullptr.cast<Char>()
        : messageEncoding.toNativeUtf8(allocator: arena).cast<Char>();
    final cMessage = message.toNativeUtf8(allocator: arena).cast<Char>();
    final parentCount = parentHandles.length;
    final parents = arena<Pointer<Commit>>(parentCount);
    for (var i = 0; i < parentCount; i++) {
      parents[i] = _commit(parentHandles[i]);
    }
    final authorPtr = _allocSignature(arena, author);
    final committerPtr = _allocSignature(arena, committer);
    try {
      checkCode(
        git_commit_create_buffer(
          out,
          _repo(repoHandle),
          authorPtr,
          committerPtr,
          cEncoding,
          cMessage,
          _tree(treeHandle),
          parentCount,
          parents,
        ),
      );
      return bufString(out);
    } finally {
      git_signature_free(authorPtr);
      git_signature_free(committerPtr);
    }
  });
}

Uint8List commitCreateWithSignature({
  required int repoHandle,
  required String content,
  required String signature,
  String? signatureField,
}) {
  return using((arena) {
    final out = arena<Oid>();
    final cContent = content.toNativeUtf8(allocator: arena).cast<Char>();
    final cSig = signature.toNativeUtf8(allocator: arena).cast<Char>();
    final cField = signatureField == null
        ? nullptr.cast<Char>()
        : signatureField.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_commit_create_with_signature(
        out,
        _repo(repoHandle),
        cContent,
        cSig,
        cField,
      ),
    );
    return _oidBytes(out);
  });
}

Uint8List commitCreateFromStage(int repoHandle, String message) {
  return using((arena) {
    final out = arena<Oid>();
    final cMessage = message.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_commit_create_from_stage(
        out,
        _repo(repoHandle),
        cMessage,
        nullptr.cast<CommitCreateOptions>(),
      ),
    );
    return _oidBytes(out);
  });
}

({String signature, String signedData}) commitExtractSignature(
  int repoHandle,
  Uint8List commitId, {
  String? field,
}) {
  return using((arena) {
    final sig = arena<Buf>();
    final body = arena<Buf>();
    final oid = _allocOid(arena, commitId);
    final cField = field == null
        ? nullptr.cast<Char>()
        : field.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      checkCode(
        git_commit_extract_signature(sig, body, _repo(repoHandle), oid, cField),
      );
      return (signature: bufString(sig), signedData: bufString(body));
    } finally {
      git_buf_dispose(sig);
      git_buf_dispose(body);
    }
  });
}

void commitArrayDispose(int arrayAddress) =>
    git_commitarray_dispose(Pointer<Commitarray>.fromAddress(arrayAddress));

int commitDup(int handle) {
  return using((arena) {
    final out = arena<Pointer<Commit>>();
    checkCode(git_commit_dup(out, _commit(handle)));
    return out.value.address;
  });
}

Pointer<Signature> _allocSignature(
  Allocator arena,
  ({String name, String email, int time, int offset}) data,
) {
  final out = arena<Pointer<Signature>>();
  final cName = data.name.toNativeUtf8(allocator: arena).cast<Char>();
  final cEmail = data.email.toNativeUtf8(allocator: arena).cast<Char>();
  checkCode(git_signature_new(out, cName, cEmail, data.time, data.offset));
  return out.value;
}

({String name, String email, int time, int offset}) _readSig(
  Pointer<Signature> sig,
) {
  return (
    name: sig.ref.name.cast<Utf8>().toDartString(),
    email: sig.ref.email.cast<Utf8>().toDartString(),
    time: sig.ref.when.time,
    offset: sig.ref.when.offset,
  );
}

Pointer<Commit> _commit(int handle) => Pointer<Commit>.fromAddress(handle);

Pointer<Tree> _tree(int handle) => Pointer<Tree>.fromAddress(handle);

Pointer<Repository> _repo(int handle) {
  return Pointer<Repository>.fromAddress(handle);
}

Pointer<Oid> _allocOid(Allocator arena, Uint8List bytes) {
  final out = arena<Oid>();
  for (var i = 0; i < 20; i++) {
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
