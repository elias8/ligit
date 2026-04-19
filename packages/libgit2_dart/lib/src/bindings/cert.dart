import 'dart:ffi';
import 'dart:typed_data';

import '../ffi/libgit2.g.dart';

export '../ffi/libgit2_enums.g.dart' show CertSsh, CertSshRawType, CertT;

typedef CertHostkeyRecord = ({
  int availableHashes,
  Uint8List md5,
  Uint8List sha1,
  Uint8List sha256,
  int rawType,
  Uint8List hostkey,
});

typedef CertX509Record = ({Uint8List data});

int certReadType(int certAddress) =>
    Pointer<Cert>.fromAddress(certAddress).ref.cert_typeAsInt;

CertHostkeyRecord certReadHostkey(int certAddress) {
  final ref = Pointer<CertHostkey>.fromAddress(certAddress).ref;
  final md5 = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    md5[i] = ref.hash_md5[i];
  }
  final sha1 = Uint8List(20);
  for (var i = 0; i < 20; i++) {
    sha1[i] = ref.hash_sha1[i];
  }
  final sha256 = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    sha256[i] = ref.hash_sha256[i];
  }
  final len = ref.hostkey_len;
  final raw = Uint8List(len);
  final src = ref.hostkey.cast<Uint8>();
  for (var i = 0; i < len; i++) {
    raw[i] = src[i];
  }
  return (
    availableHashes: ref.typeAsInt,
    md5: md5,
    sha1: sha1,
    sha256: sha256,
    rawType: ref.raw_typeAsInt,
    hostkey: raw,
  );
}

CertX509Record certReadX509(int certAddress) {
  final ref = Pointer<CertX509>.fromAddress(certAddress).ref;
  final len = ref.len;
  final data = Uint8List(len);
  final src = ref.data.cast<Uint8>();
  for (var i = 0; i < len; i++) {
    data[i] = src[i];
  }
  return (data: data);
}
