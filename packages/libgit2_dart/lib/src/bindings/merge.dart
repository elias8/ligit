import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'index.dart' show IndexEntryRecord;
import 'oidarray.dart' show oidarrayToList;
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart'
    show
        MergeAnalysis,
        MergeFileFavor,
        MergeFileFlag,
        MergeFlag,
        MergePreference;

const mergeConflictMarkerSize = GIT_MERGE_CONFLICT_MARKER_SIZE;

typedef MergeOptionsRecord = ({
  int flags,
  int renameThreshold,
  int targetLimit,
  int recursionLimit,
  String? defaultDriver,
  int fileFavor,
  int fileFlags,
});

typedef MergeFileOptionsRecord = ({
  String? ancestorLabel,
  String? ourLabel,
  String? theirLabel,
  int favor,
  int flags,
  int markerSize,
});

typedef MergeFileInputRecord = ({Uint8List contents, String? path, int mode});

typedef MergeFileResultRecord = ({
  bool automergeable,
  String? path,
  int mode,
  Uint8List contents,
});

({int analysis, int preference}) mergeAnalysis(
  int repoHandle,
  List<int> theirHeads,
) {
  return using((arena) {
    final analysis = arena<UnsignedInt>();
    final preference = arena<UnsignedInt>();
    final heads = _allocHeads(arena, theirHeads);
    checkCode(
      git_merge_analysis(
        analysis,
        preference,
        _repo(repoHandle),
        heads,
        theirHeads.length,
      ),
    );
    return (analysis: analysis.value, preference: preference.value);
  });
}

({int analysis, int preference}) mergeAnalysisForRef(
  int repoHandle,
  int refHandle,
  List<int> theirHeads,
) {
  return using((arena) {
    final analysis = arena<UnsignedInt>();
    final preference = arena<UnsignedInt>();
    final heads = _allocHeads(arena, theirHeads);
    checkCode(
      git_merge_analysis_for_ref(
        analysis,
        preference,
        _repo(repoHandle),
        Pointer<Reference>.fromAddress(refHandle),
        heads,
        theirHeads.length,
      ),
    );
    return (analysis: analysis.value, preference: preference.value);
  });
}

Uint8List? mergeBase(int repoHandle, Uint8List one, Uint8List two) {
  return using((arena) {
    final out = arena<Oid>();
    final oneOid = _allocOid(arena, one);
    final twoOid = _allocOid(arena, two);
    final result = git_merge_base(out, _repo(repoHandle), oneOid, twoOid);
    if (result == ErrorCode.enotfound.value) return null;
    checkCode(result);
    return _oidBytes(out);
  });
}

Uint8List? mergeBaseMany(int repoHandle, List<Uint8List> inputs) {
  return using((arena) {
    final out = arena<Oid>();
    final arr = _allocOidArray(arena, inputs);
    final result = git_merge_base_many(
      out,
      _repo(repoHandle),
      inputs.length,
      arr,
    );
    if (result == ErrorCode.enotfound.value) return null;
    checkCode(result);
    return _oidBytes(out);
  });
}

Uint8List? mergeBaseOctopus(int repoHandle, List<Uint8List> inputs) {
  return using((arena) {
    final out = arena<Oid>();
    final arr = _allocOidArray(arena, inputs);
    final result = git_merge_base_octopus(
      out,
      _repo(repoHandle),
      inputs.length,
      arr,
    );
    if (result == ErrorCode.enotfound.value) return null;
    checkCode(result);
    return _oidBytes(out);
  });
}

List<Uint8List> mergeBases(int repoHandle, Uint8List one, Uint8List two) {
  return using((arena) {
    final out = arena<Oidarray>();
    final oneOid = _allocOid(arena, one);
    final twoOid = _allocOid(arena, two);
    checkCode(git_merge_bases(out, _repo(repoHandle), oneOid, twoOid));
    return oidarrayToList(out);
  });
}

List<Uint8List> mergeBasesMany(int repoHandle, List<Uint8List> inputs) {
  return using((arena) {
    final out = arena<Oidarray>();
    final arr = _allocOidArray(arena, inputs);
    checkCode(git_merge_bases_many(out, _repo(repoHandle), inputs.length, arr));
    return oidarrayToList(out);
  });
}

int mergeTrees(
  int repoHandle,
  int ancestorTreeHandle,
  int ourTreeHandle,
  int theirTreeHandle, {
  MergeOptionsRecord? options,
}) {
  return using((arena) {
    final opts = options == null ? null : _allocMergeOptions(arena, options);
    final out = arena<Pointer<Index>>();
    checkCode(
      git_merge_trees(
        out,
        _repo(repoHandle),
        ancestorTreeHandle == 0
            ? nullptr.cast<Tree>()
            : Pointer<Tree>.fromAddress(ancestorTreeHandle),
        Pointer<Tree>.fromAddress(ourTreeHandle),
        Pointer<Tree>.fromAddress(theirTreeHandle),
        opts ?? nullptr.cast<MergeOptions>(),
      ),
    );
    return out.value.address;
  });
}

int mergeCommits(
  int repoHandle,
  int ourCommitHandle,
  int theirCommitHandle, {
  MergeOptionsRecord? options,
}) {
  return using((arena) {
    final opts = options == null ? null : _allocMergeOptions(arena, options);
    final out = arena<Pointer<Index>>();
    checkCode(
      git_merge_commits(
        out,
        _repo(repoHandle),
        Pointer<Commit>.fromAddress(ourCommitHandle),
        Pointer<Commit>.fromAddress(theirCommitHandle),
        opts ?? nullptr.cast<MergeOptions>(),
      ),
    );
    return out.value.address;
  });
}

void merge(
  int repoHandle,
  List<int> theirHeads, {
  MergeOptionsRecord? mergeOptions,
  int checkoutStrategy = 0,
  List<String> checkoutPaths = const [],
}) {
  using((arena) {
    final mopts = mergeOptions == null
        ? null
        : _allocMergeOptions(arena, mergeOptions);
    final heads = _allocHeads(arena, theirHeads);
    final copts = _allocCheckoutOptions(
      arena,
      strategy: checkoutStrategy,
      paths: checkoutPaths,
    );
    checkCode(
      git_merge(
        _repo(repoHandle),
        heads,
        theirHeads.length,
        mopts ?? nullptr.cast<MergeOptions>(),
        copts,
      ),
    );
  });
}

Pointer<CheckoutOptions> _allocCheckoutOptions(
  Allocator arena, {
  required int strategy,
  required List<String> paths,
}) {
  final opts = arena<CheckoutOptions>();
  checkCode(git_checkout_options_init(opts, GIT_CHECKOUT_OPTIONS_VERSION));
  opts.ref.checkout_strategy = strategy;
  if (paths.isNotEmpty) {
    final ptrs = arena<Pointer<Char>>(paths.length);
    for (var i = 0; i < paths.length; i++) {
      ptrs[i] = paths[i].toNativeUtf8(allocator: arena).cast<Char>();
    }
    opts.ref.paths.strings = ptrs;
    opts.ref.paths.count = paths.length;
  }
  return opts;
}

MergeFileResultRecord mergeFile(
  MergeFileInputRecord ancestor,
  MergeFileInputRecord ours,
  MergeFileInputRecord theirs, {
  MergeFileOptionsRecord? options,
}) {
  return using((arena) {
    final out = arena<MergeFileResult>();
    final opts = options == null
        ? nullptr.cast<MergeFileOptions>()
        : _allocFileOptions(arena, options);
    final a = _allocFileInput(arena, ancestor);
    final o = _allocFileInput(arena, ours);
    final t = _allocFileInput(arena, theirs);
    checkCode(git_merge_file(out, a, o, t, opts));
    try {
      return _readFileResult(out);
    } finally {
      git_merge_file_result_free(out);
    }
  });
}

MergeFileResultRecord mergeFileFromIndex(
  int repoHandle, {
  required IndexEntryRecord? ancestor,
  required IndexEntryRecord? ours,
  required IndexEntryRecord? theirs,
  MergeFileOptionsRecord? options,
}) {
  return using((arena) {
    final out = arena<MergeFileResult>();
    final opts = options == null
        ? nullptr.cast<MergeFileOptions>()
        : _allocFileOptions(arena, options);
    checkCode(
      git_merge_file_from_index(
        out,
        _repo(repoHandle),
        ancestor == null
            ? nullptr.cast<IndexEntry>()
            : _allocIndexEntry(arena, ancestor),
        ours == null
            ? nullptr.cast<IndexEntry>()
            : _allocIndexEntry(arena, ours),
        theirs == null
            ? nullptr.cast<IndexEntry>()
            : _allocIndexEntry(arena, theirs),
        opts,
      ),
    );
    try {
      return _readFileResult(out);
    } finally {
      git_merge_file_result_free(out);
    }
  });
}

Pointer<IndexEntry> _allocIndexEntry(Allocator arena, IndexEntryRecord r) {
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

Pointer<Pointer<AnnotatedCommit>> _allocHeads(
  Allocator arena,
  List<int> handles,
) {
  final arr = arena<Pointer<AnnotatedCommit>>(handles.length);
  for (var i = 0; i < handles.length; i++) {
    arr[i] = Pointer<AnnotatedCommit>.fromAddress(handles[i]);
  }
  return arr;
}

Pointer<Oid> _allocOid(Allocator arena, Uint8List bytes) {
  final out = arena<Oid>();
  for (var i = 0; i < bytes.length; i++) {
    out.ref.id[i] = bytes[i];
  }
  return out;
}

Pointer<Oid> _allocOidArray(Allocator arena, List<Uint8List> inputs) {
  final arr = arena<Oid>(inputs.length);
  for (var i = 0; i < inputs.length; i++) {
    final bytes = inputs[i];
    for (var j = 0; j < bytes.length; j++) {
      (arr + i).ref.id[j] = bytes[j];
    }
  }
  return arr;
}

Uint8List _oidBytes(Pointer<Oid> ptr) {
  final out = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    out[i] = ptr.ref.id[i];
  }
  return out;
}

Pointer<MergeOptions> _allocMergeOptions(
  Allocator arena,
  MergeOptionsRecord r,
) {
  final opts = arena<MergeOptions>();
  checkCode(git_merge_options_init(opts, GIT_MERGE_OPTIONS_VERSION));
  opts.ref.flags = r.flags;
  opts.ref.rename_threshold = r.renameThreshold;
  opts.ref.target_limit = r.targetLimit;
  opts.ref.recursion_limit = r.recursionLimit;
  opts.ref.file_favorAsInt = r.fileFavor;
  opts.ref.file_flags = r.fileFlags;
  if (r.defaultDriver != null) {
    opts.ref.default_driver = r.defaultDriver!
        .toNativeUtf8(allocator: arena)
        .cast<Char>();
  }
  return opts;
}

Pointer<MergeFileOptions> _allocFileOptions(
  Allocator arena,
  MergeFileOptionsRecord r,
) {
  final opts = arena<MergeFileOptions>();
  checkCode(git_merge_file_options_init(opts, GIT_MERGE_FILE_OPTIONS_VERSION));
  opts.ref.favorAsInt = r.favor;
  opts.ref.flags = r.flags;
  opts.ref.marker_size = r.markerSize;
  if (r.ancestorLabel != null) {
    opts.ref.ancestor_label = r.ancestorLabel!
        .toNativeUtf8(allocator: arena)
        .cast<Char>();
  }
  if (r.ourLabel != null) {
    opts.ref.our_label = r.ourLabel!
        .toNativeUtf8(allocator: arena)
        .cast<Char>();
  }
  if (r.theirLabel != null) {
    opts.ref.their_label = r.theirLabel!
        .toNativeUtf8(allocator: arena)
        .cast<Char>();
  }
  return opts;
}

Pointer<MergeFileInput> _allocFileInput(
  Allocator arena,
  MergeFileInputRecord r,
) {
  final input = arena<MergeFileInput>();
  checkCode(git_merge_file_input_init(input, GIT_MERGE_FILE_INPUT_VERSION));
  final bytes = arena<Uint8>(r.contents.length);
  for (var i = 0; i < r.contents.length; i++) {
    bytes[i] = r.contents[i];
  }
  input.ref.ptr = bytes.cast<Char>();
  input.ref.size = r.contents.length;
  input.ref.mode = r.mode;
  if (r.path != null) {
    input.ref.path = r.path!.toNativeUtf8(allocator: arena).cast<Char>();
  }
  return input;
}

MergeFileResultRecord _readFileResult(Pointer<MergeFileResult> ptr) {
  final r = ptr.ref;
  final len = r.len;
  final data = Uint8List(len);
  final src = r.ptr.cast<Uint8>();
  for (var i = 0; i < len; i++) {
    data[i] = src[i];
  }
  return (
    automergeable: r.automergeable != 0,
    path: r.path == nullptr ? null : r.path.cast<Utf8>().toDartString(),
    mode: r.mode,
    contents: data,
  );
}

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
