import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';

String bufString(Pointer<Buf> buf) {
  final ptr = buf.ref.ptr;
  if (ptr == nullptr || buf.ref.size == 0) {
    git_buf_dispose(buf);
    return '';
  }
  final result = ptr.cast<Utf8>().toDartString(length: buf.ref.size);
  git_buf_dispose(buf);
  return result;
}

Uint8List bufBytes(Pointer<Buf> buf) {
  final len = buf.ref.size;
  final data = Uint8List(len);
  if (len > 0) {
    final src = buf.ref.ptr.cast<Uint8>();
    for (var i = 0; i < len; i++) {
      data[i] = src[i];
    }
  }
  git_buf_dispose(buf);
  return data;
}
