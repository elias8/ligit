import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ffi/libgit2.g.dart';
import '../ffi/libgit2_enums.g.dart';
import 'types/result.dart';

export '../ffi/libgit2_enums.g.dart' show TraceLevel;

void traceSet(
  TraceLevel level, {
  void Function(TraceLevel level, String message)? onTrace,
}) {
  _currentCallback?.close();
  _currentCallback = null;
  _currentHandler = null;

  if (onTrace == null) {
    checkCode(git_trace_set(level, nullptr.cast()));
    return;
  }

  _currentHandler = onTrace;
  final callable =
      NativeCallable<Void Function(UnsignedInt, Pointer<Char>)>.listener(
        _dispatch,
      );
  _currentCallback = callable;
  checkCode(git_trace_set(level, callable.nativeFunction));
}

void _dispatch(int level, Pointer<Char> msg) {
  final handler = _currentHandler;
  if (handler == null) return;
  final message = msg == nullptr ? '' : msg.cast<Utf8>().toDartString();
  handler(TraceLevel.fromValue(level), message);
}

NativeCallable<Void Function(UnsignedInt, Pointer<Char>)>? _currentCallback;
void Function(TraceLevel level, String message)? _currentHandler;
