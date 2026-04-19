import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'diff.dart' show DiffDeltaRecord;
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show PathspecFlag;

int pathspecNew(List<String> pathspec) {
  return using((arena) {
    final out = arena<Pointer<Pathspec>>();
    final arr = arena<Strarray>();
    final ptrs = arena<Pointer<Char>>(pathspec.length);
    for (var i = 0; i < pathspec.length; i++) {
      ptrs[i] = pathspec[i].toNativeUtf8(allocator: arena).cast<Char>();
    }
    arr.ref.strings = ptrs;
    arr.ref.count = pathspec.length;
    checkCode(git_pathspec_new(out, arr));
    return out.value.address;
  });
}

void pathspecFree(int handle) => git_pathspec_free(_spec(handle));

bool pathspecMatchesPath(int handle, String path, {int flags = 0}) {
  return using((arena) {
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    return git_pathspec_matches_path(_spec(handle), flags, cPath) == 1;
  });
}

int pathspecMatchWorkdir(int repoHandle, int handle, {int flags = 0}) {
  return using((arena) {
    final out = arena<Pointer<PathspecMatchList>>();
    checkCode(
      git_pathspec_match_workdir(out, _repo(repoHandle), flags, _spec(handle)),
    );
    return out.value.address;
  });
}

int pathspecMatchTree(int treeHandle, int handle, {int flags = 0}) {
  return using((arena) {
    final out = arena<Pointer<PathspecMatchList>>();
    checkCode(
      git_pathspec_match_tree(
        out,
        Pointer<Tree>.fromAddress(treeHandle),
        flags,
        _spec(handle),
      ),
    );
    return out.value.address;
  });
}

int pathspecMatchIndex(int indexHandle, int handle, {int flags = 0}) {
  return using((arena) {
    final out = arena<Pointer<PathspecMatchList>>();
    checkCode(
      git_pathspec_match_index(
        out,
        Pointer<Index>.fromAddress(indexHandle),
        flags,
        _spec(handle),
      ),
    );
    return out.value.address;
  });
}

int pathspecMatchDiff(int diffHandle, int handle, {int flags = 0}) {
  return using((arena) {
    final out = arena<Pointer<PathspecMatchList>>();
    checkCode(
      git_pathspec_match_diff(
        out,
        Pointer<Diff>.fromAddress(diffHandle),
        flags,
        _spec(handle),
      ),
    );
    return out.value.address;
  });
}

DiffDeltaRecord? pathspecMatchListDiffEntry(int handle, int index) {
  final ptr = git_pathspec_match_list_diff_entry(_list(handle), index);
  if (ptr == nullptr) return null;
  final d = ptr.ref;
  Uint8List idOf(DiffFile f) {
    final id = Uint8List(20);
    for (var i = 0; i < 20; i++) {
      id[i] = f.id.id[i];
    }
    return id;
  }

  ({int flags, Uint8List id, int idAbbrev, int mode, String path, int size})
  fileOf(DiffFile f) {
    return (
      id: idOf(f),
      path: f.path == nullptr ? '' : f.path.cast<Utf8>().toDartString(),
      size: f.size,
      flags: f.flags,
      mode: f.mode,
      idAbbrev: f.id_abbrev,
    );
  }

  return (
    status: d.statusAsInt,
    flags: d.flags,
    similarity: d.similarity,
    nfiles: d.nfiles,
    oldFile: fileOf(d.old_file),
    newFile: fileOf(d.new_file),
  );
}

void pathspecMatchListFree(int handle) {
  git_pathspec_match_list_free(_list(handle));
}

int pathspecMatchListEntryCount(int handle) {
  return git_pathspec_match_list_entrycount(_list(handle));
}

String? pathspecMatchListEntry(int handle, int index) {
  final ptr = git_pathspec_match_list_entry(_list(handle), index);
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

int pathspecMatchListFailedEntryCount(int handle) {
  return git_pathspec_match_list_failed_entrycount(_list(handle));
}

String? pathspecMatchListFailedEntry(int handle, int index) {
  final ptr = git_pathspec_match_list_failed_entry(_list(handle), index);
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

Pointer<Pathspec> _spec(int handle) => Pointer<Pathspec>.fromAddress(handle);

Pointer<PathspecMatchList> _list(int handle) =>
    Pointer<PathspecMatchList>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
