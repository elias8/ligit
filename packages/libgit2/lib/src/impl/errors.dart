part of 'api.dart';

/// Error classes are the category of error. They reflect the area of
/// the code where an error occurred.
typedef ErrorCategory = ErrorT;

/// Extra details of the last error that occurred.
///
/// Callers normally observe failures through [Libgit2Exception]
/// subclasses raised from failing calls; [Libgit2LastError] exposes
/// the recorded details directly for callbacks, custom bindings, or
/// introspection that has not yet surfaced as an exception.
///
/// This is kept on a per-thread basis when threading support is
/// compiled into libgit2, and globally otherwise. The contents may
/// be stale after a call that succeeded, so consult it only when
/// you already know a preceding call failed.
@immutable
final class Libgit2LastError {
  /// Human-readable error message libgit2 recorded.
  final String message;

  /// Category the failure belongs to.
  final ErrorCategory category;

  const Libgit2LastError._({required this.message, required this.category});

  /// Returns the last error generated for the current thread, or
  /// `null` when none has been recorded.
  ///
  /// Should not be used to determine whether an error has occurred;
  /// examine return values or catch [Libgit2Exception] subclasses
  /// instead. The message is only reliable immediately after a
  /// known-failing call.
  static Libgit2LastError? read() {
    final raw = errorLast();
    if (raw == null) return null;
    return Libgit2LastError._(message: raw.message, category: raw.klass);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Libgit2LastError &&
          message == other.message &&
          category == other.category);

  @override
  int get hashCode => Object.hash(message, category);

  @override
  String toString() => '$category: $message';
}
