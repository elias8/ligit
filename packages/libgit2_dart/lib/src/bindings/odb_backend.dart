import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

int odbBackendLoose(
  String objectsDir, {
  int compressionLevel = -1,
  bool doFsync = false,
  int dirMode = 0,
  int fileMode = 0,
}) {
  return using((arena) {
    final out = arena<Pointer<OdbBackend>>();
    final cDir = objectsDir.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_odb_backend_loose(
        out,
        cDir,
        compressionLevel,
        doFsync ? 1 : 0,
        dirMode,
        fileMode,
      ),
    );
    return out.value.address;
  });
}

int odbBackendPack(String objectsDir) {
  return using((arena) {
    final out = arena<Pointer<OdbBackend>>();
    final cDir = objectsDir.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_odb_backend_pack(out, cDir));
    return out.value.address;
  });
}

int odbBackendOnePack(String indexFile) {
  return using((arena) {
    final out = arena<Pointer<OdbBackend>>();
    final cPath = indexFile.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_odb_backend_one_pack(out, cPath));
    return out.value.address;
  });
}
