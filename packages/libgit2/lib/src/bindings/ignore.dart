import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

void ignoreAddRule(int repoHandle, String rules) {
  using((arena) {
    final cRules = rules.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_ignore_add_rule(_repo(repoHandle), cRules));
  });
}

void ignoreClearInternalRules(int repoHandle) {
  checkCode(git_ignore_clear_internal_rules(_repo(repoHandle)));
}

bool ignorePathIsIgnored(int repoHandle, String path) {
  return using((arena) {
    final out = arena<Int>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_ignore_path_is_ignored(out, _repo(repoHandle), cPath));
    return out.value == 1;
  });
}

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
