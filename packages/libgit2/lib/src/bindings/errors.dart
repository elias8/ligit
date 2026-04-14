import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';

export '../ffi/libgit2_enums.g.dart' show ErrorCode, ErrorT;

({String message, ErrorT klass})? errorLast() {
  final ptr = git_error_last();
  if (ptr == nullptr) return null;
  final msg = ptr.ref.message;
  if (msg == nullptr) return null;
  return (
    message: msg.cast<Utf8>().toDartString(),
    klass: ErrorT.fromValue(ptr.ref.klass),
  );
}
