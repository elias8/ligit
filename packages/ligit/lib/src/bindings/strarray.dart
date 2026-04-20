import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';

List<String> strarrayToList(Pointer<Strarray> array) {
  final count = array.ref.count;
  final strings = array.ref.strings;
  final result = [
    for (var i = 0; i < count; i++) strings[i].cast<Utf8>().toDartString(),
  ];
  git_strarray_dispose(array);
  return result;
}

void strarrayFromList(
  Allocator arena,
  Pointer<Strarray> array,
  List<String> values,
) {
  if (values.isEmpty) {
    array.ref.strings = nullptr;
    array.ref.count = 0;
    return;
  }
  final ptrs = arena<Pointer<Char>>(values.length);
  for (var i = 0; i < values.length; i++) {
    ptrs[i] = values[i].toNativeUtf8(allocator: arena).cast<Char>();
  }
  array.ref.strings = ptrs;
  array.ref.count = values.length;
}

Pointer<Strarray> strarrayAlloc(Allocator arena, List<String> values) {
  if (values.isEmpty) return nullptr.cast<Strarray>();
  final arr = arena<Strarray>();
  strarrayFromList(arena, arr, values);
  return arr;
}
