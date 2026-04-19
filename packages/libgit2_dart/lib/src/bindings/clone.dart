import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show CloneLocal;

int clone(
  String url,
  String localPath, {
  bool bare = false,
  int local = 0,
  String? checkoutBranch,
  int checkoutStrategy = 0,
  List<String> checkoutPaths = const [],
}) {
  return using((arena) {
    final out = arena<Pointer<Repository>>();
    final cUrl = url.toNativeUtf8(allocator: arena).cast<Char>();
    final cPath = localPath.toNativeUtf8(allocator: arena).cast<Char>();
    final opts = arena<CloneOptions>();
    checkCode(git_clone_options_init(opts, GIT_CLONE_OPTIONS_VERSION));
    opts.ref.bare = bare ? 1 : 0;
    opts.ref.localAsInt = local;
    if (checkoutBranch != null) {
      opts.ref.checkout_branch = checkoutBranch
          .toNativeUtf8(allocator: arena)
          .cast<Char>();
    }
    opts.ref.checkout_opts.checkout_strategy = checkoutStrategy;
    if (checkoutPaths.isNotEmpty) {
      final ptrs = arena<Pointer<Char>>(checkoutPaths.length);
      for (var i = 0; i < checkoutPaths.length; i++) {
        ptrs[i] = checkoutPaths[i].toNativeUtf8(allocator: arena).cast<Char>();
      }
      opts.ref.checkout_opts.paths.strings = ptrs;
      opts.ref.checkout_opts.paths.count = checkoutPaths.length;
    }
    checkCode(git_clone(out, cUrl, cPath, opts));
    return out.value.address;
  });
}
