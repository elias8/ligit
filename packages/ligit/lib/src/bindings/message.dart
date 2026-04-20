import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

String messagePrettify(
  String message, {
  bool stripComments = false,
  String commentChar = '#',
}) {
  if (commentChar.length != 1) {
    throw ArgumentError.value(
      commentChar,
      'commentChar',
      'must be a single character',
    );
  }
  return using((arena) {
    final buf = arena<Buf>();
    final cMessage = message.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      checkCode(
        git_message_prettify(
          buf,
          cMessage,
          stripComments ? 1 : 0,
          commentChar.codeUnitAt(0),
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

List<({String key, String value})> messageTrailers(String message) {
  return using((arena) {
    final arr = arena<MessageTrailerArray>();
    final cMessage = message.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      checkCode(git_message_trailers(arr, cMessage));
      final count = arr.ref.count;
      final result = <({String key, String value})>[];
      for (var i = 0; i < count; i++) {
        final entry = (arr.ref.trailers + i).ref;
        result.add((
          key: entry.key.cast<Utf8>().toDartString(),
          value: entry.value.cast<Utf8>().toDartString(),
        ));
      }
      return result;
    } finally {
      git_message_trailer_array_free(arr);
    }
  });
}
