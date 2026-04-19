import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show CheckoutNotify, CheckoutStrategy;

void checkoutHead(
  int repoHandle, {
  int strategy = 0,
  int? baselineTreeHandle,
  List<String> paths = const [],
  String? targetDirectory,
  String? ancestorLabel,
  String? ourLabel,
  String? theirLabel,
  int dirMode = 0,
  int fileMode = 0,
  bool disableFilters = false,
}) {
  using((arena) {
    final opts = _writeOpts(
      arena,
      strategy: strategy,
      baselineTreeHandle: baselineTreeHandle,
      paths: paths,
      targetDirectory: targetDirectory,
      ancestorLabel: ancestorLabel,
      ourLabel: ourLabel,
      theirLabel: theirLabel,
      dirMode: dirMode,
      fileMode: fileMode,
      disableFilters: disableFilters,
    );
    checkCode(git_checkout_head(_repo(repoHandle), opts));
  });
}

void checkoutTree(
  int repoHandle,
  int treeishHandle, {
  int strategy = 0,
  int? baselineTreeHandle,
  List<String> paths = const [],
  String? targetDirectory,
  String? ancestorLabel,
  String? ourLabel,
  String? theirLabel,
  int dirMode = 0,
  int fileMode = 0,
  bool disableFilters = false,
}) {
  using((arena) {
    final opts = _writeOpts(
      arena,
      strategy: strategy,
      baselineTreeHandle: baselineTreeHandle,
      paths: paths,
      targetDirectory: targetDirectory,
      ancestorLabel: ancestorLabel,
      ourLabel: ourLabel,
      theirLabel: theirLabel,
      dirMode: dirMode,
      fileMode: fileMode,
      disableFilters: disableFilters,
    );
    checkCode(
      git_checkout_tree(
        _repo(repoHandle),
        treeishHandle == 0
            ? nullptr.cast<Object>()
            : Pointer<Object>.fromAddress(treeishHandle),
        opts,
      ),
    );
  });
}

void checkoutIndex(
  int repoHandle, {
  int indexHandle = 0,
  int strategy = 0,
  int? baselineTreeHandle,
  List<String> paths = const [],
  String? targetDirectory,
  String? ancestorLabel,
  String? ourLabel,
  String? theirLabel,
  int dirMode = 0,
  int fileMode = 0,
  bool disableFilters = false,
}) {
  using((arena) {
    final opts = _writeOpts(
      arena,
      strategy: strategy,
      baselineTreeHandle: baselineTreeHandle,
      paths: paths,
      targetDirectory: targetDirectory,
      ancestorLabel: ancestorLabel,
      ourLabel: ourLabel,
      theirLabel: theirLabel,
      dirMode: dirMode,
      fileMode: fileMode,
      disableFilters: disableFilters,
    );
    checkCode(
      git_checkout_index(
        _repo(repoHandle),
        indexHandle == 0
            ? nullptr.cast<Index>()
            : Pointer<Index>.fromAddress(indexHandle),
        opts,
      ),
    );
  });
}

Pointer<CheckoutOptions> _writeOpts(
  Arena arena, {
  required int strategy,
  required int? baselineTreeHandle,
  required List<String> paths,
  required String? targetDirectory,
  required String? ancestorLabel,
  required String? ourLabel,
  required String? theirLabel,
  required int dirMode,
  required int fileMode,
  required bool disableFilters,
}) {
  final opts = arena<CheckoutOptions>();
  checkCode(git_checkout_options_init(opts, GIT_CHECKOUT_OPTIONS_VERSION));
  writeCheckoutOptionsInto(
    arena,
    opts.ref,
    strategy: strategy,
    baselineTreeHandle: baselineTreeHandle,
    paths: paths,
    targetDirectory: targetDirectory,
    ancestorLabel: ancestorLabel,
    ourLabel: ourLabel,
    theirLabel: theirLabel,
    dirMode: dirMode,
    fileMode: fileMode,
    disableFilters: disableFilters,
  );
  return opts;
}

void writeCheckoutOptionsInto(
  Allocator arena,
  CheckoutOptions dest, {
  int strategy = 0,
  int? baselineTreeHandle,
  List<String> paths = const [],
  String? targetDirectory,
  String? ancestorLabel,
  String? ourLabel,
  String? theirLabel,
  int dirMode = 0,
  int fileMode = 0,
  bool disableFilters = false,
}) {
  dest.checkout_strategy = strategy;
  dest.dir_mode = dirMode;
  dest.file_mode = fileMode;
  dest.disable_filters = disableFilters ? 1 : 0;
  if (baselineTreeHandle != null) {
    dest.baseline = Pointer<Tree>.fromAddress(baselineTreeHandle);
  }
  if (paths.isNotEmpty) {
    final ptrs = arena<Pointer<Char>>(paths.length);
    for (var i = 0; i < paths.length; i++) {
      ptrs[i] = paths[i].toNativeUtf8(allocator: arena).cast<Char>();
    }
    dest.paths.strings = ptrs;
    dest.paths.count = paths.length;
  }
  if (targetDirectory != null) {
    dest.target_directory = targetDirectory
        .toNativeUtf8(allocator: arena)
        .cast<Char>();
  }
  if (ancestorLabel != null) {
    dest.ancestor_label = ancestorLabel
        .toNativeUtf8(allocator: arena)
        .cast<Char>();
  }
  if (ourLabel != null) {
    dest.our_label = ourLabel.toNativeUtf8(allocator: arena).cast<Char>();
  }
  if (theirLabel != null) {
    dest.their_label = theirLabel.toNativeUtf8(allocator: arena).cast<Char>();
  }
}

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
