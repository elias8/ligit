import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show BranchT;

int branchCreate({
  required int repoHandle,
  required String name,
  required int commitHandle,
  required bool force,
}) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_branch_create(
        out,
        _repo(repoHandle),
        cName,
        _commit(commitHandle),
        force ? 1 : 0,
      ),
    );
    return out.value.address;
  });
}

int branchCreateFromAnnotated({
  required int repoHandle,
  required String name,
  required int annotatedHandle,
  required bool force,
}) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_branch_create_from_annotated(
        out,
        _repo(repoHandle),
        cName,
        _annotated(annotatedHandle),
        force ? 1 : 0,
      ),
    );
    return out.value.address;
  });
}

void branchDelete(int refHandle) {
  checkCode(git_branch_delete(_ref(refHandle)));
}

int branchIteratorNew(int repoHandle, BranchT listFlags) {
  return using((arena) {
    final out = arena<Pointer<BranchIterator>>();
    checkCode(git_branch_iterator_new(out, _repo(repoHandle), listFlags));
    return out.value.address;
  });
}

({int handle, BranchT type})? branchNext(int iteratorHandle) {
  return using((arena) {
    final outRef = arena<Pointer<Reference>>();
    final outType = arena<UnsignedInt>();
    final code = git_branch_next(outRef, outType, _iter(iteratorHandle));
    if (code == ErrorCode.iterover.value) return null;
    checkCode(code);
    return (
      handle: outRef.value.address,
      type: BranchT.fromValue(outType.value),
    );
  });
}

void branchIteratorFree(int iteratorHandle) {
  git_branch_iterator_free(_iter(iteratorHandle));
}

int branchMove(int refHandle, String newName, {required bool force}) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    final cName = newName.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_branch_move(out, _ref(refHandle), cName, force ? 1 : 0));
    return out.value.address;
  });
}

int branchLookup(int repoHandle, String name, BranchT type) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_branch_lookup(out, _repo(repoHandle), cName, type));
    return out.value.address;
  });
}

String branchName(int refHandle) {
  return using((arena) {
    final out = arena<Pointer<Char>>();
    checkCode(git_branch_name(out, _ref(refHandle)));
    return out.value.cast<Utf8>().toDartString();
  });
}

int branchUpstream(int refHandle) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    checkCode(git_branch_upstream(out, _ref(refHandle)));
    return out.value.address;
  });
}

void branchSetUpstream(int refHandle, String? upstreamName) {
  using((arena) {
    final cName = upstreamName == null
        ? nullptr.cast<Char>()
        : upstreamName.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_branch_set_upstream(_ref(refHandle), cName));
  });
}

String branchUpstreamName(int repoHandle, String refname) {
  return using((arena) {
    final buf = arena<Buf>();
    final cName = refname.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      checkCode(git_branch_upstream_name(buf, _repo(repoHandle), cName));
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

String branchUpstreamMerge(int repoHandle, String refname) {
  return using((arena) {
    final buf = arena<Buf>();
    final cName = refname.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      checkCode(git_branch_upstream_merge(buf, _repo(repoHandle), cName));
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

String branchUpstreamRemote(int repoHandle, String refname) {
  return using((arena) {
    final buf = arena<Buf>();
    final cName = refname.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      checkCode(git_branch_upstream_remote(buf, _repo(repoHandle), cName));
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

bool branchIsHead(int refHandle) {
  final code = git_branch_is_head(_ref(refHandle));
  checkCode(code);
  return code == 1;
}

bool branchIsCheckedOut(int refHandle) {
  final code = git_branch_is_checked_out(_ref(refHandle));
  checkCode(code);
  return code == 1;
}

String branchRemoteName(int repoHandle, String refname) {
  return using((arena) {
    final buf = arena<Buf>();
    final cName = refname.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      checkCode(git_branch_remote_name(buf, _repo(repoHandle), cName));
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

bool branchNameIsValid(String name) {
  return using((arena) {
    final out = arena<Int>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_branch_name_is_valid(out, cName));
    return out.value == 1;
  });
}

Pointer<Reference> _ref(int handle) => Pointer<Reference>.fromAddress(handle);

Pointer<BranchIterator> _iter(int handle) {
  return Pointer<BranchIterator>.fromAddress(handle);
}

Pointer<Repository> _repo(int handle) {
  return Pointer<Repository>.fromAddress(handle);
}

Pointer<Commit> _commit(int handle) => Pointer<Commit>.fromAddress(handle);

Pointer<AnnotatedCommit> _annotated(int handle) {
  return Pointer<AnnotatedCommit>.fromAddress(handle);
}
