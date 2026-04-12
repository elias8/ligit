import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart'
    show IndexAddOption, IndexCapability, IndexStage;

const indexEntryNameMask = GIT_INDEX_ENTRY_NAMEMASK;

const indexEntryStageMask = GIT_INDEX_ENTRY_STAGEMASK;

const indexEntryStageShift = GIT_INDEX_ENTRY_STAGESHIFT;

const indexEntryExtended = 0x4000;

const indexEntryValid = 0x8000;

const indexEntryIntentToAdd = 1 << 13;

const indexEntrySkipWorktree = 1 << 14;

const indexEntryUpToDate = 1 << 2;

typedef IndexEntryRecord = ({
  int ctimeSeconds,
  int ctimeNanoseconds,
  int mtimeSeconds,
  int mtimeNanoseconds,
  int dev,
  int ino,
  int mode,
  int uid,
  int gid,
  int fileSize,
  Uint8List id,
  int flags,
  int flagsExtended,
  String path,
});

int indexNew() {
  return using((arena) {
    final out = arena<Pointer<Index>>();
    checkCode(git_index_new(out));
    return out.value.address;
  });
}

int indexOpen(String indexPath) {
  return using((arena) {
    final out = arena<Pointer<Index>>();
    final cPath = indexPath.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_index_open(out, cPath));
    return out.value.address;
  });
}

int indexFromRepository(int repoHandle) {
  return using((arena) {
    final out = arena<Pointer<Index>>();
    checkCode(git_repository_index(out, _repo(repoHandle)));
    return out.value.address;
  });
}

void indexFree(int handle) => git_index_free(_index(handle));

int indexOwner(int handle) => git_index_owner(_index(handle)).address;

int indexCaps(int handle) => git_index_caps(_index(handle));

void indexSetCaps(int handle, int caps) {
  checkCode(git_index_set_caps(_index(handle), caps));
}

int indexVersion(int handle) => git_index_version(_index(handle));

void indexSetVersion(int handle, int version) {
  checkCode(git_index_set_version(_index(handle), version));
}

void indexRead(int handle, {bool force = false}) {
  checkCode(git_index_read(_index(handle), force ? 1 : 0));
}

void indexWrite(int handle) {
  checkCode(git_index_write(_index(handle)));
}

String? indexPath(int handle) {
  final ptr = git_index_path(_index(handle));
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

Uint8List indexChecksum(int handle) =>
    _oidBytes(git_index_checksum(_index(handle)));

void indexReadTree(int handle, int treeHandle) {
  checkCode(git_index_read_tree(_index(handle), _tree(treeHandle)));
}

Uint8List indexWriteTree(int handle) {
  return using((arena) {
    final out = arena<Oid>();
    checkCode(git_index_write_tree(out, _index(handle)));
    return _oidBytes(out);
  });
}

Uint8List indexWriteTreeTo(int handle, int repoHandle) {
  return using((arena) {
    final out = arena<Oid>();
    checkCode(git_index_write_tree_to(out, _index(handle), _repo(repoHandle)));
    return _oidBytes(out);
  });
}

int indexEntryCount(int handle) => git_index_entrycount(_index(handle));

void indexClear(int handle) {
  checkCode(git_index_clear(_index(handle)));
}

IndexEntryRecord? indexGetByIndex(int handle, int position) {
  final ptr = git_index_get_byindex(_index(handle), position);
  if (ptr == nullptr) return null;
  return _entry(ptr);
}

IndexEntryRecord? indexGetByPath(int handle, String path, int stage) {
  return using((arena) {
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final ptr = git_index_get_bypath(_index(handle), cPath, stage);
    if (ptr == nullptr) return null;
    return _entry(ptr);
  });
}

void indexRemove(int handle, String path, int stage) {
  using((arena) {
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_index_remove(_index(handle), cPath, stage));
  });
}

void indexRemoveDirectory(int handle, String directory, int stage) {
  using((arena) {
    final cDir = directory.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_index_remove_directory(_index(handle), cDir, stage));
  });
}

void indexAdd(int handle, IndexEntryRecord entry) {
  using((arena) {
    final native = _allocEntry(arena, entry);
    checkCode(git_index_add(_index(handle), native));
  });
}

void indexAddByPath(int handle, String path) {
  using((arena) {
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_index_add_bypath(_index(handle), cPath));
  });
}

void indexAddFromBuffer(int handle, IndexEntryRecord entry, Uint8List buffer) {
  using((arena) {
    final native = _allocEntry(arena, entry);
    final data = arena<Uint8>(buffer.length);
    for (var i = 0; i < buffer.length; i++) {
      data[i] = buffer[i];
    }
    checkCode(
      git_index_add_from_buffer(
        _index(handle),
        native,
        data.cast<Void>(),
        buffer.length,
      ),
    );
  });
}

void indexRemoveByPath(int handle, String path) {
  using((arena) {
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_index_remove_bypath(_index(handle), cPath));
  });
}

void indexAddAll(
  int handle,
  List<String> pathSpecs, {
  int flags = 0,
  int Function(String path, String matchedPathspec)? onMatch,
}) {
  _runMatched(
    (arr, cb) =>
        git_index_add_all(_index(handle), arr, flags, cb, nullptr.cast()),
    pathSpecs,
    onMatch,
  );
}

void indexRemoveAll(
  int handle,
  List<String> pathSpecs, {
  int Function(String path, String matchedPathspec)? onMatch,
}) {
  _runMatched(
    (arr, cb) => git_index_remove_all(_index(handle), arr, cb, nullptr.cast()),
    pathSpecs,
    onMatch,
  );
}

void indexUpdateAll(
  int handle,
  List<String> pathSpecs, {
  int Function(String path, String matchedPathspec)? onMatch,
}) {
  _runMatched(
    (arr, cb) => git_index_update_all(_index(handle), arr, cb, nullptr.cast()),
    pathSpecs,
    onMatch,
  );
}

int? indexFind(int handle, String path) {
  return using((arena) {
    final out = arena<Size>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final result = git_index_find(out, _index(handle), cPath);
    if (result == ErrorCode.enotfound.value) return null;
    checkCode(result);
    return out.value;
  });
}

int? indexFindPrefix(int handle, String prefix) {
  return using((arena) {
    final out = arena<Size>();
    final cPrefix = prefix.toNativeUtf8(allocator: arena).cast<Char>();
    final result = git_index_find_prefix(out, _index(handle), cPrefix);
    if (result == ErrorCode.enotfound.value) return null;
    checkCode(result);
    return out.value;
  });
}

int indexEntryStage(int flags) {
  return using((arena) {
    final entry = arena<IndexEntry>();
    entry.ref.flags = flags;
    return git_index_entry_stage(entry);
  });
}

bool indexEntryIsConflict(int flags) {
  return using((arena) {
    final entry = arena<IndexEntry>();
    entry.ref.flags = flags;
    return git_index_entry_is_conflict(entry) == 1;
  });
}

void indexConflictAdd(
  int handle, {
  IndexEntryRecord? ancestor,
  IndexEntryRecord? ours,
  IndexEntryRecord? theirs,
}) {
  using((arena) {
    final a = ancestor == null
        ? nullptr.cast<IndexEntry>()
        : _allocEntry(arena, ancestor);
    final o = ours == null
        ? nullptr.cast<IndexEntry>()
        : _allocEntry(arena, ours);
    final t = theirs == null
        ? nullptr.cast<IndexEntry>()
        : _allocEntry(arena, theirs);
    checkCode(git_index_conflict_add(_index(handle), a, o, t));
  });
}

typedef IndexConflictRecord = ({
  IndexEntryRecord? ancestor,
  IndexEntryRecord? ours,
  IndexEntryRecord? theirs,
});

IndexConflictRecord? indexConflictGet(int handle, String path) {
  return using((arena) {
    final ancestor = arena<Pointer<IndexEntry>>();
    final ours = arena<Pointer<IndexEntry>>();
    final theirs = arena<Pointer<IndexEntry>>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final result = git_index_conflict_get(
      ancestor,
      ours,
      theirs,
      _index(handle),
      cPath,
    );
    if (result == ErrorCode.enotfound.value) return null;
    checkCode(result);
    return (
      ancestor: ancestor.value == nullptr ? null : _entry(ancestor.value),
      ours: ours.value == nullptr ? null : _entry(ours.value),
      theirs: theirs.value == nullptr ? null : _entry(theirs.value),
    );
  });
}

void indexConflictRemove(int handle, String path) {
  using((arena) {
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_index_conflict_remove(_index(handle), cPath));
  });
}

void indexConflictCleanup(int handle) {
  checkCode(git_index_conflict_cleanup(_index(handle)));
}

bool indexHasConflicts(int handle) =>
    git_index_has_conflicts(_index(handle)) == 1;

int indexIteratorNew(int handle) {
  return using((arena) {
    final out = arena<Pointer<IndexIterator>>();
    checkCode(git_index_iterator_new(out, _index(handle)));
    return out.value.address;
  });
}

IndexEntryRecord? indexIteratorNext(int handle) {
  return using((arena) {
    final out = arena<Pointer<IndexEntry>>();
    final result = git_index_iterator_next(
      out,
      Pointer<IndexIterator>.fromAddress(handle),
    );
    if (result == ErrorCode.iterover.value) return null;
    checkCode(result);
    return _entry(out.value);
  });
}

void indexIteratorFree(int handle) =>
    git_index_iterator_free(Pointer<IndexIterator>.fromAddress(handle));

int indexConflictIteratorNew(int handle) {
  return using((arena) {
    final out = arena<Pointer<IndexConflictIterator>>();
    checkCode(git_index_conflict_iterator_new(out, _index(handle)));
    return out.value.address;
  });
}

IndexConflictRecord? indexConflictIteratorNext(int handle) {
  return using((arena) {
    final ancestor = arena<Pointer<IndexEntry>>();
    final ours = arena<Pointer<IndexEntry>>();
    final theirs = arena<Pointer<IndexEntry>>();
    final result = git_index_conflict_next(
      ancestor,
      ours,
      theirs,
      Pointer<IndexConflictIterator>.fromAddress(handle),
    );
    if (result == ErrorCode.iterover.value) return null;
    checkCode(result);
    return (
      ancestor: ancestor.value == nullptr ? null : _entry(ancestor.value),
      ours: ours.value == nullptr ? null : _entry(ours.value),
      theirs: theirs.value == nullptr ? null : _entry(theirs.value),
    );
  });
}

void indexConflictIteratorFree(int handle) => git_index_conflict_iterator_free(
  Pointer<IndexConflictIterator>.fromAddress(handle),
);

void _runMatched(
  int Function(Pointer<Strarray>, IndexMatchedPathCb) call,
  List<String> pathSpecs,
  int Function(String path, String matchedPathspec)? onMatch,
) {
  using((arena) {
    final arr = arena<Strarray>();
    final ptrs = arena<Pointer<Char>>(pathSpecs.length);
    for (var i = 0; i < pathSpecs.length; i++) {
      ptrs[i] = pathSpecs[i].toNativeUtf8(allocator: arena).cast<Char>();
    }
    arr.ref.strings = ptrs;
    arr.ref.count = pathSpecs.length;

    NativeCallable<Int Function(Pointer<Char>, Pointer<Char>, Pointer<Void>)>?
    callable;
    var cb = nullptr
        .cast<
          NativeFunction<
            Int Function(Pointer<Char>, Pointer<Char>, Pointer<Void>)
          >
        >();
    if (onMatch != null) {
      int trampoline(
        Pointer<Char> path,
        Pointer<Char> matched,
        Pointer<Void> payload,
      ) {
        try {
          return onMatch(
            path.cast<Utf8>().toDartString(),
            matched == nullptr ? '' : matched.cast<Utf8>().toDartString(),
          );
        } on Object {
          return -1;
        }
      }

      callable =
          NativeCallable<
            Int Function(Pointer<Char>, Pointer<Char>, Pointer<Void>)
          >.isolateLocal(trampoline, exceptionalReturn: -1);
      cb = callable.nativeFunction;
    }
    try {
      checkCode(call(arr, cb));
    } finally {
      callable?.close();
    }
  });
}

Pointer<IndexEntry> _allocEntry(Allocator arena, IndexEntryRecord r) {
  final e = arena<IndexEntry>();
  e.ref.ctime.seconds = r.ctimeSeconds;
  e.ref.ctime.nanoseconds = r.ctimeNanoseconds;
  e.ref.mtime.seconds = r.mtimeSeconds;
  e.ref.mtime.nanoseconds = r.mtimeNanoseconds;
  e.ref.dev = r.dev;
  e.ref.ino = r.ino;
  e.ref.mode = r.mode;
  e.ref.uid = r.uid;
  e.ref.gid = r.gid;
  e.ref.file_size = r.fileSize;
  for (var i = 0; i < 20; i++) {
    e.ref.id.id[i] = r.id[i];
  }
  e.ref.flags = r.flags;
  e.ref.flags_extended = r.flagsExtended;
  e.ref.path = r.path.toNativeUtf8(allocator: arena).cast<Char>();
  return e;
}

IndexEntryRecord _entry(Pointer<IndexEntry> ptr) {
  final e = ptr.ref;
  final id = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    id[i] = e.id.id[i];
  }
  return (
    ctimeSeconds: e.ctime.seconds,
    ctimeNanoseconds: e.ctime.nanoseconds,
    mtimeSeconds: e.mtime.seconds,
    mtimeNanoseconds: e.mtime.nanoseconds,
    dev: e.dev,
    ino: e.ino,
    mode: e.mode,
    uid: e.uid,
    gid: e.gid,
    fileSize: e.file_size,
    id: id,
    flags: e.flags,
    flagsExtended: e.flags_extended,
    path: e.path == nullptr ? '' : e.path.cast<Utf8>().toDartString(),
  );
}

Uint8List _oidBytes(Pointer<Oid> ptr) {
  final out = Uint8List(20);
  if (ptr == nullptr) return out;
  for (var i = 0; i < 20; i++) {
    out[i] = ptr.ref.id[i];
  }
  return out;
}

Pointer<Index> _index(int handle) => Pointer<Index>.fromAddress(handle);

Pointer<Tree> _tree(int handle) => Pointer<Tree>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
