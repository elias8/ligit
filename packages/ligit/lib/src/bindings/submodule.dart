import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'checkout.dart' show writeCheckoutOptionsInto;
import 'remote.dart' show FetchOptionsRecord, writeFetchOptionsInto;
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart'
    show SubmoduleIgnore, SubmoduleRecurse, SubmoduleStatus, SubmoduleUpdate;

int submoduleLookup(int repoHandle, String name) {
  return using((arena) {
    final out = arena<Pointer<Submodule>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_submodule_lookup(out, _repo(repoHandle), cName));
    return out.value.address;
  });
}

int submoduleDup(int sourceHandle) {
  return using((arena) {
    final out = arena<Pointer<Submodule>>();
    checkCode(git_submodule_dup(out, _submodule(sourceHandle)));
    return out.value.address;
  });
}

void submoduleFree(int handle) => git_submodule_free(_submodule(handle));

List<String> submoduleForeach(int repoHandle) {
  return using((arena) {
    final names = <String>[];
    late NativeCallable<
      Int Function(Pointer<Submodule>, Pointer<Char>, Pointer<Void>)
    >
    cb;
    cb = NativeCallable.isolateLocal((
      Pointer<Submodule> _,
      Pointer<Char> name,
      Pointer<Void> _,
    ) {
      try {
        names.add(name.cast<Utf8>().toDartString());
        return 0;
      } on Object {
        return -1;
      }
    }, exceptionalReturn: -1);
    try {
      checkCode(
        git_submodule_foreach(
          _repo(repoHandle),
          cb.nativeFunction.cast(),
          nullptr,
        ),
      );
    } finally {
      cb.close();
    }
    return names;
  });
}

int submoduleAddSetup(
  int repoHandle,
  String url,
  String path, {
  bool useGitlink = true,
}) {
  return using((arena) {
    final out = arena<Pointer<Submodule>>();
    final cUrl = url.toNativeUtf8(allocator: arena).cast<Char>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_submodule_add_setup(
        out,
        _repo(repoHandle),
        cUrl,
        cPath,
        useGitlink ? 1 : 0,
      ),
    );
    return out.value.address;
  });
}

void submoduleAddFinalize(int handle) {
  checkCode(git_submodule_add_finalize(_submodule(handle)));
}

void submoduleAddToIndex(int handle, {bool writeIndex = true}) {
  checkCode(git_submodule_add_to_index(_submodule(handle), writeIndex ? 1 : 0));
}

int submoduleOwner(int handle) =>
    git_submodule_owner(_submodule(handle)).address;

String submoduleName(int handle) {
  final ptr = git_submodule_name(_submodule(handle));
  if (ptr == nullptr) return '';
  return ptr.cast<Utf8>().toDartString();
}

String submodulePath(int handle) {
  final ptr = git_submodule_path(_submodule(handle));
  if (ptr == nullptr) return '';
  return ptr.cast<Utf8>().toDartString();
}

String submoduleUrl(int handle) {
  final ptr = git_submodule_url(_submodule(handle));
  if (ptr == nullptr) return '';
  return ptr.cast<Utf8>().toDartString();
}

String? submoduleBranch(int handle) {
  final ptr = git_submodule_branch(_submodule(handle));
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

String submoduleResolveUrl(int repoHandle, String url) {
  return using((arena) {
    final buf = arena<Buf>();
    final cUrl = url.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_submodule_resolve_url(buf, _repo(repoHandle), cUrl));
    try {
      return buf.ref.ptr.cast<Utf8>().toDartString();
    } finally {
      git_buf_dispose(buf);
    }
  });
}

void submoduleSetUrl(int repoHandle, String name, String url) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cUrl = url.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_submodule_set_url(_repo(repoHandle), cName, cUrl));
  });
}

void submoduleSetBranch(int repoHandle, String name, String branch) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cBranch = branch.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_submodule_set_branch(_repo(repoHandle), cName, cBranch));
  });
}

Uint8List? submoduleIndexId(int handle) =>
    _oidOrNull(git_submodule_index_id(_submodule(handle)));

Uint8List? submoduleHeadId(int handle) =>
    _oidOrNull(git_submodule_head_id(_submodule(handle)));

Uint8List? submoduleWdId(int handle) =>
    _oidOrNull(git_submodule_wd_id(_submodule(handle)));

int submoduleIgnore(int handle) =>
    git_submodule_ignore(_submodule(handle)).value;

void submoduleSetIgnore(int repoHandle, String name, int rule) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_submodule_set_ignore(
        _repo(repoHandle),
        cName,
        SubmoduleIgnore.fromValue(rule),
      ),
    );
  });
}

int submoduleUpdateStrategy(int handle) =>
    git_submodule_update_strategy(_submodule(handle)).value;

void submoduleSetUpdate(int repoHandle, String name, int rule) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_submodule_set_update(
        _repo(repoHandle),
        cName,
        SubmoduleUpdate.fromValue(rule),
      ),
    );
  });
}

int submoduleFetchRecurseSubmodules(int handle) =>
    git_submodule_fetch_recurse_submodules(_submodule(handle)).value;

void submoduleSetFetchRecurseSubmodules(int repoHandle, String name, int rule) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_submodule_set_fetch_recurse_submodules(
        _repo(repoHandle),
        cName,
        SubmoduleRecurse.fromValue(rule),
      ),
    );
  });
}

void submoduleInit(int handle, {bool overwrite = false}) {
  checkCode(git_submodule_init(_submodule(handle), overwrite ? 1 : 0));
}

void submoduleSync(int handle) {
  checkCode(git_submodule_sync(_submodule(handle)));
}

int submoduleOpen(int handle) {
  return using((arena) {
    final out = arena<Pointer<Repository>>();
    checkCode(git_submodule_open(out, _submodule(handle)));
    return out.value.address;
  });
}

void submoduleReload(int handle, {bool force = false}) {
  checkCode(git_submodule_reload(_submodule(handle), force ? 1 : 0));
}

int submoduleStatus(int repoHandle, String name, int ignore) {
  return using((arena) {
    final out = arena<UnsignedInt>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_submodule_status(
        out,
        _repo(repoHandle),
        cName,
        SubmoduleIgnore.fromValue(ignore),
      ),
    );
    return out.value;
  });
}

int submoduleLocation(int handle) {
  return using((arena) {
    final out = arena<UnsignedInt>();
    checkCode(git_submodule_location(out, _submodule(handle)));
    return out.value;
  });
}

typedef SubmoduleUpdateOptionsRecord = ({
  int checkoutStrategy,
  List<String> checkoutPaths,
  FetchOptionsRecord? fetch,
  bool allowFetch,
});

void submoduleUpdate(
  int handle, {
  bool init = false,
  SubmoduleUpdateOptionsRecord? options,
}) {
  using((arena) {
    final callables = <NativeCallable<dynamic>>[];
    final opts = options == null
        ? nullptr.cast<SubmoduleUpdateOptions>()
        : _allocUpdateOpts(arena, options, callables);
    try {
      checkCode(git_submodule_update(_submodule(handle), init ? 1 : 0, opts));
    } finally {
      for (final cb in callables) {
        cb.close();
      }
    }
  });
}

int submoduleClone(int handle, {SubmoduleUpdateOptionsRecord? options}) {
  return using((arena) {
    final callables = <NativeCallable<dynamic>>[];
    final out = arena<Pointer<Repository>>();
    final opts = options == null
        ? nullptr.cast<SubmoduleUpdateOptions>()
        : _allocUpdateOpts(arena, options, callables);
    try {
      checkCode(git_submodule_clone(out, _submodule(handle), opts));
      return out.value.address;
    } finally {
      for (final cb in callables) {
        cb.close();
      }
    }
  });
}

int submoduleRepoInit(int handle, {bool useGitlink = true}) {
  return using((arena) {
    final out = arena<Pointer<Repository>>();
    checkCode(
      git_submodule_repo_init(out, _submodule(handle), useGitlink ? 1 : 0),
    );
    return out.value.address;
  });
}

Pointer<SubmoduleUpdateOptions> _allocUpdateOpts(
  Allocator arena,
  SubmoduleUpdateOptionsRecord r,
  List<NativeCallable<dynamic>> callables,
) {
  final opts = arena<SubmoduleUpdateOptions>();
  checkCode(
    git_submodule_update_options_init(
      opts,
      GIT_SUBMODULE_UPDATE_OPTIONS_VERSION,
    ),
  );
  writeCheckoutOptionsInto(
    arena,
    opts.ref.checkout_opts,
    strategy: r.checkoutStrategy,
    paths: r.checkoutPaths,
  );
  if (r.fetch != null) {
    writeFetchOptionsInto(arena, opts.ref.fetch_opts, r.fetch!, callables);
  }
  opts.ref.allow_fetch = r.allowFetch ? 1 : 0;
  return opts;
}

Uint8List? _oidOrNull(Pointer<Oid> ptr) {
  if (ptr == nullptr) return null;
  final out = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    out[i] = ptr.ref.id[i];
  }
  return out;
}

Pointer<Submodule> _submodule(int handle) =>
    Pointer<Submodule>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
