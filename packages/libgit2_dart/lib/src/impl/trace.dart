part of 'api.dart';

/// Global tracing controls.
///
/// Install a callback with [Libgit2Trace.set] to receive libgit2's
/// internal diagnostic events. The callback runs on whatever thread
/// libgit2 happens to be using, so heavy work belongs in a separate
/// isolate; events are delivered through a [NativeCallable]
/// listener that wakes the owning Dart isolate.
///
/// ```dart
/// Libgit2Trace.set(TraceLevel.info, (level, msg) {
///   print('[$level] $msg');
/// });
/// // ... later:
/// Libgit2Trace.clear();
/// ```
abstract final class Libgit2Trace {
  /// Installs [onTrace] at [level], replacing any callback
  /// previously set.
  static void set(
    TraceLevel level,
    void Function(TraceLevel level, String message) onTrace,
  ) {
    traceSet(level, onTrace: onTrace);
  }

  /// Disables tracing and releases the callback.
  static void clear() {
    traceSet(TraceLevel.none);
  }
}
