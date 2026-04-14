import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

const notesDefaultRef = 'refs/notes/commits';

int noteIteratorNew(int repoHandle, {String? notesRef}) {
  return using((arena) {
    final out = arena<Pointer<NoteIterator>>();
    final cRef = notesRef == null
        ? nullptr.cast<Char>()
        : notesRef.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_note_iterator_new(out, _repo(repoHandle), cRef));
    return out.value.address;
  });
}

int noteCommitIteratorNew(int commitHandle) {
  return using((arena) {
    final out = arena<Pointer<NoteIterator>>();
    checkCode(
      git_note_commit_iterator_new(
        out,
        Pointer<Commit>.fromAddress(commitHandle),
      ),
    );
    return out.value.address;
  });
}

void noteIteratorFree(int handle) {
  git_note_iterator_free(_iter(handle));
}

({Uint8List blobId, Uint8List annotatedId})? noteNext(int handle) {
  return using((arena) {
    final blobId = arena<Oid>();
    final annotatedId = arena<Oid>();
    final result = git_note_next(blobId, annotatedId, _iter(handle));
    if (result == ErrorCode.iterover.value) return null;
    checkCode(result);
    return (blobId: _oidBytes(blobId), annotatedId: _oidBytes(annotatedId));
  });
}

int noteRead(int repoHandle, Uint8List annotatedId, {String? notesRef}) {
  return using((arena) {
    final out = arena<Pointer<Note>>();
    final cRef = notesRef == null
        ? nullptr.cast<Char>()
        : notesRef.toNativeUtf8(allocator: arena).cast<Char>();
    final oid = _allocOid(arena, annotatedId);
    checkCode(git_note_read(out, _repo(repoHandle), cRef, oid));
    return out.value.address;
  });
}

int noteCommitRead(int repoHandle, int commitHandle, Uint8List annotatedId) {
  return using((arena) {
    final out = arena<Pointer<Note>>();
    final oid = _allocOid(arena, annotatedId);
    checkCode(
      git_note_commit_read(
        out,
        _repo(repoHandle),
        Pointer<Commit>.fromAddress(commitHandle),
        oid,
      ),
    );
    return out.value.address;
  });
}

int noteAuthor(int handle) => git_note_author(_note(handle)).address;

int noteCommitter(int handle) => git_note_committer(_note(handle)).address;

String noteMessage(int handle) {
  return git_note_message(_note(handle)).cast<Utf8>().toDartString();
}

Uint8List noteId(int handle) => _oidBytes(git_note_id(_note(handle)));

Uint8List noteCreate(
  int repoHandle,
  int authorHandle,
  int committerHandle,
  Uint8List annotatedId,
  String message, {
  String? notesRef,
  bool force = false,
}) {
  return using((arena) {
    final out = arena<Oid>();
    final cRef = notesRef == null
        ? nullptr.cast<Char>()
        : notesRef.toNativeUtf8(allocator: arena).cast<Char>();
    final cMessage = message.toNativeUtf8(allocator: arena).cast<Char>();
    final oid = _allocOid(arena, annotatedId);
    checkCode(
      git_note_create(
        out,
        _repo(repoHandle),
        cRef,
        Pointer<Signature>.fromAddress(authorHandle),
        Pointer<Signature>.fromAddress(committerHandle),
        oid,
        cMessage,
        force ? 1 : 0,
      ),
    );
    return _oidBytes(out);
  });
}

({Uint8List notesCommitId, Uint8List notesBlobId}) noteCommitCreate(
  int repoHandle,
  int? parentCommitHandle,
  int authorHandle,
  int committerHandle,
  Uint8List annotatedId,
  String message, {
  bool allowOverwrite = false,
}) {
  return using((arena) {
    final commitOut = arena<Oid>();
    final blobOut = arena<Oid>();
    final cMessage = message.toNativeUtf8(allocator: arena).cast<Char>();
    final oid = _allocOid(arena, annotatedId);
    checkCode(
      git_note_commit_create(
        commitOut,
        blobOut,
        _repo(repoHandle),
        parentCommitHandle == null
            ? nullptr.cast<Commit>()
            : Pointer<Commit>.fromAddress(parentCommitHandle),
        Pointer<Signature>.fromAddress(authorHandle),
        Pointer<Signature>.fromAddress(committerHandle),
        oid,
        cMessage,
        allowOverwrite ? 1 : 0,
      ),
    );
    return (
      notesCommitId: _oidBytes(commitOut),
      notesBlobId: _oidBytes(blobOut),
    );
  });
}

void noteRemove(
  int repoHandle,
  int authorHandle,
  int committerHandle,
  Uint8List annotatedId, {
  String? notesRef,
}) {
  using((arena) {
    final cRef = notesRef == null
        ? nullptr.cast<Char>()
        : notesRef.toNativeUtf8(allocator: arena).cast<Char>();
    final oid = _allocOid(arena, annotatedId);
    checkCode(
      git_note_remove(
        _repo(repoHandle),
        cRef,
        Pointer<Signature>.fromAddress(authorHandle),
        Pointer<Signature>.fromAddress(committerHandle),
        oid,
      ),
    );
  });
}

Uint8List noteCommitRemove(
  int repoHandle,
  int commitHandle,
  int authorHandle,
  int committerHandle,
  Uint8List annotatedId,
) {
  return using((arena) {
    final out = arena<Oid>();
    final oid = _allocOid(arena, annotatedId);
    checkCode(
      git_note_commit_remove(
        out,
        _repo(repoHandle),
        Pointer<Commit>.fromAddress(commitHandle),
        Pointer<Signature>.fromAddress(authorHandle),
        Pointer<Signature>.fromAddress(committerHandle),
        oid,
      ),
    );
    return _oidBytes(out);
  });
}

void noteFree(int handle) => git_note_free(_note(handle));

String noteDefaultRef(int repoHandle) {
  return using((arena) {
    final buf = arena<Buf>();
    try {
      checkCode(git_note_default_ref(buf, _repo(repoHandle)));
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

int noteForeach(
  int repoHandle,
  int Function(Uint8List noteId, Uint8List annotatedId) callback, {
  String? notesRef,
}) {
  return using((arena) {
    final cRef = notesRef == null
        ? nullptr.cast<Char>()
        : notesRef.toNativeUtf8(allocator: arena).cast<Char>();
    final cb =
        NativeCallable<
          Int Function(Pointer<Oid>, Pointer<Oid>, Pointer<Void>)
        >.isolateLocal((
          Pointer<Oid> blob,
          Pointer<Oid> annotated,
          Pointer<Void> _,
        ) {
          try {
            return callback(_oidBytes(blob), _oidBytes(annotated));
          } on Object {
            return -1;
          }
        }, exceptionalReturn: -1);
    try {
      final code = git_note_foreach(
        _repo(repoHandle),
        cRef,
        cb.nativeFunction.cast(),
        nullptr.cast(),
      );
      if (code < 0) checkCode(code);
      return code;
    } finally {
      cb.close();
    }
  });
}

Pointer<Note> _note(int handle) => Pointer<Note>.fromAddress(handle);

Pointer<NoteIterator> _iter(int handle) =>
    Pointer<NoteIterator>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);

Pointer<Oid> _allocOid(Allocator arena, Uint8List bytes) {
  final out = arena<Oid>();
  for (var i = 0; i < bytes.length; i++) {
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
