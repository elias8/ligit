import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show DescribeStrategy;

int describeCommit(
  int commitHandle, {
  int maxCandidatesTags = GIT_DESCRIBE_DEFAULT_MAX_CANDIDATES_TAGS,
  DescribeStrategy strategy = DescribeStrategy.default$,
  String? pattern,
  bool onlyFollowFirstParent = false,
  bool showCommitOidAsFallback = false,
}) {
  return using((arena) {
    final out = arena<Pointer<DescribeResult>>();
    final opts = arena<DescribeOptions>();
    checkCode(git_describe_options_init(opts, GIT_DESCRIBE_OPTIONS_VERSION));
    opts.ref.max_candidates_tags = maxCandidatesTags;
    opts.ref.describe_strategy = strategy.value;
    opts.ref.pattern = pattern == null
        ? nullptr.cast<Char>()
        : pattern.toNativeUtf8(allocator: arena).cast<Char>();
    opts.ref.only_follow_first_parent = onlyFollowFirstParent ? 1 : 0;
    opts.ref.show_commit_oid_as_fallback = showCommitOidAsFallback ? 1 : 0;
    checkCode(
      git_describe_commit(out, Pointer<Object>.fromAddress(commitHandle), opts),
    );
    return out.value.address;
  });
}

int describeWorkdir(
  int repoHandle, {
  int maxCandidatesTags = GIT_DESCRIBE_DEFAULT_MAX_CANDIDATES_TAGS,
  DescribeStrategy strategy = DescribeStrategy.default$,
  String? pattern,
  bool onlyFollowFirstParent = false,
  bool showCommitOidAsFallback = false,
}) {
  return using((arena) {
    final out = arena<Pointer<DescribeResult>>();
    final opts = arena<DescribeOptions>();
    checkCode(git_describe_options_init(opts, GIT_DESCRIBE_OPTIONS_VERSION));
    opts.ref.max_candidates_tags = maxCandidatesTags;
    opts.ref.describe_strategy = strategy.value;
    opts.ref.pattern = pattern == null
        ? nullptr.cast<Char>()
        : pattern.toNativeUtf8(allocator: arena).cast<Char>();
    opts.ref.only_follow_first_parent = onlyFollowFirstParent ? 1 : 0;
    opts.ref.show_commit_oid_as_fallback = showCommitOidAsFallback ? 1 : 0;
    checkCode(git_describe_workdir(out, _repo(repoHandle), opts));
    return out.value.address;
  });
}

String describeFormat(
  int handle, {
  int abbreviatedSize = GIT_DESCRIBE_DEFAULT_ABBREVIATED_SIZE,
  bool alwaysUseLongFormat = false,
  String? dirtySuffix,
}) {
  return using((arena) {
    final buf = arena<Buf>();
    final opts = arena<DescribeFormatOptions>();
    checkCode(
      git_describe_format_options_init(
        opts,
        GIT_DESCRIBE_FORMAT_OPTIONS_VERSION,
      ),
    );
    opts.ref.abbreviated_size = abbreviatedSize;
    opts.ref.always_use_long_format = alwaysUseLongFormat ? 1 : 0;
    opts.ref.dirty_suffix = dirtySuffix == null
        ? nullptr.cast<Char>()
        : dirtySuffix.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      checkCode(git_describe_format(buf, _result(handle), opts));
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

void describeResultFree(int handle) {
  git_describe_result_free(_result(handle));
}

Pointer<DescribeResult> _result(int handle) =>
    Pointer<DescribeResult>.fromAddress(handle);

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);
