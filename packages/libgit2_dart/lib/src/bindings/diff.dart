import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'buffer.dart' show bufString;
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart'
    show
        Delta,
        DiffFind,
        DiffFlag,
        DiffFormat,
        DiffLineT,
        DiffOption,
        DiffStatsFormat,
        SubmoduleIgnore;

const diffHunkHeaderSize = 128;

typedef DiffOptionsRecord = ({
  int flags,
  int ignoreSubmodules,
  List<String> pathspec,
  int contextLines,
  int interhunkLines,
  int idAbbrev,
  int maxSize,
  String? oldPrefix,
  String? newPrefix,
});

typedef DiffFindOptionsRecord = ({
  int flags,
  int renameThreshold,
  int renameFromRewriteThreshold,
  int copyThreshold,
  int breakRewriteThreshold,
  int renameLimit,
});

typedef DiffFileRecord = ({
  Uint8List id,
  String path,
  int size,
  int flags,
  int mode,
  int idAbbrev,
});

typedef DiffDeltaRecord = ({
  int status,
  int flags,
  int similarity,
  int nfiles,
  DiffFileRecord oldFile,
  DiffFileRecord newFile,
});

typedef DiffHunkRecord = ({
  int oldStart,
  int oldLines,
  int newStart,
  int newLines,
  String header,
});

typedef DiffLineRecord = ({
  int origin,
  int oldLineno,
  int newLineno,
  int numLines,
  int contentOffset,
  Uint8List content,
});

int diffTreeToTree(
  int repoHandle,
  int oldTreeHandle,
  int newTreeHandle, {
  DiffOptionsRecord? options,
}) {
  return using((arena) {
    final out = arena<Pointer<Diff>>();
    final opts = options == null ? null : _allocOpts(arena, options);
    checkCode(
      git_diff_tree_to_tree(
        out,
        _repo(repoHandle),
        oldTreeHandle == 0
            ? nullptr.cast<Tree>()
            : Pointer<Tree>.fromAddress(oldTreeHandle),
        newTreeHandle == 0
            ? nullptr.cast<Tree>()
            : Pointer<Tree>.fromAddress(newTreeHandle),
        opts ?? nullptr.cast<DiffOptions>(),
      ),
    );
    return out.value.address;
  });
}

int diffTreeToIndex(
  int repoHandle,
  int oldTreeHandle, {
  int indexHandle = 0,
  DiffOptionsRecord? options,
}) {
  return using((arena) {
    final out = arena<Pointer<Diff>>();
    final opts = options == null ? null : _allocOpts(arena, options);
    checkCode(
      git_diff_tree_to_index(
        out,
        _repo(repoHandle),
        oldTreeHandle == 0
            ? nullptr.cast<Tree>()
            : Pointer<Tree>.fromAddress(oldTreeHandle),
        indexHandle == 0
            ? nullptr.cast<Index>()
            : Pointer<Index>.fromAddress(indexHandle),
        opts ?? nullptr.cast<DiffOptions>(),
      ),
    );
    return out.value.address;
  });
}

int diffIndexToWorkdir(
  int repoHandle, {
  int indexHandle = 0,
  DiffOptionsRecord? options,
}) {
  return using((arena) {
    final out = arena<Pointer<Diff>>();
    final opts = options == null ? null : _allocOpts(arena, options);
    checkCode(
      git_diff_index_to_workdir(
        out,
        _repo(repoHandle),
        indexHandle == 0
            ? nullptr.cast<Index>()
            : Pointer<Index>.fromAddress(indexHandle),
        opts ?? nullptr.cast<DiffOptions>(),
      ),
    );
    return out.value.address;
  });
}

int diffTreeToWorkdir(
  int repoHandle,
  int oldTreeHandle, {
  DiffOptionsRecord? options,
}) {
  return using((arena) {
    final out = arena<Pointer<Diff>>();
    final opts = options == null ? null : _allocOpts(arena, options);
    checkCode(
      git_diff_tree_to_workdir(
        out,
        _repo(repoHandle),
        oldTreeHandle == 0
            ? nullptr.cast<Tree>()
            : Pointer<Tree>.fromAddress(oldTreeHandle),
        opts ?? nullptr.cast<DiffOptions>(),
      ),
    );
    return out.value.address;
  });
}

int diffTreeToWorkdirWithIndex(
  int repoHandle,
  int oldTreeHandle, {
  DiffOptionsRecord? options,
}) {
  return using((arena) {
    final out = arena<Pointer<Diff>>();
    final opts = options == null ? null : _allocOpts(arena, options);
    checkCode(
      git_diff_tree_to_workdir_with_index(
        out,
        _repo(repoHandle),
        oldTreeHandle == 0
            ? nullptr.cast<Tree>()
            : Pointer<Tree>.fromAddress(oldTreeHandle),
        opts ?? nullptr.cast<DiffOptions>(),
      ),
    );
    return out.value.address;
  });
}

int diffIndexToIndex(
  int repoHandle,
  int oldIndexHandle,
  int newIndexHandle, {
  DiffOptionsRecord? options,
}) {
  return using((arena) {
    final out = arena<Pointer<Diff>>();
    final opts = options == null ? null : _allocOpts(arena, options);
    checkCode(
      git_diff_index_to_index(
        out,
        _repo(repoHandle),
        Pointer<Index>.fromAddress(oldIndexHandle),
        Pointer<Index>.fromAddress(newIndexHandle),
        opts ?? nullptr.cast<DiffOptions>(),
      ),
    );
    return out.value.address;
  });
}

int diffFromBuffer(Uint8List buffer) {
  return using((arena) {
    final out = arena<Pointer<Diff>>();
    final data = arena<Uint8>(buffer.length);
    for (var i = 0; i < buffer.length; i++) {
      data[i] = buffer[i];
    }
    checkCode(git_diff_from_buffer(out, data.cast<Char>(), buffer.length));
    return out.value.address;
  });
}

void diffFree(int handle) => git_diff_free(_diff(handle));

void diffMerge(int ontoHandle, int fromHandle) {
  checkCode(git_diff_merge(_diff(ontoHandle), _diff(fromHandle)));
}

void diffFindSimilar(int handle, {DiffFindOptionsRecord? options}) {
  using((arena) {
    final opts = options == null ? null : _allocFindOpts(arena, options);
    checkCode(
      git_diff_find_similar(
        _diff(handle),
        opts ?? nullptr.cast<DiffFindOptions>(),
      ),
    );
  });
}

int diffNumDeltas(int handle) => git_diff_num_deltas(_diff(handle));

int diffNumDeltasOfType(int handle, int status) =>
    git_diff_num_deltas_of_type(_diff(handle), Delta.fromValue(status));

bool diffIsSortedIcase(int handle) =>
    git_diff_is_sorted_icase(_diff(handle)) == 1;

DiffDeltaRecord? diffGetDelta(int handle, int position) {
  final ptr = git_diff_get_delta(_diff(handle), position);
  if (ptr == nullptr) return null;
  return _readDelta(ptr);
}

int diffStatusChar(int status) => git_diff_status_char(Delta.fromValue(status));

String diffToText(int handle, int format) {
  return using((arena) {
    final buf = arena<Buf>();
    checkCode(
      git_diff_to_buf(buf, _diff(handle), DiffFormat.fromValue(format)),
    );
    return bufString(buf);
  });
}

void diffForeach(
  int handle, {
  int Function(DiffDeltaRecord delta, double progress)? onFile,
  int Function(DiffDeltaRecord delta, DiffHunkRecord hunk)? onHunk,
  int Function(
    DiffDeltaRecord delta,
    DiffHunkRecord? hunk,
    DiffLineRecord line,
  )?
  onLine,
}) {
  using((arena) {
    final fileCb = onFile == null
        ? null
        : NativeCallable<
            Int Function(Pointer<DiffDelta>, Float, Pointer<Void>)
          >.isolateLocal((
            Pointer<DiffDelta> delta,
            double progress,
            Pointer<Void> _,
          ) {
            try {
              return onFile(_readDelta(delta), progress);
            } on Object {
              return -1;
            }
          }, exceptionalReturn: -1);
    final hunkCb = onHunk == null
        ? null
        : NativeCallable<
            Int Function(Pointer<DiffDelta>, Pointer<DiffHunk>, Pointer<Void>)
          >.isolateLocal((
            Pointer<DiffDelta> delta,
            Pointer<DiffHunk> hunk,
            Pointer<Void> _,
          ) {
            try {
              return onHunk(_readDelta(delta), _readHunk(hunk));
            } on Object {
              return -1;
            }
          }, exceptionalReturn: -1);
    final lineCb = onLine == null
        ? null
        : NativeCallable<
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
        git_diff_foreach(
          _diff(handle),
          fileCb == null ? nullptr.cast() : fileCb.nativeFunction.cast(),
          nullptr.cast(),
          hunkCb == null ? nullptr.cast() : hunkCb.nativeFunction.cast(),
          lineCb == null ? nullptr.cast() : lineCb.nativeFunction.cast(),
          nullptr.cast(),
        ),
      );
    } finally {
      fileCb?.close();
      hunkCb?.close();
      lineCb?.close();
    }
  });
}

Uint8List diffPatchId(int handle) {
  return using((arena) {
    final out = arena<Oid>();
    final opts = arena<DiffPatchidOptions>();
    checkCode(
      git_diff_patchid_options_init(opts, GIT_DIFF_PATCHID_OPTIONS_VERSION),
    );
    checkCode(git_diff_patchid(out, _diff(handle), opts));
    final bytes = Uint8List(20);
    for (var i = 0; i < 20; i++) {
      bytes[i] = out.ref.id[i];
    }
    return bytes;
  });
}

void diffBlobs(
  int oldBlobHandle,
  String? oldAsPath,
  int newBlobHandle,
  String? newAsPath, {
  DiffOptionsRecord? options,
  int Function(DiffDeltaRecord delta, double progress)? onFile,
  int Function(DiffDeltaRecord delta, DiffHunkRecord hunk)? onHunk,
  int Function(
    DiffDeltaRecord delta,
    DiffHunkRecord? hunk,
    DiffLineRecord line,
  )?
  onLine,
}) {
  using((arena) {
    final opts = options == null ? null : _allocOpts(arena, options);
    final fileCb = _fileCallable(onFile);
    final hunkCb = _hunkCallable(onHunk);
    final lineCb = _lineCallable(onLine);
    try {
      checkCode(
        git_diff_blobs(
          oldBlobHandle == 0
              ? nullptr.cast<Blob>()
              : Pointer<Blob>.fromAddress(oldBlobHandle),
          oldAsPath == null
              ? nullptr.cast<Char>()
              : oldAsPath.toNativeUtf8(allocator: arena).cast<Char>(),
          newBlobHandle == 0
              ? nullptr.cast<Blob>()
              : Pointer<Blob>.fromAddress(newBlobHandle),
          newAsPath == null
              ? nullptr.cast<Char>()
              : newAsPath.toNativeUtf8(allocator: arena).cast<Char>(),
          opts ?? nullptr.cast<DiffOptions>(),
          fileCb == null ? nullptr.cast() : fileCb.nativeFunction.cast(),
          nullptr.cast(),
          hunkCb == null ? nullptr.cast() : hunkCb.nativeFunction.cast(),
          lineCb == null ? nullptr.cast() : lineCb.nativeFunction.cast(),
          nullptr.cast(),
        ),
      );
    } finally {
      fileCb?.close();
      hunkCb?.close();
      lineCb?.close();
    }
  });
}

void diffBlobToBuffer(
  int oldBlobHandle,
  String? oldAsPath,
  Uint8List? newBuffer,
  String? newAsPath, {
  DiffOptionsRecord? options,
  int Function(DiffDeltaRecord delta, double progress)? onFile,
  int Function(DiffDeltaRecord delta, DiffHunkRecord hunk)? onHunk,
  int Function(
    DiffDeltaRecord delta,
    DiffHunkRecord? hunk,
    DiffLineRecord line,
  )?
  onLine,
}) {
  using((arena) {
    final opts = options == null ? null : _allocOpts(arena, options);
    final fileCb = _fileCallable(onFile);
    final hunkCb = _hunkCallable(onHunk);
    final lineCb = _lineCallable(onLine);
    try {
      final data = newBuffer == null
          ? nullptr.cast<Char>()
          : arena<Uint8>(newBuffer.length);
      if (newBuffer != null) {
        for (var i = 0; i < newBuffer.length; i++) {
          (data as Pointer<Uint8>)[i] = newBuffer[i];
        }
      }
      checkCode(
        git_diff_blob_to_buffer(
          oldBlobHandle == 0
              ? nullptr.cast<Blob>()
              : Pointer<Blob>.fromAddress(oldBlobHandle),
          oldAsPath == null
              ? nullptr.cast<Char>()
              : oldAsPath.toNativeUtf8(allocator: arena).cast<Char>(),
          newBuffer == null
              ? nullptr.cast<Char>()
              : (data as Pointer<Uint8>).cast<Char>(),
          newBuffer == null ? 0 : newBuffer.length,
          newAsPath == null
              ? nullptr.cast<Char>()
              : newAsPath.toNativeUtf8(allocator: arena).cast<Char>(),
          opts ?? nullptr.cast<DiffOptions>(),
          fileCb == null ? nullptr.cast() : fileCb.nativeFunction.cast(),
          nullptr.cast(),
          hunkCb == null ? nullptr.cast() : hunkCb.nativeFunction.cast(),
          lineCb == null ? nullptr.cast() : lineCb.nativeFunction.cast(),
          nullptr.cast(),
        ),
      );
    } finally {
      fileCb?.close();
      hunkCb?.close();
      lineCb?.close();
    }
  });
}

void diffBuffers(
  Uint8List? oldBuffer,
  String? oldAsPath,
  Uint8List? newBuffer,
  String? newAsPath, {
  DiffOptionsRecord? options,
  int Function(DiffDeltaRecord delta, double progress)? onFile,
  int Function(DiffDeltaRecord delta, DiffHunkRecord hunk)? onHunk,
  int Function(
    DiffDeltaRecord delta,
    DiffHunkRecord? hunk,
    DiffLineRecord line,
  )?
  onLine,
}) {
  using((arena) {
    final opts = options == null ? null : _allocOpts(arena, options);
    final fileCb = _fileCallable(onFile);
    final hunkCb = _hunkCallable(onHunk);
    final lineCb = _lineCallable(onLine);
    try {
      Pointer<Uint8> fill(Uint8List bytes) {
        final buf = arena<Uint8>(bytes.length);
        for (var i = 0; i < bytes.length; i++) {
          buf[i] = bytes[i];
        }
        return buf;
      }

      final oldPtr = oldBuffer == null
          ? nullptr.cast<Char>()
          : fill(oldBuffer).cast<Char>();
      final newPtr = newBuffer == null
          ? nullptr.cast<Char>()
          : fill(newBuffer).cast<Char>();
      checkCode(
        git_diff_buffers(
          oldPtr.cast(),
          oldBuffer == null ? 0 : oldBuffer.length,
          oldAsPath == null
              ? nullptr.cast<Char>()
              : oldAsPath.toNativeUtf8(allocator: arena).cast<Char>(),
          newPtr.cast(),
          newBuffer == null ? 0 : newBuffer.length,
          newAsPath == null
              ? nullptr.cast<Char>()
              : newAsPath.toNativeUtf8(allocator: arena).cast<Char>(),
          opts ?? nullptr.cast<DiffOptions>(),
          fileCb == null ? nullptr.cast() : fileCb.nativeFunction.cast(),
          nullptr.cast(),
          hunkCb == null ? nullptr.cast() : hunkCb.nativeFunction.cast(),
          lineCb == null ? nullptr.cast() : lineCb.nativeFunction.cast(),
          nullptr.cast(),
        ),
      );
    } finally {
      fileCb?.close();
      hunkCb?.close();
      lineCb?.close();
    }
  });
}

void diffPrint(
  int handle,
  int format,
  int Function(DiffDeltaRecord delta, DiffHunkRecord? hunk, DiffLineRecord line)
  onLine,
) {
  final cb = _lineCallable(onLine)!;
  try {
    checkCode(
      git_diff_print(
        _diff(handle),
        DiffFormat.fromValue(format),
        cb.nativeFunction.cast(),
        nullptr.cast(),
      ),
    );
  } finally {
    cb.close();
  }
}

NativeCallable<Int Function(Pointer<DiffDelta>, Float, Pointer<Void>)>?
_fileCallable(int Function(DiffDeltaRecord, double)? onFile) {
  if (onFile == null) return null;
  return NativeCallable<
    Int Function(Pointer<DiffDelta>, Float, Pointer<Void>)
  >.isolateLocal((Pointer<DiffDelta> delta, double progress, Pointer<Void> _) {
    try {
      return onFile(_readDelta(delta), progress);
    } on Object {
      return -1;
    }
  }, exceptionalReturn: -1);
}

NativeCallable<
  Int Function(Pointer<DiffDelta>, Pointer<DiffHunk>, Pointer<Void>)
>?
_hunkCallable(
  int Function(DiffDeltaRecord delta, DiffHunkRecord hunk)? onHunk,
) {
  if (onHunk == null) return null;
  return NativeCallable<
    Int Function(Pointer<DiffDelta>, Pointer<DiffHunk>, Pointer<Void>)
  >.isolateLocal((
    Pointer<DiffDelta> delta,
    Pointer<DiffHunk> hunk,
    Pointer<Void> _,
  ) {
    try {
      return onHunk(_readDelta(delta), _readHunk(hunk));
    } on Object {
      return -1;
    }
  }, exceptionalReturn: -1);
}

NativeCallable<
  Int Function(
    Pointer<DiffDelta>,
    Pointer<DiffHunk>,
    Pointer<DiffLine>,
    Pointer<Void>,
  )
>?
_lineCallable(
  int Function(
    DiffDeltaRecord delta,
    DiffHunkRecord? hunk,
    DiffLineRecord line,
  )?
  onLine,
) {
  if (onLine == null) return null;
  return NativeCallable<
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
}

int diffStatsNew(int handle) {
  return using((arena) {
    final out = arena<Pointer<DiffStats>>();
    checkCode(git_diff_get_stats(out, _diff(handle)));
    return out.value.address;
  });
}

void diffStatsFree(int handle) =>
    git_diff_stats_free(Pointer<DiffStats>.fromAddress(handle));

int diffStatsFilesChanged(int handle) =>
    git_diff_stats_files_changed(Pointer<DiffStats>.fromAddress(handle));

int diffStatsInsertions(int handle) =>
    git_diff_stats_insertions(Pointer<DiffStats>.fromAddress(handle));

int diffStatsDeletions(int handle) =>
    git_diff_stats_deletions(Pointer<DiffStats>.fromAddress(handle));

String diffStatsToText(int handle, int format, int width) {
  return using((arena) {
    final buf = arena<Buf>();
    checkCode(
      git_diff_stats_to_buf(
        buf,
        Pointer<DiffStats>.fromAddress(handle),
        DiffStatsFormat.fromValue(format),
        width,
      ),
    );
    return bufString(buf);
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

Pointer<DiffFindOptions> _allocFindOpts(
  Allocator arena,
  DiffFindOptionsRecord r,
) {
  final opts = arena<DiffFindOptions>();
  checkCode(git_diff_find_options_init(opts, GIT_DIFF_FIND_OPTIONS_VERSION));
  opts.ref.flags = r.flags;
  opts.ref.rename_threshold = r.renameThreshold;
  opts.ref.rename_from_rewrite_threshold = r.renameFromRewriteThreshold;
  opts.ref.copy_threshold = r.copyThreshold;
  opts.ref.break_rewrite_threshold = r.breakRewriteThreshold;
  opts.ref.rename_limit = r.renameLimit;
  return opts;
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

Pointer<Diff> _diff(int handle) => Pointer<Diff>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
