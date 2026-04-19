import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show RebaseOperationT;

const rebaseNoOperation = GIT_REBASE_NO_OPERATION;

typedef RebaseOperationRecord = ({int type, Uint8List id, String? exec});

typedef SignatureData = ({String name, String email, int time, int offset});

int rebaseInit(
  int repoHandle, {
  int branchHandle = 0,
  int upstreamHandle = 0,
  int ontoHandle = 0,
  bool inMemory = false,
  bool quiet = false,
  String? rewriteNotesRef,
}) {
  return using((arena) {
    final out = arena<Pointer<Rebase>>();
    final opts = _allocOpts(
      arena,
      inMemory: inMemory,
      quiet: quiet,
      rewriteNotesRef: rewriteNotesRef,
    );
    checkCode(
      git_rebase_init(
        out,
        _repo(repoHandle),
        _annotatedOrNull(branchHandle),
        _annotatedOrNull(upstreamHandle),
        _annotatedOrNull(ontoHandle),
        opts,
      ),
    );
    return out.value.address;
  });
}

int rebaseOpen(int repoHandle) {
  return using((arena) {
    final out = arena<Pointer<Rebase>>();
    checkCode(
      git_rebase_open(out, _repo(repoHandle), nullptr.cast<RebaseOptions>()),
    );
    return out.value.address;
  });
}

void rebaseFree(int handle) => git_rebase_free(_rebase(handle));

String rebaseOrigHeadName(int handle) {
  final ptr = git_rebase_orig_head_name(_rebase(handle));
  if (ptr == nullptr) return '';
  return ptr.cast<Utf8>().toDartString();
}

Uint8List rebaseOrigHeadId(int handle) {
  final ptr = git_rebase_orig_head_id(_rebase(handle));
  return _oid(ptr);
}

String rebaseOntoName(int handle) {
  final ptr = git_rebase_onto_name(_rebase(handle));
  if (ptr == nullptr) return '';
  return ptr.cast<Utf8>().toDartString();
}

Uint8List rebaseOntoId(int handle) {
  final ptr = git_rebase_onto_id(_rebase(handle));
  return _oid(ptr);
}

int rebaseOperationEntryCount(int handle) =>
    git_rebase_operation_entrycount(_rebase(handle));

int rebaseOperationCurrent(int handle) =>
    git_rebase_operation_current(_rebase(handle));

RebaseOperationRecord? rebaseOperationByIndex(int handle, int position) {
  final ptr = git_rebase_operation_byindex(_rebase(handle), position);
  if (ptr == nullptr) return null;
  return _readOp(ptr);
}

RebaseOperationRecord rebaseNext(int handle) {
  return using((arena) {
    final out = arena<Pointer<RebaseOperation>>();
    checkCode(git_rebase_next(out, _rebase(handle)));
    return _readOp(out.value);
  });
}

int rebaseInmemoryIndex(int handle) {
  return using((arena) {
    final out = arena<Pointer<Index>>();
    checkCode(git_rebase_inmemory_index(out, _rebase(handle)));
    return out.value.address;
  });
}

Uint8List rebaseCommit(
  int handle, {
  SignatureData? author,
  required SignatureData committer,
  String? messageEncoding,
  String? message,
}) {
  return using((arena) {
    final out = arena<Oid>();
    final authorSig = author == null ? null : _allocSignature(arena, author);
    final committerSig = _allocSignature(arena, committer);
    try {
      final cEnc = messageEncoding == null
          ? nullptr.cast<Char>()
          : messageEncoding.toNativeUtf8(allocator: arena).cast<Char>();
      final cMsg = message == null
          ? nullptr.cast<Char>()
          : message.toNativeUtf8(allocator: arena).cast<Char>();
      checkCode(
        git_rebase_commit(
          out,
          _rebase(handle),
          authorSig ?? nullptr.cast<Signature>(),
          committerSig,
          cEnc,
          cMsg,
        ),
      );
      return _oidFromStruct(out);
    } finally {
      if (authorSig != null) git_signature_free(authorSig);
      git_signature_free(committerSig);
    }
  });
}

void rebaseAbort(int handle) {
  checkCode(git_rebase_abort(_rebase(handle)));
}

void rebaseFinish(int handle, {SignatureData? signature}) {
  using((arena) {
    final sig = signature == null ? null : _allocSignature(arena, signature);
    try {
      checkCode(
        git_rebase_finish(_rebase(handle), sig ?? nullptr.cast<Signature>()),
      );
    } finally {
      if (sig != null) git_signature_free(sig);
    }
  });
}

Pointer<RebaseOptions> _allocOpts(
  Allocator arena, {
  required bool inMemory,
  required bool quiet,
  required String? rewriteNotesRef,
}) {
  final opts = arena<RebaseOptions>();
  checkCode(git_rebase_options_init(opts, GIT_REBASE_OPTIONS_VERSION));
  opts.ref.inmemory = inMemory ? 1 : 0;
  opts.ref.quiet = quiet ? 1 : 0;
  if (rewriteNotesRef != null) {
    opts.ref.rewrite_notes_ref = rewriteNotesRef
        .toNativeUtf8(allocator: arena)
        .cast<Char>();
  }
  return opts;
}

Pointer<Signature> _allocSignature(Allocator arena, SignatureData s) {
  final out = arena<Pointer<Signature>>();
  final cName = s.name.toNativeUtf8(allocator: arena).cast<Char>();
  final cEmail = s.email.toNativeUtf8(allocator: arena).cast<Char>();
  checkCode(git_signature_new(out, cName, cEmail, s.time, s.offset));
  return out.value;
}

RebaseOperationRecord _readOp(Pointer<RebaseOperation> ptr) {
  final op = ptr.ref;
  final id = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    id[i] = op.id.id[i];
  }
  return (
    type: op.typeAsInt,
    id: id,
    exec: op.exec == nullptr ? null : op.exec.cast<Utf8>().toDartString(),
  );
}

Uint8List _oid(Pointer<Oid> ptr) {
  final out = Uint8List(20);
  if (ptr == nullptr) return out;
  for (var i = 0; i < 20; i++) {
    out[i] = ptr.ref.id[i];
  }
  return out;
}

Uint8List _oidFromStruct(Pointer<Oid> ptr) {
  final out = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    out[i] = ptr.ref.id[i];
  }
  return out;
}

Pointer<AnnotatedCommit> _annotatedOrNull(int handle) => handle == 0
    ? nullptr.cast<AnnotatedCommit>()
    : Pointer<AnnotatedCommit>.fromAddress(handle);

Pointer<Rebase> _rebase(int handle) => Pointer<Rebase>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
