import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import 'types/result.dart';

({int ahead, int behind}) graphAheadBehind(
  int repoHandle,
  Uint8List local,
  Uint8List upstream,
) {
  return using((arena) {
    final ahead = arena<Size>();
    final behind = arena<Size>();
    final localOid = _allocOid(arena, local);
    final upstreamOid = _allocOid(arena, upstream);
    checkCode(
      git_graph_ahead_behind(
        ahead,
        behind,
        _repo(repoHandle),
        localOid,
        upstreamOid,
      ),
    );
    return (ahead: ahead.value, behind: behind.value);
  });
}

bool graphDescendantOf(int repoHandle, Uint8List commit, Uint8List ancestor) {
  return using((arena) {
    final commitOid = _allocOid(arena, commit);
    final ancestorOid = _allocOid(arena, ancestor);
    final result = git_graph_descendant_of(
      _repo(repoHandle),
      commitOid,
      ancestorOid,
    );
    if (result < 0) checkCode(result);
    return result == 1;
  });
}

bool graphReachableFromAny(
  int repoHandle,
  Uint8List commit,
  List<Uint8List> descendants,
) {
  return using((arena) {
    final commitOid = _allocOid(arena, commit);
    final array = arena<Oid>(descendants.length);
    for (var i = 0; i < descendants.length; i++) {
      final bytes = descendants[i];
      for (var j = 0; j < bytes.length; j++) {
        (array + i).ref.id[j] = bytes[j];
      }
    }
    final result = git_graph_reachable_from_any(
      _repo(repoHandle),
      commitOid,
      array,
      descendants.length,
    );
    if (result < 0) checkCode(result);
    return result == 1;
  });
}

Pointer<Repository> _repo(int handle) =>
    Pointer<Repository>.fromAddress(handle);

Pointer<Oid> _allocOid(Allocator arena, Uint8List bytes) {
  final out = arena<Oid>();
  for (var i = 0; i < bytes.length; i++) {
    out.ref.id[i] = bytes[i];
  }
  return out;
}
