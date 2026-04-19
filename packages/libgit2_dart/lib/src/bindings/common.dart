import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show Feature;

const commonPathMax = GIT_PATH_MAX;

const commonPathListSeparator = GIT_PATH_LIST_SEPARATOR;

({int major, int minor, int revision}) commonLibgit2Version() {
  return using((arena) {
    final pMajor = arena<Int>();
    final pMinor = arena<Int>();
    final pRev = arena<Int>();
    checkCode(git_libgit2_version(pMajor, pMinor, pRev));
    return (major: pMajor.value, minor: pMinor.value, revision: pRev.value);
  });
}

String? commonLibgit2Prerelease() {
  final ptr = git_libgit2_prerelease();
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}

Set<Feature> commonLibgit2Features() {
  final bits = git_libgit2_features();
  return {
    for (final f in Feature.values)
      if (bits & f.value != 0) f,
  };
}

String? commonLibgit2FeatureBackend(Feature feature) {
  final ptr = git_libgit2_feature_backend(feature);
  if (ptr == nullptr) return null;
  return ptr.cast<Utf8>().toDartString();
}
