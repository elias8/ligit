import 'dart:ffi';
import 'dart:typed_data';

import '../ffi/libgit2.g.dart';

List<Uint8List> oidarrayToList(Pointer<Oidarray> array) {
  final count = array.ref.count;
  final ids = array.ref.ids;
  final result = <Uint8List>[];
  for (var i = 0; i < count; i++) {
    final bytes = Uint8List(20);
    final src = ids + i;
    for (var j = 0; j < 20; j++) {
      bytes[j] = src.ref.id[j];
    }
    result.add(bytes);
  }
  git_oidarray_dispose(array);
  return result;
}
