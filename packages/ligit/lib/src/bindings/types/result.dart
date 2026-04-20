import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../ffi/libgit2.g.dart' as native;
import '../../ffi/libgit2_enums.g.dart';

/// Checks [result]'s return code and returns its value on success.
///
/// Shorthand for calling [checkCode] on the code half of the pair and
/// then reading the value half. Throws the same [Libgit2Exception]
/// subclasses that [checkCode] would throw.
T check<T>(CResult<T> result) {
  checkCode(result.$1);
  return result.$2;
}

/// Throws a [Libgit2Exception] when [code] is negative; returns
/// silently otherwise.
///
/// Reads libgit2's current thread-local error state and raises the
/// most specific [Libgit2Exception] subclass for the failure. Zero
/// and positive codes are treated as success. The raised exception
/// carries the message libgit2 recorded for the failing call, the
/// numeric [Libgit2Error] code, and the error category ([ErrorT])
/// libgit2 assigned to the failure.
void checkCode(int code) {
  if (code >= 0) return;

  final errPtr = native.git_error_last();
  final message = errPtr == nullptr ? null : errPtr.ref.message.toDartString();
  final klass = errPtr == nullptr
      ? ErrorT.none
      : ErrorT.fromValue(errPtr.ref.klass);

  throw Libgit2Exception._from(
    code: code,
    message: message ?? 'libgit2 error $code',
    klass: klass,
  );
}

ErrorCode _safeErrorCode(int code) {
  for (final v in ErrorCode.values) {
    if (v.value == code) return v;
  }
  return .error;
}

/// A libgit2 C-function result: the `int` return code paired with a
/// value that is only meaningful when the code is non-negative.
///
/// Use [check] to validate the code and unwrap the value in one step,
/// or [checkCode] to validate the code on its own.
typedef CResult<T> = (int code, T value);

/// Generic libgit2 return code.
///
/// Discriminates the category of failure that produced a
/// [Libgit2Exception]. Most callers match on one of the dedicated
/// subclasses instead of inspecting [Libgit2Exception.code] directly.
typedef Libgit2Error = ErrorCode;

/// Error thrown by every libgit2 call that fails.
///
/// Carries extra details of the last error that occurred on the
/// current thread. More specific subclasses are thrown for the
/// common error codes — [NotFoundException], [ExistsException],
/// [AmbiguousException], [InvalidValueException], [BareRepoException],
/// [UnbornBranchException], [ConflictException], [UserException] and
/// [OutOfMemoryException]. Match on those when you want to handle a
/// specific failure, and fall back to [Libgit2Exception] for anything
/// else.
///
/// ```dart
/// try {
///   final branch = Branch.lookup(repo, 'missing', BranchType.local);
///   branch.dispose();
/// } on NotFoundException {
///   print('no such branch');
/// } on Libgit2Exception catch (e) {
///   print('libgit2 error ${e.code}: ${e.message}');
/// }
/// ```
class Libgit2Exception implements Exception {
  /// Human-readable description of what went wrong.
  final String message;

  /// Generic return code reported by libgit2.
  final Libgit2Error code;

  /// Subsystem that produced the error (e.g. `ErrorT.odb`,
  /// `ErrorT.net`, `ErrorT.ssl`).
  final ErrorT klass;

  const Libgit2Exception({
    required this.message,
    required this.code,
    this.klass = ErrorT.none,
  });

  factory Libgit2Exception._from({
    required int code,
    required String message,
    ErrorT klass = ErrorT.none,
  }) {
    final errorCode = _safeErrorCode(code);
    return switch (errorCode) {
      .enotfound => NotFoundException(message: message, klass: klass),
      .eexists => ExistsException(message: message, klass: klass),
      .eambiguous => AmbiguousException(message: message, klass: klass),
      .einvalid ||
      .einvalidspec => InvalidValueException(message: message, klass: klass),
      .ebarerepo => BareRepoException(message: message, klass: klass),
      .eunbornbranch => UnbornBranchException(message: message, klass: klass),
      .econflict ||
      .emergeconflict => ConflictException(message: message, klass: klass),
      .euser => UserException(message: message, klass: klass),
      _ =>
        errorCode == .error && klass == .nomemory
            ? OutOfMemoryException(message: message, klass: klass)
            : Libgit2Exception(message: message, code: errorCode, klass: klass),
    };
  }

  @override
  String toString() => message;
}

/// Thrown when a requested object could not be found.
class NotFoundException extends Libgit2Exception {
  const NotFoundException({
    super.message = 'Requested object could not be found.',
    super.klass,
  }) : super(code: .enotfound);
}

/// Thrown when an object exists and prevents the operation.
class ExistsException extends Libgit2Exception {
  const ExistsException({
    super.message = 'Object exists preventing operation.',
    super.klass,
  }) : super(code: .eexists);
}

/// Thrown when more than one object matches a lookup.
class AmbiguousException extends Libgit2Exception {
  const AmbiguousException({
    super.message = 'More than one object matches.',
    super.klass,
  }) : super(code: .eambiguous);
}

/// Thrown when an operation receives an invalid input — an
/// out-of-range argument, a malformed name or refspec, or a value
/// libgit2 cannot interpret.
class InvalidValueException extends Libgit2Exception {
  const InvalidValueException({
    super.message = 'Invalid operation or input.',
    super.klass,
  }) : super(code: .einvalid);
}

/// Thrown when libgit2 could not allocate memory for the operation.
class OutOfMemoryException extends Libgit2Exception {
  const OutOfMemoryException({
    super.message = 'Memory allocation failed.',
    super.klass = ErrorT.nomemory,
  }) : super(code: .error);
}

/// Thrown when an operation that requires a working directory is
/// attempted on a bare repository.
class BareRepoException extends Libgit2Exception {
  const BareRepoException({
    super.message = 'Operation not allowed on bare repository.',
    super.klass,
  }) : super(code: .ebarerepo);
}

/// Thrown when HEAD refers to a branch that has no commits yet.
class UnbornBranchException extends Libgit2Exception {
  const UnbornBranchException({
    super.message = 'HEAD refers to branch with no commits.',
    super.klass,
  }) : super(code: .eunbornbranch);
}

/// Thrown when checkout, merge, cherry-pick or a similar operation
/// cannot proceed because of conflicts.
class ConflictException extends Libgit2Exception {
  const ConflictException({
    super.message = 'Conflicts prevented operation.',
    super.klass,
  }) : super(code: .econflict);
}

/// Thrown when a user-supplied callback signals that it refuses to
/// act, typically to stop an iteration or abort a transfer.
class UserException extends Libgit2Exception {
  const UserException({
    super.message = 'A user-configured callback refused to act.',
    super.klass,
  }) : super(code: .euser);
}

extension NativeString on Pointer<Char> {
  String toDartString() {
    if (this == nullptr) return '';
    return cast<Utf8>().toDartString();
  }
}
