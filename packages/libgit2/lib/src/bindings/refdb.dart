import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

int refdbNew(int repoHandle) {
  return using((arena) {
    final out = arena<Pointer<Refdb>>();
    checkCode(git_refdb_new(out, _repo(repoHandle)));
    return out.value.address;
  });
}

int refdbOpen(int repoHandle) {
  return using((arena) {
    final out = arena<Pointer<Refdb>>();
    checkCode(git_refdb_open(out, _repo(repoHandle)));
    return out.value.address;
  });
}

int refdbFromRepository(int repoHandle) {
  return using((arena) {
    final out = arena<Pointer<Refdb>>();
    checkCode(git_repository_refdb(out, _repo(repoHandle)));
    return out.value.address;
  });
}

void refdbCompress(int handle) {
  checkCode(git_refdb_compress(_refdb(handle)));
}

void refdbFree(int handle) => git_refdb_free(_refdb(handle));

Pointer<Refdb> _refdb(int handle) => Pointer<Refdb>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
