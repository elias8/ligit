import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'diff.dart'
    show DiffDeltaRecord, DiffHunkRecord, DiffLineRecord, DiffOptionsRecord;
import 'types/result.dart';

int patchFromDiff(int diffHandle, int position) {
  return using((arena) {
    final out = arena<Pointer<Patch>>();
    checkCode(
      git_patch_from_diff(out, Pointer<Diff>.fromAddress(diffHandle), position),
    );
    return out.value.address;
  });
}

int patchFromBlobs(
  int oldBlobHandle,
  int newBlobHandle, {
  String? oldAsPath,
  String? newAsPath,
  DiffOptionsRecord? options,
}) {
  return using((arena) {
    final out = arena<Pointer<Patch>>();
    final cOld = oldAsPath == null
        ? nullptr.cast<Char>()
        : oldAsPath.toNativeUtf8(allocator: arena).cast<Char>();
    final cNew = newAsPath == null
        ? nullptr.cast<Char>()
        : newAsPath.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_patch_from_blobs(
        out,
        oldBlobHandle == 0
            ? nullptr.cast<Blob>()
            : Pointer<Blob>.fromAddress(oldBlobHandle),
        cOld,
        newBlobHandle == 0
            ? nullptr.cast<Blob>()
            : Pointer<Blob>.fromAddress(newBlobHandle),
        cNew,
        options == null
            ? nullptr.cast<DiffOptions>()
            : _allocOpts(arena, options),
      ),
    );
    return out.value.address;
  });
}

int patchFromBlobAndBuffer(
  int oldBlobHandle,
  Uint8List buffer, {
  String? oldAsPath,
  String? bufferAsPath,
  DiffOptionsRecord? options,
}) {
  return using((arena) {
    final out = arena<Pointer<Patch>>();
    final bytes = arena<Uint8>(buffer.length);
    for (var i = 0; i < buffer.length; i++) {
      bytes[i] = buffer[i];
    }
    final cOld = oldAsPath == null
        ? nullptr.cast<Char>()
        : oldAsPath.toNativeUtf8(allocator: arena).cast<Char>();
    final cPath = bufferAsPath == null
        ? nullptr.cast<Char>()
        : bufferAsPath.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_patch_from_blob_and_buffer(
        out,
        oldBlobHandle == 0
            ? nullptr.cast<Blob>()
            : Pointer<Blob>.fromAddress(oldBlobHandle),
        cOld,
        bytes.cast<Void>(),
        buffer.length,
        cPath,
        options == null
            ? nullptr.cast<DiffOptions>()
            : _allocOpts(arena, options),
      ),
    );
    return out.value.address;
  });
}

int patchFromBuffers(
  Uint8List oldBuffer,
  Uint8List newBuffer, {
  String? oldAsPath,
  String? newAsPath,
  DiffOptionsRecord? options,
}) {
  return using((arena) {
    final out = arena<Pointer<Patch>>();
    final oldBytes = arena<Uint8>(oldBuffer.length);
    for (var i = 0; i < oldBuffer.length; i++) {
      oldBytes[i] = oldBuffer[i];
    }
    final newBytes = arena<Uint8>(newBuffer.length);
    for (var i = 0; i < newBuffer.length; i++) {
      newBytes[i] = newBuffer[i];
    }
    final cOld = oldAsPath == null
        ? nullptr.cast<Char>()
        : oldAsPath.toNativeUtf8(allocator: arena).cast<Char>();
    final cNew = newAsPath == null
        ? nullptr.cast<Char>()
        : newAsPath.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(
      git_patch_from_buffers(
        out,
        oldBytes.cast<Void>(),
        oldBuffer.length,
        cOld,
        newBytes.cast<Void>(),
        newBuffer.length,
        cNew,
        options == null
            ? nullptr.cast<DiffOptions>()
            : _allocOpts(arena, options),
      ),
    );
    return out.value.address;
  });
}

void patchFree(int handle) => git_patch_free(_patch(handle));

DiffDeltaRecord? patchGetDelta(int handle) {
  final ptr = git_patch_get_delta(_patch(handle));
  if (ptr == nullptr) return null;
  return _readDelta(ptr);
}

void patchPrint(
  int handle,
  int Function(DiffDeltaRecord delta, DiffHunkRecord? hunk, DiffLineRecord line)
  onLine,
) {
  final cb =
      NativeCallable<
        Int Function(
          Pointer<DiffDelta>,
          Pointer<DiffHunk>,
          Pointer<DiffLine>,
          Pointer<Void>,
        )
      >.isolateLocal((
        Pointer<DiffDelta> delta,
        Pointer<DiffHunk> hunk,
        Pointer<DiffLine> line,
        Pointer<Void> _,
      ) {
        try {
          return onLine(
            _readDelta(delta),
            hunk == nullptr ? null : _readHunk(hunk),
            _readLine(line),
          );
        } on Object {
          return -1;
        }
      }, exceptionalReturn: -1);
  try {
    checkCode(
      git_patch_print(_patch(handle), cb.nativeFunction.cast(), nullptr.cast()),
    );
  } finally {
    cb.close();
  }
}

int patchOwner(int handle) => git_patch_owner(_patch(handle)).address;

int patchNumHunks(int handle) => git_patch_num_hunks(_patch(handle));

({int context, int additions, int deletions}) patchLineStats(int handle) {
  return using((arena) {
    final ctx = arena<Size>();
    final add = arena<Size>();
    final del = arena<Size>();
    checkCode(git_patch_line_stats(ctx, add, del, _patch(handle)));
    return (context: ctx.value, additions: add.value, deletions: del.value);
  });
}

({DiffHunkRecord hunk, int lines}) patchGetHunk(int handle, int hunkIndex) {
  return using((arena) {
    final out = arena<Pointer<DiffHunk>>();
    final lines = arena<Size>();
    checkCode(git_patch_get_hunk(out, lines, _patch(handle), hunkIndex));
    return (hunk: _readHunk(out.value), lines: lines.value);
  });
}

int patchNumLinesInHunk(int handle, int hunkIndex) =>
    git_patch_num_lines_in_hunk(_patch(handle), hunkIndex);

DiffLineRecord patchGetLineInHunk(int handle, int hunkIndex, int lineOfHunk) {
  return using((arena) {
    final out = arena<Pointer<DiffLine>>();
    checkCode(
      git_patch_get_line_in_hunk(out, _patch(handle), hunkIndex, lineOfHunk),
    );
    return _readLine(out.value);
  });
}

int patchSize(
  int handle, {
  bool includeContext = true,
  bool includeHunkHeaders = true,
  bool includeFileHeaders = true,
}) => git_patch_size(
  _patch(handle),
  includeContext ? 1 : 0,
  includeHunkHeaders ? 1 : 0,
  includeFileHeaders ? 1 : 0,
);

String patchToText(int handle) {
  return using((arena) {
    final buf = arena<Buf>();
    checkCode(git_patch_to_buf(buf, _patch(handle)));
    try {
      final bytes = buf.ref.ptr.cast<Uint8>();
      final len = buf.ref.size;
      final data = Uint8List(len);
      for (var i = 0; i < len; i++) {
        data[i] = bytes[i];
      }
      return String.fromCharCodes(data);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

Pointer<DiffOptions> _allocOpts(Allocator arena, DiffOptionsRecord r) {
  final opts = arena<DiffOptions>();
  checkCode(git_diff_options_init(opts, GIT_DIFF_OPTIONS_VERSION));
  opts.ref.flags = r.flags;
  opts.ref.ignore_submodulesAsInt = r.ignoreSubmodules;
  opts.ref.context_lines = r.contextLines;
  opts.ref.interhunk_lines = r.interhunkLines;
  opts.ref.id_abbrev = r.idAbbrev;
  opts.ref.max_size = r.maxSize;
  if (r.pathspec.isNotEmpty) {
    final ptrs = arena<Pointer<Char>>(r.pathspec.length);
    for (var i = 0; i < r.pathspec.length; i++) {
      ptrs[i] = r.pathspec[i].toNativeUtf8(allocator: arena).cast<Char>();
    }
    opts.ref.pathspec.strings = ptrs;
    opts.ref.pathspec.count = r.pathspec.length;
  }
  if (r.oldPrefix != null) {
    opts.ref.old_prefix = r.oldPrefix!
        .toNativeUtf8(allocator: arena)
        .cast<Char>();
  }
  if (r.newPrefix != null) {
    opts.ref.new_prefix = r.newPrefix!
        .toNativeUtf8(allocator: arena)
        .cast<Char>();
  }
  return opts;
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

DiffLineRecord _readLine(Pointer<DiffLine> ptr) {
  final l = ptr.ref;
  final data = Uint8List(l.content_len);
  final src = l.content.cast<Uint8>();
  for (var i = 0; i < l.content_len; i++) {
    data[i] = src[i];
  }
  return (
    origin: l.origin,
    oldLineno: l.old_lineno,
    newLineno: l.new_lineno,
    numLines: l.num_lines,
    contentOffset: l.content_offset,
    content: data,
  );
}

DiffDeltaRecord _readDelta(Pointer<DiffDelta> ptr) {
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

Pointer<Patch> _patch(int handle) => Pointer<Patch>.fromAddress(handle);
