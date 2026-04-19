import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

int annotatedCommitLookup(int repoHandle, Uint8List oidBytes) {
  return using((arena) {
    final out = arena<Pointer<AnnotatedCommit>>();
    final oid = _allocOid(arena, oidBytes);
    checkCode(git_annotated_commit_lookup(out, _repo(repoHandle), oid));
    return out.value.address;
  });
}

int annotatedCommitFromRevSpec(int repoHandle, String revSpec) {
  return using((arena) {
    final out = arena<Pointer<AnnotatedCommit>>();
    final cRevSpec = revSpec.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_annotated_commit_from_revspec(out, _repo(repoHandle), cRevSpec),
    );
    return out.value.address;
  });
}

int annotatedCommitFromRef(int repoHandle, int referenceHandle) {
  return using((arena) {
    final out = arena<Pointer<AnnotatedCommit>>();
    checkCode(
      git_annotated_commit_from_ref(
        out,
        _repo(repoHandle),
        Pointer<Reference>.fromAddress(referenceHandle),
      ),
    );
    return out.value.address;
  });
}

int annotatedCommitFromFetchHead(
  int repoHandle,
  String branchName,
  String remoteUrl,
  Uint8List oidBytes,
) {
  return using((arena) {
    final out = arena<Pointer<AnnotatedCommit>>();
    final cBranch = branchName.toNativeUtf8(allocator: arena).cast<Char>();
    final cUrl = remoteUrl.toNativeUtf8(allocator: arena).cast<Char>();
    final oid = _allocOid(arena, oidBytes);
    checkCode(
      git_annotated_commit_from_fetchhead(
        out,
        _repo(repoHandle),
        cBranch,
        cUrl,
        oid,
      ),
    );
    return out.value.address;
  });
}

Uint8List annotatedCommitId(int handle) {
  return _oidBytes(git_annotated_commit_id(_annotated(handle)));
}

String? annotatedCommitRef(int handle) {
  final ptr = git_annotated_commit_ref(_annotated(handle));
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

void annotatedCommitFree(int handle) {
  git_annotated_commit_free(_annotated(handle));
}

Pointer<AnnotatedCommit> _annotated(int handle) =>
    Pointer<AnnotatedCommit>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);

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
