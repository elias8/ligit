import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show Filemode;

int treeLookup(int repoHandle, Uint8List oidBytes) {
  return using((arena) {
    final out = arena<Pointer<Tree>>();
    final oid = _allocOid(arena, oidBytes);
    checkCode(git_tree_lookup(out, _repo(repoHandle), oid));
    return out.value.address;
  });
}

int treeLookupPrefix(int repoHandle, Uint8List oidBytes, int prefixLength) {
  return using((arena) {
    final out = arena<Pointer<Tree>>();
    final oid = _allocOid(arena, oidBytes);
    checkCode(
      git_tree_lookup_prefix(out, _repo(repoHandle), oid, prefixLength),
    );
    return out.value.address;
  });
}

void treeFree(int handle) => git_tree_free(_tree(handle));

Uint8List treeId(int handle) => _oidBytes(git_tree_id(_tree(handle)));

int treeOwner(int handle) => git_tree_owner(_tree(handle)).address;

int treeEntryCount(int handle) => git_tree_entrycount(_tree(handle));

int treeEntryByName(int treeHandle, String name) {
  return using((arena) {
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    final ptr = git_tree_entry_byname(_tree(treeHandle), cName);
    if (ptr == nullptr) return 0;
    return ptr.address;
  });
}

int treeEntryByIndex(int treeHandle, int index) {
  final ptr = git_tree_entry_byindex(_tree(treeHandle), index);
  if (ptr == nullptr) return 0;
  return ptr.address;
}

int treeEntryById(int treeHandle, Uint8List oidBytes) {
  return using((arena) {
    final oid = _allocOid(arena, oidBytes);
    final ptr = git_tree_entry_byid(_tree(treeHandle), oid);
    if (ptr == nullptr) return 0;
    return ptr.address;
  });
}

int treeEntryByPath(int treeHandle, String path) {
  return using((arena) {
    final out = arena<Pointer<TreeEntry>>();
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final result = git_tree_entry_bypath(out, _tree(treeHandle), cPath);
    if (result == ErrorCode.enotfound.value) return 0;
    checkCode(result);
    return out.value.address;
  });
}

int treeEntryDup(int borrowedHandle) {
  return using((arena) {
    final out = arena<Pointer<TreeEntry>>();
    checkCode(git_tree_entry_dup(out, _treeEntry(borrowedHandle)));
    return out.value.address;
  });
}

void treeEntryFree(int handle) => git_tree_entry_free(_treeEntry(handle));

String treeEntryName(int handle) {
  final ptr = git_tree_entry_name(_treeEntry(handle));
  return ptr.cast<Utf8>().toDartString();
}

Uint8List treeEntryId(int handle) =>
    _oidBytes(git_tree_entry_id(_treeEntry(handle)));

ObjectT treeEntryType(int handle) => git_tree_entry_type(_treeEntry(handle));

Filemode treeEntryFileMode(int handle) =>
    git_tree_entry_filemode(_treeEntry(handle));

int treeEntryFileModeRaw(int handle) =>
    git_tree_entry_filemode_raw(_treeEntry(handle)).value;

int treeEntryCmp(int aHandle, int bHandle) =>
    git_tree_entry_cmp(_treeEntry(aHandle), _treeEntry(bHandle));

int treeEntryToObject(int repoHandle, int entryHandle) {
  return using((arena) {
    final out = arena<Pointer<Object>>();
    checkCode(
      git_tree_entry_to_object(out, _repo(repoHandle), _treeEntry(entryHandle)),
    );
    return out.value.address;
  });
}

int treeDup(int handle) {
  return using((arena) {
    final out = arena<Pointer<Tree>>();
    checkCode(git_tree_dup(out, _tree(handle)));
    return out.value.address;
  });
}

const treeWalkPre = 0;

const treeWalkPost = 1;

typedef TreeUpdateRecord = ({
  int action,
  Uint8List oid,
  int filemode,
  String path,
});

int treeWalk(
  int handle,
  int mode,
  int Function(String root, int entryHandle) callback,
) {
  final cb =
      NativeCallable<
        Int Function(Pointer<Char>, Pointer<TreeEntry>, Pointer<Void>)
      >.isolateLocal((
        Pointer<Char> root,
        Pointer<TreeEntry> entry,
        Pointer<Void> _,
      ) {
        try {
          return callback(
            root == nullptr ? '' : root.cast<Utf8>().toDartString(),
            entry.address,
          );
        } on Object {
          return -1;
        }
      }, exceptionalReturn: -1);
  try {
    final code = git_tree_walk(
      _tree(handle),
      TreewalkMode.fromValue(mode),
      cb.nativeFunction.cast(),
      nullptr,
    );
    if (code < 0) checkCode(code);
    return code;
  } finally {
    cb.close();
  }
}

Uint8List treeCreateUpdated(
  int repoHandle,
  int baselineHandle,
  List<TreeUpdateRecord> updates,
) {
  return using((arena) {
    final out = arena<Oid>();
    final count = updates.length;
    final array = arena<TreeUpdate>(count);
    for (var i = 0; i < count; i++) {
      final u = updates[i];
      final slot = (array + i).ref;
      slot.actionAsInt = u.action;
      for (var j = 0; j < 20; j++) {
        slot.id.id[j] = j < u.oid.length ? u.oid[j] : 0;
      }
      slot.filemodeAsInt = u.filemode;
      slot.path = u.path.toNativeUtf8(allocator: arena).cast<Char>();
    }
    checkCode(
      git_tree_create_updated(
        out,
        _repo(repoHandle),
        _tree(baselineHandle),
        count,
        array,
      ),
    );
    return _oidBytes(out);
  });
}

int treebuilderNew(int repoHandle, {int sourceHandle = 0}) {
  return using((arena) {
    final out = arena<Pointer<Treebuilder>>();
    checkCode(
      git_treebuilder_new(
        out,
        _repo(repoHandle),
        sourceHandle == 0
            ? nullptr.cast<Tree>()
            : Pointer<Tree>.fromAddress(sourceHandle),
      ),
    );
    return out.value.address;
  });
}

void treebuilderFree(int handle) => git_treebuilder_free(_builder(handle));

void treebuilderClear(int handle) {
  checkCode(git_treebuilder_clear(_builder(handle)));
}

int treebuilderEntryCount(int handle) =>
    git_treebuilder_entrycount(_builder(handle));

int treebuilderGet(int handle, String filename) {
  return using((arena) {
    final cName = filename.toNativeUtf8(allocator: arena).cast<Char>();
    final ptr = git_treebuilder_get(_builder(handle), cName);
    return ptr.address;
  });
}

void treebuilderInsert(
  int handle,
  String filename,
  Uint8List oid,
  int filemode,
) {
  using((arena) {
    final cName = filename.toNativeUtf8(allocator: arena).cast<Char>();
    final id = _allocOid(arena, oid);
    final out = arena<Pointer<TreeEntry>>();
    checkCode(
      git_treebuilder_insert(
        out,
        _builder(handle),
        cName,
        id,
        Filemode.fromValue(filemode),
      ),
    );
  });
}

void treebuilderRemove(int handle, String filename) {
  using((arena) {
    final cName = filename.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_treebuilder_remove(_builder(handle), cName));
  });
}

void treebuilderFilter(int handle, int Function(int entryHandle) filter) {
  final cb =
      NativeCallable<
        Int Function(Pointer<TreeEntry>, Pointer<Void>)
      >.isolateLocal((Pointer<TreeEntry> entry, Pointer<Void> _) {
        try {
          return filter(entry.address);
        } on Object {
          return -1;
        }
      }, exceptionalReturn: -1);
  try {
    checkCode(
      git_treebuilder_filter(
        _builder(handle),
        cb.nativeFunction.cast(),
        nullptr,
      ),
    );
  } finally {
    cb.close();
  }
}

Uint8List treebuilderWrite(int handle) {
  return using((arena) {
    final out = arena<Oid>();
    checkCode(git_treebuilder_write(out, _builder(handle)));
    return _oidBytes(out);
  });
}

Pointer<Tree> _tree(int handle) => Pointer<Tree>.fromAddress(handle);

Pointer<Treebuilder> _builder(int handle) =>
    Pointer<Treebuilder>.fromAddress(handle);

Pointer<TreeEntry> _treeEntry(int handle) {
  return Pointer<TreeEntry>.fromAddress(handle);
}

Pointer<Repository> _repo(int handle) {
  return Pointer<Repository>.fromAddress(handle);
}

Pointer<Oid> _allocOid(Allocator arena, Uint8List bytes) {
  final out = arena<Oid>();
  for (var i = 0; i < 20; i++) {
    out.ref.id[i] = bytes[i];
  }
  return out;
}

Uint8List _oidBytes(Pointer<Oid> ptr) {
  final out = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    out[i] = ptr.ref.id[i];
  }
  return out;
}
