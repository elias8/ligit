import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

void cherryPick(int repoHandle, int commitHandle, {int mainline = 0}) {
  using((arena) {
    final opts = arena<CherrypickOptions>();
    checkCode(
      git_cherrypick_options_init(opts, GIT_CHERRYPICK_OPTIONS_VERSION),
    );
    opts.ref.mainline = mainline;
    checkCode(
      git_cherrypick(
        _repo(repoHandle),
        Pointer<Commit>.fromAddress(commitHandle),
        opts,
      ),
    );
  });
}

int cherryPickCommit(
  int repoHandle,
  int commitHandle,
  int ourCommitHandle, {
  int mainline = 0,
}) {
  return using((arena) {
    final out = arena<Pointer<Index>>();
    checkCode(
      git_cherrypick_commit(
        out,
        _repo(repoHandle),
        Pointer<Commit>.fromAddress(commitHandle),
        Pointer<Commit>.fromAddress(ourCommitHandle),
        mainline,
        nullptr.cast<MergeOptions>(),
      ),
    );
    return out.value.address;
  });
}

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
