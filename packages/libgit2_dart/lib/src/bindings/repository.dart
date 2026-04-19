import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart'
    show OidT, RepositoryItem, RepositoryOpenFlag, RepositoryState;

int repositoryOpen(String path) {
  return using((arena) {
    final out = arena<Pointer<Repository>>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_repository_open(out, cPath));
    return out.value.address;
  });
}

int repositoryOpenBare(String path) {
  return using((arena) {
    final out = arena<Pointer<Repository>>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_repository_open_bare(out, cPath));
    return out.value.address;
  });
}

int repositoryOpenExt(String? path, int flags, String? ceilingDirs) {
  return using((arena) {
    final out = arena<Pointer<Repository>>();
    final cPath = path == null
        ? nullptr.cast<Char>()
        : path.toNativeUtf8(allocator: arena).cast<Char>();
    final cCeiling = ceilingDirs == null
        ? nullptr.cast<Char>()
        : ceilingDirs.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_repository_open_ext(out, cPath, flags, cCeiling));
    return out.value.address;
  });
}

int repositoryInit(String path, {required bool bare}) {
  return using((arena) {
    final out = arena<Pointer<Repository>>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_repository_init(out, cPath, bare ? 1 : 0));
    return out.value.address;
  });
}

int repositoryInitExt(
  String path, {
  required int flags,
  required int mode,
  String? workdirPath,
  String? description,
  String? templatePath,
  String? initialHead,
  String? originUrl,
}) {
  return using((arena) {
    final out = arena<Pointer<Repository>>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final opts = arena<RepositoryInitOptions>();
    checkCode(
      git_repository_init_options_init(
        opts,
        GIT_REPOSITORY_INIT_OPTIONS_VERSION,
      ),
    );
    opts.ref.flags = flags;
    opts.ref.mode = mode;
    opts.ref.workdir_path = workdirPath == null
        ? nullptr
        : workdirPath.toNativeUtf8(allocator: arena).cast<Char>();
    opts.ref.description = description == null
        ? nullptr
        : description.toNativeUtf8(allocator: arena).cast<Char>();
    opts.ref.template_path = templatePath == null
        ? nullptr
        : templatePath.toNativeUtf8(allocator: arena).cast<Char>();
    opts.ref.initial_head = initialHead == null
        ? nullptr
        : initialHead.toNativeUtf8(allocator: arena).cast<Char>();
    opts.ref.origin_url = originUrl == null
        ? nullptr
        : originUrl.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_repository_init_ext(out, cPath, opts));
    return out.value.address;
  });
}

String? repositoryDiscover(
  String startPath, {
  bool acrossFs = false,
  String? ceilingDirs,
}) {
  return using((arena) {
    final buf = arena<Buf>();
    final cStart = startPath.toNativeUtf8(allocator: arena).cast<Char>();
    final cCeiling = ceilingDirs == null
        ? nullptr.cast<Char>()
        : ceilingDirs.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      final result = git_repository_discover(
        buf,
        cStart,
        acrossFs ? 1 : 0,
        cCeiling,
      );
      if (result == ErrorCode.enotfound.value) return null;
      checkCode(result);
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

void repositoryFree(int handle) => git_repository_free(_repo(handle));

String repositoryPath(int handle) {
  final ptr = git_repository_path(_repo(handle));
  if (ptr == nullptr) return '';
  return ptr.cast<Utf8>().toDartString();
}

String? repositoryWorkDir(int handle) {
  final ptr = git_repository_workdir(_repo(handle));
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

String repositoryCommonDir(int handle) {
  final ptr = git_repository_commondir(_repo(handle));
  return ptr.cast<Utf8>().toDartString();
}

void repositorySetWorkDir(
  int handle,
  String workdir, {
  required bool updateGitlink,
}) {
  using((arena) {
    final cWorkdir = workdir.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_repository_set_workdir(
        _repo(handle),
        cWorkdir,
        updateGitlink ? 1 : 0,
      ),
    );
  });
}

bool repositoryIsBare(int handle) {
  return git_repository_is_bare(_repo(handle)) == 1;
}

bool repositoryIsEmpty(int handle) {
  final result = git_repository_is_empty(_repo(handle));
  checkCode(result);
  return result == 1;
}

bool repositoryIsShallow(int handle) {
  return git_repository_is_shallow(_repo(handle)) == 1;
}

bool repositoryIsWorktree(int handle) {
  return git_repository_is_worktree(_repo(handle)) == 1;
}

String? repositoryItemPath(int handle, RepositoryItem item) {
  return using((arena) {
    final buf = arena<Buf>();
    try {
      final result = git_repository_item_path(buf, _repo(handle), item);
      if (result == ErrorCode.enotfound.value) return null;
      checkCode(result);
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

bool repositoryHeadDetached(int handle) {
  final result = git_repository_head_detached(_repo(handle));
  checkCode(result);
  return result == 1;
}

bool repositoryHeadDetachedForWorktree(int handle, String name) {
  return using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final result = git_repository_head_detached_for_worktree(
      _repo(handle),
      cName,
    );
    checkCode(result);
    return result == 1;
  });
}

int repositoryHead(int handle) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    checkCode(git_repository_head(out, _repo(handle)));
    return out.value.address;
  });
}

int repositoryHeadForWorktree(int handle, String name) {
  return using((arena) {
    final out = arena<Pointer<Reference>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_repository_head_for_worktree(out, _repo(handle), cName));
    return out.value.address;
  });
}

bool repositoryHeadUnborn(int handle) {
  final result = git_repository_head_unborn(_repo(handle));
  checkCode(result);
  return result == 1;
}

void repositorySetHead(int handle, String refname) {
  using((arena) {
    final cRef = refname.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_repository_set_head(_repo(handle), cRef));
  });
}

void repositorySetHeadDetached(int handle, Uint8List oidBytes) {
  using((arena) {
    final oid = _allocOid(arena, oidBytes);
    checkCode(git_repository_set_head_detached(_repo(handle), oid));
  });
}

void repositorySetHeadDetachedFromAnnotated(int handle, int annotatedHandle) {
  checkCode(
    git_repository_set_head_detached_from_annotated(
      _repo(handle),
      Pointer<AnnotatedCommit>.fromAddress(annotatedHandle),
    ),
  );
}

void repositoryDetachHead(int handle) {
  checkCode(git_repository_detach_head(_repo(handle)));
}

List<int> repositoryCommitParents(int handle) {
  return using((arena) {
    final arr = arena<Commitarray>();
    try {
      checkCode(git_repository_commit_parents(arr, _repo(handle)));
      final count = arr.ref.count;
      final result = <int>[];
      for (var i = 0; i < count; i++) {
        final ptr = (arr.ref.commits + i).value;
        result.add(ptr.address);
      }
      return result;
    } finally {
      git_commitarray_dispose(arr);
    }
  });
}

RepositoryState repositoryState(int handle) {
  final result = git_repository_state(_repo(handle));
  return RepositoryState.fromValue(result);
}

void repositoryStateCleanup(int handle) {
  checkCode(git_repository_state_cleanup(_repo(handle)));
}

void repositorySetNamespace(int handle, String namespace) {
  using((arena) {
    final cNs = namespace.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_repository_set_namespace(_repo(handle), cNs));
  });
}

String? repositoryGetNamespace(int handle) {
  final ptr = git_repository_get_namespace(_repo(handle));
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

({String? name, String? email}) repositoryIdent(int handle) {
  return using((arena) {
    final nameOut = arena<Pointer<Char>>();
    final emailOut = arena<Pointer<Char>>();
    checkCode(git_repository_ident(nameOut, emailOut, _repo(handle)));
    final name = nameOut.value == nullptr
        ? null
        : nameOut.value.cast<Utf8>().toDartString();
    final email = emailOut.value == nullptr
        ? null
        : emailOut.value.cast<Utf8>().toDartString();
    return (name: name, email: email);
  });
}

void repositorySetIdent(int handle, {String? name, String? email}) {
  using((arena) {
    final cName = name == null
        ? nullptr.cast<Char>()
        : name.toNativeUtf8(allocator: arena).cast<Char>();
    final cEmail = email == null
        ? nullptr.cast<Char>()
        : email.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_repository_set_ident(_repo(handle), cName, cEmail));
  });
}

String? repositoryMessage(int handle) {
  return using((arena) {
    final buf = arena<Buf>();
    try {
      final result = git_repository_message(buf, _repo(handle));
      if (result == ErrorCode.enotfound.value) return null;
      checkCode(result);
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

void repositoryMessageRemove(int handle) {
  checkCode(git_repository_message_remove(_repo(handle)));
}

Uint8List repositoryHashFile(
  int handle,
  String path,
  int objectType,
  String? asPath,
) {
  return using((arena) {
    final out = arena<Oid>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final cAsPath = asPath == null
        ? nullptr.cast<Char>()
        : asPath.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_repository_hashfile(
        out,
        _repo(handle),
        cPath,
        ObjectT.fromValue(objectType),
        cAsPath,
      ),
    );
    return _oidBytes(out);
  });
}

int repositoryConfig(int handle) {
  return using((arena) {
    final out = arena<Pointer<Config>>();
    checkCode(git_repository_config(out, _repo(handle)));
    return out.value.address;
  });
}

int repositoryConfigSnapshot(int handle) {
  return using((arena) {
    final out = arena<Pointer<Config>>();
    checkCode(git_repository_config_snapshot(out, _repo(handle)));
    return out.value.address;
  });
}

int repositoryOdb(int handle) {
  return using((arena) {
    final out = arena<Pointer<Odb>>();
    checkCode(git_repository_odb(out, _repo(handle)));
    return out.value.address;
  });
}

int repositoryRefdb(int handle) {
  return using((arena) {
    final out = arena<Pointer<Refdb>>();
    checkCode(git_repository_refdb(out, _repo(handle)));
    return out.value.address;
  });
}

int repositoryIndex(int handle) {
  return using((arena) {
    final out = arena<Pointer<Index>>();
    checkCode(git_repository_index(out, _repo(handle)));
    return out.value.address;
  });
}

int repositoryOpenFromWorktree(int worktreeHandle) {
  return using((arena) {
    final out = arena<Pointer<Repository>>();
    checkCode(
      git_repository_open_from_worktree(
        out,
        Pointer<Worktree>.fromAddress(worktreeHandle),
      ),
    );
    return out.value.address;
  });
}

int repositoryWrapOdb(int odbHandle) {
  return using((arena) {
    final out = arena<Pointer<Repository>>();
    checkCode(
      git_repository_wrap_odb(out, Pointer<Odb>.fromAddress(odbHandle)),
    );
    return out.value.address;
  });
}

int repositoryOidType(int handle) =>
    git_repository_oid_type(_repo(handle)).value;

int repositoryFetchheadForeach(
  int handle,
  int Function({
    required String refName,
    required String remoteUrl,
    required Uint8List oid,
    required bool isMerge,
  })
  callback,
) {
  final cb =
      NativeCallable<
        Int Function(
          Pointer<Char>,
          Pointer<Char>,
          Pointer<Oid>,
          UnsignedInt,
          Pointer<Void>,
        )
      >.isolateLocal((
        Pointer<Char> refName,
        Pointer<Char> remoteUrl,
        Pointer<Oid> oid,
        int isMerge,
        Pointer<Void> _,
      ) {
        try {
          return callback(
            refName: refName.cast<Utf8>().toDartString(),
            remoteUrl: remoteUrl.cast<Utf8>().toDartString(),
            oid: _oidBytes(oid),
            isMerge: isMerge != 0,
          );
        } on Object {
          return -1;
        }
      }, exceptionalReturn: -1);
  try {
    final code = git_repository_fetchhead_foreach(
      _repo(handle),
      cb.nativeFunction.cast(),
      nullptr,
    );
    if (code < 0) checkCode(code);
    return code;
  } finally {
    cb.close();
  }
}

int repositoryMergeheadForeach(
  int handle,
  int Function(Uint8List oid) callback,
) {
  final cb =
      NativeCallable<Int Function(Pointer<Oid>, Pointer<Void>)>.isolateLocal((
        Pointer<Oid> oid,
        Pointer<Void> _,
      ) {
        try {
          return callback(_oidBytes(oid));
        } on Object {
          return -1;
        }
      }, exceptionalReturn: -1);
  try {
    final code = git_repository_mergehead_foreach(
      _repo(handle),
      cb.nativeFunction.cast(),
      nullptr,
    );
    if (code < 0) checkCode(code);
    return code;
  } finally {
    cb.close();
  }
}

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
