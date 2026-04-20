import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show Direction;

int refspecParse(String input, {required bool isFetch}) {
  return using((arena) {
    final out = arena<Pointer<Refspec>>();
    final cInput = input.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_refspec_parse(out, cInput, isFetch ? 1 : 0));
    return out.value.address;
  });
}

void refspecFree(int handle) => git_refspec_free(_spec(handle));

String refspecSrc(int handle) {
  return git_refspec_src(_spec(handle)).cast<Utf8>().toDartString();
}

String refspecDst(int handle) {
  return git_refspec_dst(_spec(handle)).cast<Utf8>().toDartString();
}

String refspecString(int handle) {
  return git_refspec_string(_spec(handle)).cast<Utf8>().toDartString();
}

bool refspecForce(int handle) => git_refspec_force(_spec(handle)) == 1;

Direction refspecDirection(int handle) {
  return git_refspec_direction(_spec(handle));
}

bool refspecSrcMatchesNegative(int handle, String refname) {
  return using((arena) {
    final cName = refname.toNativeUtf8(allocator: arena).cast<Char>();
    return git_refspec_src_matches_negative(_spec(handle), cName) == 1;
  });
}

bool refspecSrcMatches(int handle, String refname) {
  return using((arena) {
    final cName = refname.toNativeUtf8(allocator: arena).cast<Char>();
    return git_refspec_src_matches(_spec(handle), cName) == 1;
  });
}

bool refspecDstMatches(int handle, String refname) {
  return using((arena) {
    final cName = refname.toNativeUtf8(allocator: arena).cast<Char>();
    return git_refspec_dst_matches(_spec(handle), cName) == 1;
  });
}

String refspecTransform(int handle, String name) {
  return using((arena) {
    final buf = arena<Buf>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      checkCode(git_refspec_transform(buf, _spec(handle), cName));
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

String refspecRtransform(int handle, String name) {
  return using((arena) {
    final buf = arena<Buf>();
    final cName = name.toNativeUtf8(allocator: arena).cast<Char>();
    try {
      checkCode(git_refspec_rtransform(buf, _spec(handle), cName));
      final ptr = buf.ref.ptr;
      if (ptr == nullptr) return '';
      return ptr.cast<Utf8>().toDartString(length: buf.ref.size);
    } finally {
      git_buf_dispose(buf);
    }
  });
}

Pointer<Refspec> _spec(int handle) => Pointer<Refspec>.fromAddress(handle);
