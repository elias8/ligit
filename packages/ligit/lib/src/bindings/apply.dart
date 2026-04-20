import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'diff.dart' show DiffDeltaRecord, DiffFileRecord, DiffHunkRecord;
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show ApplyFlags, ApplyLocation;

void apply(
  int repoHandle,
  int diffHandle, {
  int location = 0,
  int flags = 0,
  int Function(DiffDeltaRecord delta)? onDelta,
  int Function(DiffHunkRecord hunk)? onHunk,
}) {
  _runApply(
    onDelta,
    onHunk,
    flags: flags,
    call: (opts) => git_apply(
      _repo(repoHandle),
      _diff(diffHandle),
      ApplyLocation.fromValue(location),
      opts,
    ),
  );
}

int applyToTree(
  int repoHandle,
  int preimageTreeHandle,
  int diffHandle, {
  int flags = 0,
  int Function(DiffDeltaRecord delta)? onDelta,
  int Function(DiffHunkRecord hunk)? onHunk,
}) {
  late int outHandle;
  _runApply(
    onDelta,
    onHunk,
    flags: flags,
    call: (opts) {
      return using((arena) {
        final out = arena<Pointer<Index>>();
        final code = git_apply_to_tree(
          out,
          _repo(repoHandle),
          Pointer<Tree>.fromAddress(preimageTreeHandle),
          _diff(diffHandle),
          opts,
        );
        if (code >= 0) outHandle = out.value.address;
        return code;
      });
    },
  );
  return outHandle;
}

void _runApply(
  int Function(DiffDeltaRecord delta)? onDelta,
  int Function(DiffHunkRecord hunk)? onHunk, {
  required int flags,
  required int Function(Pointer<ApplyOptions> opts) call,
}) {
  using((arena) {
    final opts = arena<ApplyOptions>();
    checkCode(git_apply_options_init(opts, GIT_APPLY_OPTIONS_VERSION));
    opts.ref.flags = flags;

    NativeCallable<Int Function(Pointer<DiffDelta>, Pointer<Void>)>? deltaCb;
    NativeCallable<Int Function(Pointer<DiffHunk>, Pointer<Void>)>? hunkCb;
    if (onDelta != null) {
      deltaCb =
          NativeCallable<
            Int Function(Pointer<DiffDelta>, Pointer<Void>)
          >.isolateLocal((Pointer<DiffDelta> delta, Pointer<Void> _) {
            try {
              return onDelta(_readDelta(delta));
            } on Object {
              return -1;
            }
          }, exceptionalReturn: -1);
      opts.ref.delta_cb = deltaCb.nativeFunction.cast();
    }
    if (onHunk != null) {
      hunkCb =
          NativeCallable<
            Int Function(Pointer<DiffHunk>, Pointer<Void>)
          >.isolateLocal((Pointer<DiffHunk> hunk, Pointer<Void> _) {
            try {
              return onHunk(_readHunk(hunk));
            } on Object {
              return -1;
            }
          }, exceptionalReturn: -1);
      opts.ref.hunk_cb = hunkCb.nativeFunction.cast();
    }
    try {
      checkCode(call(opts));
    } finally {
      deltaCb?.close();
      hunkCb?.close();
    }
  });
}

DiffDeltaRecord _readDelta(Pointer<DiffDelta> ptr) {
  final d = ptr.ref;
  return (
    status: d.statusAsInt,
    flags: d.flags,
    similarity: d.similarity,
    nfiles: d.nfiles,
    oldFile: _readFile(d.old_file),
    newFile: _readFile(d.new_file),
  );
}

DiffFileRecord _readFile(DiffFile f) {
  final id = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    id[i] = f.id.id[i];
  }
  return (
    id: id,
    path: f.path == nullptr ? '' : f.path.cast<Utf8>().toDartString(),
    size: f.size,
    flags: f.flags,
    mode: f.mode,
    idAbbrev: f.id_abbrev,
  );
}

DiffHunkRecord _readHunk(Pointer<DiffHunk> ptr) {
  final h = ptr.ref;
  final bytes = Uint8List(h.header_len);
  for (var i = 0; i < h.header_len; i++) {
    bytes[i] = h.header[i];
  }
  return (
    oldStart: h.old_start,
    oldLines: h.old_lines,
    newStart: h.new_start,
    newLines: h.new_lines,
    header: String.fromCharCodes(bytes),
  );
}

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);

Pointer<Diff> _diff(int handle) => Pointer<Diff>.fromAddress(handle);
