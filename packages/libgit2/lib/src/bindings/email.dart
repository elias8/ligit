import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show EmailCreateFlags;

String emailCreateFromCommit(
  int commitHandle, {
  int flags = 0,
  String? subjectPrefix,
  int startNumber = 1,
  int rerollNumber = 0,
}) {
  return using((arena) {
    final buf = arena<Buf>();
    final opts = arena<EmailCreateOptions>();
    opts.ref.version = GIT_EMAIL_CREATE_OPTIONS_VERSION;
    opts.ref.flags = flags;
    opts.ref.diff_opts.version = GIT_DIFF_OPTIONS_VERSION;
    opts.ref.diff_opts.flags = 1 << 30;
    opts.ref.diff_opts.context_lines = 3;
    opts.ref.diff_find_opts.version = GIT_DIFF_FIND_OPTIONS_VERSION;
    if (subjectPrefix != null) {
      opts.ref.subject_prefix = subjectPrefix
          .toNativeUtf8(allocator: arena)
          .cast<Char>();
    }
    opts.ref.start_number = startNumber;
    opts.ref.reroll_number = rerollNumber;
    try {
      checkCode(
        git_email_create_from_commit(
          buf,
          Pointer<Commit>.fromAddress(commitHandle),
          opts,
        ),
      );
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}
