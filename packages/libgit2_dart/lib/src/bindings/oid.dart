import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

const oidRawSize = GIT_OID_SHA1_SIZE;

const oidHexSize = GIT_OID_SHA1_HEXSIZE;

const oidMaxRawSize = GIT_OID_MAX_SIZE;

const oidMaxHexSize = GIT_OID_MAX_HEXSIZE;

const oidMinPrefixLen = GIT_OID_MINPREFIXLEN;

const oidHexZero = GIT_OID_SHA1_HEXZERO;

const oidDefault = GIT_OID_DEFAULT;

const oidPathSize = oidHexSize + 1;

Uint8List oidFromStr(String hex) {
  if (hex.length != oidHexSize) {
    throw ArgumentError.value(
      hex,
      'hex',
      'expected exactly $oidHexSize hex characters, got ${hex.length}',
    );
  }
  return using((arena) {
    final out = arena<Oid>();
    final cHex = hex.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_oid_fromstr(out, cHex));
    return _oidBytes(out);
  });
}

Uint8List oidFromStrp(String hex) {
  return using((arena) {
    final out = arena<Oid>();
    final cHex = hex.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_oid_fromstrp(out, cHex));
    return _oidBytes(out);
  });
}

Uint8List oidFromStrn(String hex, int length) {
  if (length < 0 || length > hex.length) {
    throw ArgumentError.value(length, 'length', 'out of range for hex');
  }
  return using((arena) {
    final out = arena<Oid>();
    final cHex = hex.toNativeUtf8(allocator: arena).cast<Char>();
    checkCode(git_oid_fromstrn(out, cHex, length));
    return _oidBytes(out);
  });
}

Uint8List oidFromRaw(Uint8List raw) {
  if (raw.length != oidRawSize) {
    throw ArgumentError.value(
      raw,
      'raw',
      'expected exactly $oidRawSize bytes, got ${raw.length}',
    );
  }
  return using((arena) {
    final out = arena<Oid>();
    final src = arena<UnsignedChar>(oidRawSize);
    for (var i = 0; i < oidRawSize; i++) {
      src[i] = raw[i];
    }
    checkCode(git_oid_fromraw(out, src));
    return _oidBytes(out);
  });
}

String oidFmt(Uint8List bytes) {
  return using((arena) {
    final oid = _allocOid(arena, bytes);
    final buf = arena<Char>(oidHexSize);
    checkCode(git_oid_fmt(buf, oid));
    return buf.cast<Utf8>().toDartString(length: oidHexSize);
  });
}

String oidNfmt(Uint8List bytes, int length) {
  if (length < 0) {
    throw ArgumentError.value(length, 'length', 'must not be negative');
  }
  if (length == 0) return '';
  return using((arena) {
    final oid = _allocOid(arena, bytes);
    final buf = arena<Char>(length);
    checkCode(git_oid_nfmt(buf, length, oid));
    final cap = length < oidHexSize ? length : oidHexSize;
    return buf.cast<Utf8>().toDartString(length: cap);
  });
}

String oidPathfmt(Uint8List bytes) {
  return using((arena) {
    final oid = _allocOid(arena, bytes);
    final buf = arena<Char>(oidPathSize);
    checkCode(git_oid_pathfmt(buf, oid));
    return buf.cast<Utf8>().toDartString(length: oidPathSize);
  });
}

String oidTostrS(Uint8List bytes) {
  return using((arena) {
    final oid = _allocOid(arena, bytes);
    final ptr = git_oid_tostr_s(oid);
    if (ptr == nullptr) {
      throw const OutOfMemoryException(
        message: 'git_oid_tostr_s returned NULL',
      );
    }
    return ptr.cast<Utf8>().toDartString();
  });
}

String oidTostr(Uint8List bytes, int bufferSize) {
  if (bufferSize < 0) {
    throw ArgumentError.value(bufferSize, 'bufferSize', 'must not be negative');
  }
  if (bufferSize == 0) return '';
  return using((arena) {
    final oid = _allocOid(arena, bytes);
    final buf = arena<Char>(bufferSize);
    final ret = git_oid_tostr(buf, bufferSize, oid);
    if (ret == nullptr) return '';
    return buf.cast<Utf8>().toDartString();
  });
}

Uint8List oidCpy(Uint8List bytes) {
  return using((arena) {
    final src = _allocOid(arena, bytes);
    final dst = arena<Oid>();
    checkCode(git_oid_cpy(dst, src));
    return _oidBytes(dst);
  });
}

int oidCmp(Uint8List a, Uint8List b) {
  return using((arena) {
    final pa = _allocOid(arena, a);
    final pb = _allocOid(arena, b);
    return git_oid_cmp(pa, pb);
  });
}

bool oidEqual(Uint8List a, Uint8List b) {
  return using((arena) {
    final pa = _allocOid(arena, a);
    final pb = _allocOid(arena, b);
    return git_oid_equal(pa, pb) != 0;
  });
}

int oidNcmp(Uint8List a, Uint8List b, int hexLength) {
  if (hexLength < 0) {
    throw ArgumentError.value(hexLength, 'hexLength', 'must not be negative');
  }
  return using((arena) {
    final pa = _allocOid(arena, a);
    final pb = _allocOid(arena, b);
    return git_oid_ncmp(pa, pb, hexLength);
  });
}

bool oidStreq(Uint8List bytes, String str) {
  return using((arena) {
    final oid = _allocOid(arena, bytes);
    final cStr = str.toNativeUtf8(allocator: arena).cast<Char>();
    return git_oid_streq(oid, cStr) == 0;
  });
}

int oidStrcmp(Uint8List bytes, String str) {
  return using((arena) {
    final oid = _allocOid(arena, bytes);
    final cStr = str.toNativeUtf8(allocator: arena).cast<Char>();
    return git_oid_strcmp(oid, cStr);
  });
}

bool oidIsZero(Uint8List bytes) {
  return using((arena) {
    final oid = _allocOid(arena, bytes);
    return git_oid_is_zero(oid) == 1;
  });
}

int oidShortenNew(int minLength) {
  if (minLength < 0) {
    throw ArgumentError.value(minLength, 'minLength', 'must not be negative');
  }
  final ptr = git_oid_shorten_new(minLength);
  if (ptr == nullptr) {
    throw const OutOfMemoryException(
      message: 'git_oid_shorten_new returned NULL',
    );
  }
  return ptr.address;
}

int oidShortenAdd(int handle, String textId) {
  return using((arena) {
    final cText = textId.toNativeUtf8(allocator: arena).cast<Char>();
    final result = git_oid_shorten_add(_shortener(handle), cText);
    checkCode(result);
    return result;
  });
}

void oidShortenFree(int handle) => git_oid_shorten_free(_shortener(handle));

Pointer<Oid> _allocOid(Allocator arena, Uint8List bytes) {
  if (bytes.length != oidRawSize) {
    throw ArgumentError.value(
      bytes,
      'bytes',
      'expected exactly $oidRawSize bytes, got ${bytes.length}',
    );
  }
  final out = arena<Oid>();
  for (var i = 0; i < oidRawSize; i++) {
    out.ref.id[i] = bytes[i];
  }
  return out;
}

Uint8List _oidBytes(Pointer<Oid> ptr) {
  final out = Uint8List(oidRawSize);
  for (var i = 0; i < oidRawSize; i++) {
    out[i] = ptr.ref.id[i];
  }
  return out;
}

Pointer<OidShorten> _shortener(int handle) =>
    Pointer<OidShorten>.fromAddress(handle);
