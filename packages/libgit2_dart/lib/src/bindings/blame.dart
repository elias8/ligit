import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show BlameFlag;

int blameFile(
  int repoHandle,
  String path, {
  int flags = 0,
  int minMatchCharacters = 0,
  Uint8List? newestCommit,
  Uint8List? oldestCommit,
  int minLine = 0,
  int maxLine = 0,
}) {
  return using((arena) {
    final out = arena<Pointer<Blame>>();
    final opts = arena<BlameOptions>();
    _initBlameOptions(
      opts,
      flags: flags,
      minMatchCharacters: minMatchCharacters,
      newestCommit: newestCommit,
      oldestCommit: oldestCommit,
      minLine: minLine,
      maxLine: maxLine,
    );
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_blame_file(out, _repo(repoHandle), cPath, opts));
    return out.value.address;
  });
}

int blameFileFromBuffer(
  int repoHandle,
  String path,
  String buffer, {
  int flags = 0,
  int minMatchCharacters = 0,
  Uint8List? newestCommit,
  Uint8List? oldestCommit,
  int minLine = 0,
  int maxLine = 0,
}) {
  return using((arena) {
    final out = arena<Pointer<Blame>>();
    final opts = arena<BlameOptions>();
    _initBlameOptions(
      opts,
      flags: flags,
      minMatchCharacters: minMatchCharacters,
      newestCommit: newestCommit,
      oldestCommit: oldestCommit,
      minLine: minLine,
      maxLine: maxLine,
    );
    final cPath = path.toNativeUtf8(allocator: arena).cast<Char>();
    final bytes = buffer.toNativeUtf8(allocator: arena);
    checkCode(
      git_blame_file_from_buffer(
        out,
        _repo(repoHandle),
        cPath,
        bytes.cast<Char>(),
        bytes.length,
        opts,
      ),
    );
    return out.value.address;
  });
}

int blameBuffer(int baseHandle, String buffer) {
  return using((arena) {
    final out = arena<Pointer<Blame>>();
    final bytes = buffer.toNativeUtf8(allocator: arena);
    checkCode(
      git_blame_buffer(
        out,
        _blame(baseHandle),
        bytes.cast<Char>(),
        bytes.length,
      ),
    );
    return out.value.address;
  });
}

void blameFree(int handle) => git_blame_free(_blame(handle));

int blameLineCount(int handle) => git_blame_linecount(_blame(handle));

int blameHunkCount(int handle) => git_blame_hunkcount(_blame(handle));

({
  int linesInHunk,
  Uint8List finalCommitId,
  int finalStartLineNumber,
  ({String name, String email, int time, int offset}) finalSignature,
  ({String name, String email, int time, int offset}) finalCommitter,
  Uint8List origCommitId,
  String origPath,
  int origStartLineNumber,
  ({String name, String email, int time, int offset})? origSignature,
  ({String name, String email, int time, int offset})? origCommitter,
  String summary,
  bool boundary,
})?
blameHunkByIndex(int handle, int index) {
  final ptr = git_blame_hunk_byindex(_blame(handle), index);
  return _readHunk(ptr);
}

({
  int linesInHunk,
  Uint8List finalCommitId,
  int finalStartLineNumber,
  ({String name, String email, int time, int offset}) finalSignature,
  ({String name, String email, int time, int offset}) finalCommitter,
  Uint8List origCommitId,
  String origPath,
  int origStartLineNumber,
  ({String name, String email, int time, int offset})? origSignature,
  ({String name, String email, int time, int offset})? origCommitter,
  String summary,
  bool boundary,
})?
blameHunkByLine(int handle, int lineNumber) {
  final ptr = git_blame_hunk_byline(_blame(handle), lineNumber);
  return _readHunk(ptr);
}

String? blameLineByIndex(int handle, int index) {
  final ptr = git_blame_line_byindex(_blame(handle), index);
  if (ptr == nullptr) return null;
  final len = ptr.ref.len;
  if (ptr.ref.ptr == nullptr || len == 0) return '';
  return ptr.ref.ptr.cast<Utf8>().toDartString(length: len);
}

void _initBlameOptions(
  Pointer<BlameOptions> opts, {
  required int flags,
  required int minMatchCharacters,
  required Uint8List? newestCommit,
  required Uint8List? oldestCommit,
  required int minLine,
  required int maxLine,
}) {
  checkCode(git_blame_options_init(opts, GIT_BLAME_OPTIONS_VERSION));
  opts.ref.flags = flags;
  opts.ref.min_match_characters = minMatchCharacters;
  if (newestCommit != null) {
    for (var i = 0; i < newestCommit.length; i++) {
      opts.ref.newest_commit.id[i] = newestCommit[i];
    }
  }
  if (oldestCommit != null) {
    for (var i = 0; i < oldestCommit.length; i++) {
      opts.ref.oldest_commit.id[i] = oldestCommit[i];
    }
  }
  opts.ref.min_line = minLine;
  opts.ref.max_line = maxLine;
}

({
  int linesInHunk,
  Uint8List finalCommitId,
  int finalStartLineNumber,
  ({String name, String email, int time, int offset}) finalSignature,
  ({String name, String email, int time, int offset}) finalCommitter,
  Uint8List origCommitId,
  String origPath,
  int origStartLineNumber,
  ({String name, String email, int time, int offset})? origSignature,
  ({String name, String email, int time, int offset})? origCommitter,
  String summary,
  bool boundary,
})?
_readHunk(Pointer<BlameHunk> ptr) {
  if (ptr == nullptr) return null;
  final h = ptr.ref;
  final finalId = Uint8List(20);
  final origId = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    finalId[i] = h.final_commit_id.id[i];
    origId[i] = h.orig_commit_id.id[i];
  }
  return (
    linesInHunk: h.lines_in_hunk,
    finalCommitId: finalId,
    finalStartLineNumber: h.final_start_line_number,
    finalSignature: _readSig(h.final_signature),
    finalCommitter: _readSig(h.final_committer),
    origCommitId: origId,
    origPath: h.orig_path == nullptr
        ? ''
        : h.orig_path.cast<Utf8>().toDartString(),
    origStartLineNumber: h.orig_start_line_number,
    origSignature: h.orig_signature == nullptr
        ? null
        : _readSig(h.orig_signature),
    origCommitter: h.orig_committer == nullptr
        ? null
        : _readSig(h.orig_committer),
    summary: h.summary == nullptr ? '' : h.summary.cast<Utf8>().toDartString(),
    boundary: h.boundary != 0,
  );
}

({String name, String email, int time, int offset}) _readSig(
  Pointer<Signature> ptr,
) {
  if (ptr == nullptr) {
    return (name: '', email: '', time: 0, offset: 0);
  }
  return (
    name: ptr.ref.name.cast<Utf8>().toDartString(),
    email: ptr.ref.email.cast<Utf8>().toDartString(),
    time: ptr.ref.when.time,
    offset: ptr.ref.when.offset,
  );
}

Pointer<Blame> _blame(int handle) => Pointer<Blame>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
