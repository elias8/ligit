import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'credential_helpers.dart'
    show
        CredentialUserpassPayloadData,
        allocUserpassPayload,
        credentialUserpassAddress;
import 'proxy.dart' show ProxyOptionsRecord, allocProxyOptions;
import 'strarray.dart' show strarrayAlloc, strarrayToList;
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart'
    show Direction, FetchPrune, RemoteAutotagOption;

typedef CertificateCheckRawCb =
    // ignore: avoid_positional_boolean_parameters
    int Function(int certAddress, bool valid, String host);

typedef TransferProgressRecord = ({
  int totalObjects,
  int indexedObjects,
  int receivedObjects,
  int localObjects,
  int totalDeltas,
  int indexedDeltas,
  int receivedBytes,
});

typedef CredentialAcquireRawCb =
    int Function(String url, String? usernameFromUrl, int allowedTypes);

typedef SidebandProgressRawCb = int Function(String message);

typedef TransferProgressRawCb = int Function(TransferProgressRecord stats);

typedef PushTransferProgressRawCb =
    int Function(int current, int total, int bytes);

typedef UpdateRefsRawCb =
    int Function(String refname, Uint8List oldOid, Uint8List newOid);

typedef RemoteCallbacksRecord = ({
  CertificateCheckRawCb? certificateCheck,
  CredentialAcquireRawCb? credentials,
  CredentialUserpassPayloadData? builtinUserpass,
  SidebandProgressRawCb? sidebandProgress,
  TransferProgressRawCb? transferProgress,
  PushTransferProgressRawCb? pushTransferProgress,
  UpdateRefsRawCb? updateRefs,
});

typedef FetchOptionsRecord = ({
  int prune,
  int downloadTags,
  int depth,
  bool updateFetchhead,
  List<String> customHeaders,
  ProxyOptionsRecord? proxy,
  RemoteCallbacksRecord? callbacks,
});

typedef PushOptionsRecord = ({
  int pbParallelism,
  List<String> customHeaders,
  List<String> remotePushOptions,
  ProxyOptionsRecord? proxy,
  RemoteCallbacksRecord? callbacks,
});

typedef RemoteHeadRecord = ({
  bool local,
  Uint8List oid,
  Uint8List loid,
  String name,
  String? symrefTarget,
});

int remoteLookup(int repoHandle, String name) {
  return using((arena) {
    final out = arena<Pointer<Remote>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_remote_lookup(out, _repo(repoHandle), cName));
    return out.value.address;
  });
}

int remoteCreate(int repoHandle, String name, String url) {
  return using((arena) {
    final out = arena<Pointer<Remote>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cUrl = url.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_remote_create(out, _repo(repoHandle), cName, cUrl));
    return out.value.address;
  });
}

int remoteCreateWithFetchspec(
  int repoHandle,
  String name,
  String url,
  String fetchspec,
) {
  return using((arena) {
    final out = arena<Pointer<Remote>>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cUrl = url.toNativeUtf8(allocator: arena).cast<Char>();
    final cSpec = fetchspec.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_remote_create_with_fetchspec(
        out,
        _repo(repoHandle),
        cName,
        cUrl,
        cSpec,
      ),
    );
    return out.value.address;
  });
}

int remoteCreateAnonymous(int repoHandle, String url) {
  return using((arena) {
    final out = arena<Pointer<Remote>>();
    final cUrl = url.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_remote_create_anonymous(out, _repo(repoHandle), cUrl));
    return out.value.address;
  });
}

int remoteCreateDetached(String url) {
  return using((arena) {
    final out = arena<Pointer<Remote>>();
    final cUrl = url.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_remote_create_detached(out, cUrl));
    return out.value.address;
  });
}

void remoteFree(int handle) => git_remote_free(_remote(handle));

String? remoteName(int handle) {
  final ptr = git_remote_name(_remote(handle));
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

String remoteUrl(int handle) {
  final ptr = git_remote_url(_remote(handle));
  if (ptr == nullptr) return '';
  return ptr.cast<Utf8>().toDartString();
}

String? remotePushurl(int handle) {
  final ptr = git_remote_pushurl(_remote(handle));
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

void remoteSetUrl(int repoHandle, String name, String url) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cUrl = url.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_remote_set_url(_repo(repoHandle), cName, cUrl));
  });
}

void remoteSetPushurl(int repoHandle, String name, String url) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cUrl = url.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_remote_set_pushurl(_repo(repoHandle), cName, cUrl));
  });
}

void remoteAddFetch(int repoHandle, String name, String refspec) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cSpec = refspec.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_remote_add_fetch(_repo(repoHandle), cName, cSpec));
  });
}

void remoteAddPush(int repoHandle, String name, String refspec) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final cSpec = refspec.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_remote_add_push(_repo(repoHandle), cName, cSpec));
  });
}

List<String> remoteFetchRefspecs(int handle) {
  return using((arena) {
    final out = arena<Strarray>();
    checkCode(git_remote_get_fetch_refspecs(out, _remote(handle)));
    return strarrayToList(out);
  });
}

List<String> remotePushRefspecs(int handle) {
  return using((arena) {
    final out = arena<Strarray>();
    checkCode(git_remote_get_push_refspecs(out, _remote(handle)));
    return strarrayToList(out);
  });
}

int remoteRefspecCount(int handle) => git_remote_refspec_count(_remote(handle));

int remoteGetRefspec(int handle, int position) =>
    git_remote_get_refspec(_remote(handle), position).address;

void remoteConnect(
  int handle,
  int direction, {
  ProxyOptionsRecord? proxy,
  RemoteCallbacksRecord? callbacks,
}) {
  using((arena) {
    final proxyOpts = proxy == null
        ? nullptr.cast<ProxyOptions>()
        : allocProxyOptions(arena, proxy);
    final cbHolder = _allocCallbacks(arena, callbacks);
    try {
      checkCode(
        git_remote_connect(
          _remote(handle),
          Direction.fromValue(direction),
          cbHolder.ptr,
          proxyOpts,
          nullptr.cast<Strarray>(),
        ),
      );
    } finally {
      cbHolder.close();
    }
  });
}

({Pointer<RemoteCallbacks> ptr, void Function() close}) _allocCallbacks(
  Allocator arena,
  RemoteCallbacksRecord? r,
) {
  final opts = arena<RemoteCallbacks>();
  checkCode(git_remote_init_callbacks(opts, GIT_REMOTE_CALLBACKS_VERSION));
  if (r == null) {
    return (ptr: opts, close: () {});
  }
  final callables = <NativeCallable<dynamic>>[];
  _writeCallbacksInto(arena, r, opts.ref, callables);
  return (
    ptr: opts,
    close: () {
      for (final cb in callables) {
        cb.close();
      }
    },
  );
}

void _writeCallbacksInto(
  Allocator arena,
  RemoteCallbacksRecord r,
  RemoteCallbacks dest,
  List<NativeCallable<dynamic>> callables,
) {
  final certCb = r.certificateCheck;
  if (certCb != null) {
    final callable =
        NativeCallable<
          Int Function(Pointer<Cert>, Int, Pointer<Char>, Pointer<Void>)
        >.isolateLocal((
          Pointer<Cert> cert,
          int valid,
          Pointer<Char> host,
          Pointer<Void> _,
        ) {
          try {
            return certCb(
              cert.address,
              valid != 0,
              host == nullptr ? '' : host.cast<Utf8>().toDartString(),
            );
          } on Object {
            return -1;
          }
        }, exceptionalReturn: -1);
    callables.add(callable);
    dest.certificate_check = callable.nativeFunction.cast();
  }

  final builtin = r.builtinUserpass;
  if (builtin != null) {
    final payload = allocUserpassPayload(arena, builtin);
    dest.credentials = credentialUserpassAddress();
    dest.payload = payload.cast<Void>();
  }

  final credCb = r.credentials;
  if (credCb != null && builtin == null) {
    final callable =
        NativeCallable<
          Int Function(
            Pointer<Pointer<Credential>>,
            Pointer<Char>,
            Pointer<Char>,
            UnsignedInt,
            Pointer<Void>,
          )
        >.isolateLocal((
          Pointer<Pointer<Credential>> out,
          Pointer<Char> url,
          Pointer<Char> user,
          int allowed,
          Pointer<Void> _,
        ) {
          try {
            final handle = credCb(
              url == nullptr ? '' : url.cast<Utf8>().toDartString(),
              user == nullptr ? null : user.cast<Utf8>().toDartString(),
              allowed,
            );
            if (handle == 0) return ErrorCode.passthrough.value;
            out.value = Pointer<Credential>.fromAddress(handle);
            return 0;
          } on Object {
            return -1;
          }
        }, exceptionalReturn: -1);
    callables.add(callable);
    dest.credentials = callable.nativeFunction.cast();
  }

  final sidebandCb = r.sidebandProgress;
  if (sidebandCb != null) {
    final callable =
        NativeCallable<
          Int Function(Pointer<Char>, Int, Pointer<Void>)
        >.isolateLocal((Pointer<Char> str, int len, Pointer<Void> _) {
          try {
            if (str == nullptr || len <= 0) return sidebandCb('');
            final bytes = str.cast<Uint8>();
            final buf = Uint8List(len);
            for (var i = 0; i < len; i++) {
              buf[i] = bytes[i];
            }
            return sidebandCb(String.fromCharCodes(buf));
          } on Object {
            return -1;
          }
        }, exceptionalReturn: -1);
    callables.add(callable);
    dest.sideband_progress = callable.nativeFunction.cast();
  }

  final transferCb = r.transferProgress;
  if (transferCb != null) {
    final callable =
        NativeCallable<
          Int Function(Pointer<IndexerProgress>, Pointer<Void>)
        >.isolateLocal((Pointer<IndexerProgress> stats, Pointer<Void> _) {
          try {
            final s = stats.ref;
            return transferCb((
              totalObjects: s.total_objects,
              indexedObjects: s.indexed_objects,
              receivedObjects: s.received_objects,
              localObjects: s.local_objects,
              totalDeltas: s.total_deltas,
              indexedDeltas: s.indexed_deltas,
              receivedBytes: s.received_bytes,
            ));
          } on Object {
            return -1;
          }
        }, exceptionalReturn: -1);
    callables.add(callable);
    dest.transfer_progress = callable.nativeFunction.cast();
  }

  final pushCb = r.pushTransferProgress;
  if (pushCb != null) {
    final callable =
        NativeCallable<
          Int Function(UnsignedInt, UnsignedInt, Size, Pointer<Void>)
        >.isolateLocal((int current, int total, int bytes, Pointer<Void> _) {
          try {
            return pushCb(current, total, bytes);
          } on Object {
            return -1;
          }
        }, exceptionalReturn: -1);
    callables.add(callable);
    dest.push_transfer_progress = callable.nativeFunction.cast();
  }

  final updateRefsCb = r.updateRefs;
  if (updateRefsCb != null) {
    final callable =
        NativeCallable<
          Int Function(
            Pointer<Char>,
            Pointer<Oid>,
            Pointer<Oid>,
            Pointer<Refspec>,
            Pointer<Void>,
          )
        >.isolateLocal((
          Pointer<Char> refname,
          Pointer<Oid> a,
          Pointer<Oid> b,
          Pointer<Refspec> _,
          Pointer<Void> _,
        ) {
          try {
            return updateRefsCb(
              refname == nullptr ? '' : refname.cast<Utf8>().toDartString(),
              _oidBytes(a),
              _oidBytes(b),
            );
          } on Object {
            return -1;
          }
        }, exceptionalReturn: -1);
    callables.add(callable);
    dest.update_refs = callable.nativeFunction.cast();
  }
}

Uint8List _oidBytes(Pointer<Oid> ptr) {
  final out = Uint8List(20);
  if (ptr == nullptr) return out;
  for (var i = 0; i < 20; i++) {
    out[i] = ptr.ref.id[i];
  }
  return out;
}

bool remoteConnected(int handle) => git_remote_connected(_remote(handle)) == 1;

void remoteStop(int handle) {
  checkCode(git_remote_stop(_remote(handle)));
}

void remoteDisconnect(int handle) {
  checkCode(git_remote_disconnect(_remote(handle)));
}

List<RemoteHeadRecord> remoteLs(int handle) {
  return using((arena) {
    final out = arena<Pointer<Pointer<RemoteHead>>>();
    final size = arena<Size>();
    checkCode(git_remote_ls(out, size, _remote(handle)));
    final count = size.value;
    final arr = out.value;
    final heads = <RemoteHeadRecord>[];
    for (var i = 0; i < count; i++) {
      heads.add(_readHead(arr[i].ref));
    }
    return heads;
  });
}

void remoteFetch(
  int handle, {
  List<String> refspecs = const [],
  FetchOptionsRecord? options,
  String? reflogMessage,
}) {
  using((arena) {
    final specs = strarrayAlloc(arena, refspecs);
    final callables = <NativeCallable<dynamic>>[];
    final opts = options == null
        ? nullptr.cast<FetchOptions>()
        : _allocFetchOpts(arena, options, callables);
    final msg = reflogMessage == null
        ? nullptr.cast<Char>()
        : reflogMessage.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      checkCode(git_remote_fetch(_remote(handle), specs, opts, msg));
    } finally {
      for (final cb in callables) {
        cb.close();
      }
    }
  });
}

void remotePush(
  int handle, {
  List<String> refspecs = const [],
  PushOptionsRecord? options,
}) {
  using((arena) {
    final specs = strarrayAlloc(arena, refspecs);
    final callables = <NativeCallable<dynamic>>[];
    final opts = options == null
        ? nullptr.cast<PushOptions>()
        : _allocPushOpts(arena, options, callables);
    try {
      checkCode(git_remote_push(_remote(handle), specs, opts));
    } finally {
      for (final cb in callables) {
        cb.close();
      }
    }
  });
}

void remotePrune(int handle) {
  checkCode(git_remote_prune(_remote(handle), nullptr.cast<RemoteCallbacks>()));
}

bool remotePruneRefs(int handle) => git_remote_prune_refs(_remote(handle)) == 1;

void remoteUpload(
  int handle, {
  List<String> refspecs = const [],
  PushOptionsRecord? options,
}) {
  using((arena) {
    final specs = strarrayAlloc(arena, refspecs);
    final callables = <NativeCallable<dynamic>>[];
    final opts = options == null
        ? nullptr.cast<PushOptions>()
        : _allocPushOpts(arena, options, callables);
    try {
      checkCode(git_remote_upload(_remote(handle), specs, opts));
    } finally {
      for (final cb in callables) {
        cb.close();
      }
    }
  });
}

void remoteUpdateTips(
  int handle, {
  int updateFlags = 1,
  int downloadTags = 0,
  String? reflogMessage,
}) {
  using((arena) {
    final msg = reflogMessage == null
        ? nullptr.cast<Char>()
        : reflogMessage.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_remote_update_tips(
        _remote(handle),
        nullptr.cast<RemoteCallbacks>(),
        updateFlags,
        RemoteAutotagOption.fromValue(downloadTags),
        msg,
      ),
    );
  });
}

String remoteDefaultBranch(int handle) {
  return using((arena) {
    final buf = arena<Buf>();
    checkCode(git_remote_default_branch(buf, _remote(handle)));
    try {
      return buf.ref.ptr.cast<Utf8>().toDartString();
    } finally {
      git_buf_dispose(buf);
    }
  });
}

List<String> remoteList(int repoHandle) {
  return using((arena) {
    final out = arena<Strarray>();
    checkCode(git_remote_list(out, _repo(repoHandle)));
    return strarrayToList(out);
  });
}

void remoteDelete(int repoHandle, String name) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_remote_delete(_repo(repoHandle), cName));
  });
}

List<String> remoteRename(int repoHandle, String from, String to) {
  return using((arena) {
    final problems = arena<Strarray>();
    final cFrom = from.toNativeUtf8(allocator: arena).cast<Char>();
    final cTo = to.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_remote_rename(problems, _repo(repoHandle), cFrom, cTo));
    return strarrayToList(problems);
  });
}

bool remoteNameIsValid(String name) {
  return using((arena) {
    final out = arena<Int>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_remote_name_is_valid(out, cName));
    return out.value == 1;
  });
}

int remoteAutotag(int handle) => git_remote_autotag(_remote(handle)).value;

void remoteSetAutotag(int repoHandle, String name, int rule) {
  using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_remote_set_autotag(
        _repo(repoHandle),
        cName,
        RemoteAutotagOption.fromValue(rule),
      ),
    );
  });
}

Pointer<FetchOptions> _allocFetchOpts(
  Allocator arena,
  FetchOptionsRecord r,
  List<NativeCallable<dynamic>> callables,
) {
  final opts = arena<FetchOptions>();
  checkCode(git_fetch_options_init(opts, GIT_FETCH_OPTIONS_VERSION));
  writeFetchOptionsInto(arena, opts.ref, r, callables);
  return opts;
}

void writeFetchOptionsInto(
  Allocator arena,
  FetchOptions dest,
  FetchOptionsRecord r,
  List<NativeCallable<dynamic>> callables,
) {
  dest.pruneAsInt = r.prune;
  dest.download_tagsAsInt = r.downloadTags;
  dest.depth = r.depth;
  dest.update_fetchhead = r.updateFetchhead ? 1 : 0;
  if (r.customHeaders.isNotEmpty) {
    final ptrs = arena<Pointer<Char>>(r.customHeaders.length);
    for (var i = 0; i < r.customHeaders.length; i++) {
      ptrs[i] = r.customHeaders[i].toNativeUtf8(allocator: arena).cast<Char>();
    }
    dest.custom_headers.strings = ptrs;
    dest.custom_headers.count = r.customHeaders.length;
  }
  if (r.proxy != null) {
    _copyProxyInto(arena, r.proxy!, dest.proxy_opts);
  }
  if (r.callbacks != null) {
    _writeCallbacksInto(arena, r.callbacks!, dest.callbacks, callables);
  }
}

void _copyProxyInto(Allocator arena, ProxyOptionsRecord r, ProxyOptions dest) {
  dest.version = GIT_PROXY_OPTIONS_VERSION;
  dest.typeAsInt = r.type;
  if (r.url != null) {
    dest.url = r.url!.toNativeUtf8(allocator: arena).cast<Char>();
  }
}

Pointer<PushOptions> _allocPushOpts(
  Allocator arena,
  PushOptionsRecord r,
  List<NativeCallable<dynamic>> callables,
) {
  final opts = arena<PushOptions>();
  checkCode(git_push_options_init(opts, GIT_PUSH_OPTIONS_VERSION));
  opts.ref.pb_parallelism = r.pbParallelism;
  if (r.customHeaders.isNotEmpty) {
    final ptrs = arena<Pointer<Char>>(r.customHeaders.length);
    for (var i = 0; i < r.customHeaders.length; i++) {
      ptrs[i] = r.customHeaders[i].toNativeUtf8(allocator: arena).cast<Char>();
    }
    opts.ref.custom_headers.strings = ptrs;
    opts.ref.custom_headers.count = r.customHeaders.length;
  }
  if (r.remotePushOptions.isNotEmpty) {
    final ptrs = arena<Pointer<Char>>(r.remotePushOptions.length);
    for (var i = 0; i < r.remotePushOptions.length; i++) {
      ptrs[i] = r.remotePushOptions[i]
          .toNativeUtf8(allocator: arena)
          .cast<Char>();
    }
    opts.ref.remote_push_options.strings = ptrs;
    opts.ref.remote_push_options.count = r.remotePushOptions.length;
  }
  if (r.proxy != null) {
    _copyProxyInto(arena, r.proxy!, opts.ref.proxy_opts);
  }
  if (r.callbacks != null) {
    _writeCallbacksInto(arena, r.callbacks!, opts.ref.callbacks, callables);
  }
  return opts;
}

RemoteHeadRecord _readHead(RemoteHead h) {
  final oid = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    oid[i] = h.oid.id[i];
  }
  final loid = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    loid[i] = h.loid.id[i];
  }
  return (
    local: h.local == 1,
    oid: oid,
    loid: loid,
    name: h.name == nullptr ? '' : h.name.cast<Utf8>().toDartString(),
    symrefTarget: h.symref_target == nullptr
        ? null
        : h.symref_target.cast<Utf8>().toDartString(),
  );
}

void remoteCreateOptionsInit(int optsAddress) {
  checkCode(
    git_remote_create_options_init(
      Pointer<RemoteCreateOptions>.fromAddress(optsAddress),
      GIT_REMOTE_CREATE_OPTIONS_VERSION,
    ),
  );
}

void remoteConnectOptionsInit(int optsAddress) {
  checkCode(
    git_remote_connect_options_init(
      Pointer<RemoteConnectOptions>.fromAddress(optsAddress),
      GIT_REMOTE_CONNECT_OPTIONS_VERSION,
    ),
  );
}

int remoteCreateWithOpts(
  String url, {
  int repoHandle = 0,
  String? name,
  int fetchSpecStrategy = 0,
  List<String> fetchSpec = const [],
}) {
  return using((arena) {
    final out = arena<Pointer<Remote>>();
    final cUrl = url.toNativeUtf8(allocator: arena).cast<Char>();
    final opts = arena<RemoteCreateOptions>();
    checkCode(
      git_remote_create_options_init(opts, GIT_REMOTE_CREATE_OPTIONS_VERSION),
    );
    if (repoHandle != 0) {
      opts.ref.repository = Pointer<Repository>.fromAddress(repoHandle);
    }
    if (name != null) {
      opts.ref.name = name.toNativeUtf8(allocator: arena).cast<Char>();
    }
    opts.ref.flags = fetchSpecStrategy;
    if (fetchSpec.isNotEmpty) {
      final ptrs = arena<Pointer<Char>>(fetchSpec.length);
      for (var i = 0; i < fetchSpec.length; i++) {
        ptrs[i] = fetchSpec[i].toNativeUtf8(allocator: arena).cast<Char>();
      }
      opts.ref.fetchspec = ptrs[0];
    }
    checkCode(git_remote_create_with_opts(out, cUrl, opts));
    return out.value.address;
  });
}

void remoteConnectExt(int handle, int direction, int optsAddress) {
  checkCode(
    git_remote_connect_ext(
      _remote(handle),
      Direction.fromValue(direction),
      Pointer<RemoteConnectOptions>.fromAddress(optsAddress),
    ),
  );
}

void remoteDownload(int handle, List<String> refspecs) {
  using((arena) {
    Pointer<Strarray> specs;
    if (refspecs.isEmpty) {
      specs = nullptr.cast();
    } else {
      specs = arena<Strarray>();
      final ptrs = arena<Pointer<Char>>(refspecs.length);
      for (var i = 0; i < refspecs.length; i++) {
        ptrs[i] = refspecs[i].toNativeUtf8(allocator: arena).cast<Char>();
      }
      specs.ref.strings = ptrs;
      specs.ref.count = refspecs.length;
    }
    checkCode(git_remote_download(_remote(handle), specs, nullptr.cast()));
  });
}

int remoteDup(int handle) {
  return using((arena) {
    final out = arena<Pointer<Remote>>();
    checkCode(git_remote_dup(out, _remote(handle)));
    return out.value.address;
  });
}

int remoteOwner(int handle) => git_remote_owner(_remote(handle)).address;

void remoteSetInstanceUrl(int handle, String url) {
  using((arena) {
    final cUrl = url.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_remote_set_instance_url(_remote(handle), cUrl));
  });
}

void remoteSetInstancePushUrl(int handle, String url) {
  using((arena) {
    final cUrl = url.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_remote_set_instance_pushurl(_remote(handle), cUrl));
  });
}

TransferProgressRecord? remoteStats(int handle) {
  final ptr = git_remote_stats(_remote(handle));
  if (ptr == nullptr) return null;
  final s = ptr.ref;
  return (
    totalObjects: s.total_objects,
    indexedObjects: s.indexed_objects,
    receivedObjects: s.received_objects,
    localObjects: s.local_objects,
    totalDeltas: s.total_deltas,
    indexedDeltas: s.indexed_deltas,
    receivedBytes: s.received_bytes,
  );
}

Pointer<Remote> _remote(int handle) => Pointer<Remote>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
