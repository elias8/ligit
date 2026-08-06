import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';

Pointer<Strarray> strarrayAlloc(Allocator arena, List<String> values) {
  if (values.isEmpty) return nullptr.cast<Strarray>();
  final ptrs = arena<Pointer<Char>>(values.length);
  for (var i = 0; i < values.length; i++) {
    ptrs[i] = values[i].toNativeUtf8(allocator: arena).cast<Char>();
  }
  return Strarray.$allocate(arena, strings: ptrs, count: values.length);
}

List<String> strarrayToList(Pointer<Strarray> array) {
  final count = array.ref.count;
  final strings = array.ref.strings;
  final result = [
    for (var i = 0; i < count; i++) strings[i].cast<Utf8>().toDartString(),
  ];
  git_strarray_dispose(array);
  return result;
}
