import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show Proxy;

typedef ProxyOptionsRecord = ({int type, String? url});

Pointer<ProxyOptions> allocProxyOptions(
  Allocator arena,
  ProxyOptionsRecord record,
) {
  final opts = arena<ProxyOptions>();
  checkCode(git_proxy_options_init(opts, GIT_PROXY_OPTIONS_VERSION));
  opts.ref.typeAsInt = record.type;
  if (record.url != null) {
    opts.ref.url = record.url!.toNativeUtf8(allocator: arena).cast<Char>();
  }
  return opts;
}
