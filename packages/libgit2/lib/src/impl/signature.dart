part of 'api.dart';

/// The actor (author or committer) behind a Git action, together
/// with the time the action took place.
///
/// [Signature] is a pure Dart value type. Construction goes through
/// libgit2 for validation (angle brackets in [name] or [email] are
/// rejected), but the resulting instance holds no native resources
/// and needs no `dispose()`.
///
/// ```dart
/// final sig = Signature.now(name: 'Ada', email: 'ada@example.com');
/// print(sig);      // Ada <ada@example.com>
/// print(sig.when); // close to DateTime.now()
/// ```
@immutable
final class Signature {
  /// Name of the person.
  final String name;

  /// Email of the person.
  final String email;

  /// Time the action took place (UTC, second precision).
  final DateTime when;

  /// UTC offset in minutes east that was recorded alongside [when].
  ///
  /// This is the original timezone offset the committer had at the
  /// time of the action. [when] is already in UTC; use [offset] only
  /// when you need to reconstruct the local time as it appeared to
  /// the committer.
  final int offset;

  /// Creates a signature with an explicit [when] timestamp.
  ///
  /// The [when] value is converted to UTC seconds since the epoch;
  /// sub-second precision is lost. [offset] is the timezone offset
  /// in minutes east of UTC that should be recorded alongside the
  /// timestamp.
  ///
  /// Angle brackets (`<` and `>`) are not allowed in [name] or
  /// [email].
  ///
  /// Throws [Libgit2Exception] when [name] or [email] is empty or
  /// contains angle brackets.
  factory Signature({
    required String name,
    required String email,
    required DateTime when,
    int offset = 0,
  }) {
    final epochSeconds = when.toUtc().millisecondsSinceEpoch ~/ 1000;
    final handle = signatureNew(name, email, epochSeconds, offset);
    final sig = Signature._fromHandle(handle);
    signatureFree(handle);
    return sig;
  }

  /// Parses a signature from the format
  /// `Real Name <email> timestamp tzoffset`.
  ///
  /// `timestamp` is seconds since the Unix epoch and `tzoffset` is
  /// `hhmm` (no colon). For example:
  /// `Ada Lovelace <ada@example.com> 1234567890 +0100`.
  ///
  /// Throws [InvalidValueException] when [buffer] is not parseable.
  factory Signature.fromBuffer(String buffer) {
    final handle = signatureFromBuffer(buffer);
    final sig = Signature._fromHandle(handle);
    signatureFree(handle);
    return sig;
  }

  /// Creates a signature stamped with the current system time and
  /// timezone.
  ///
  /// Throws [Libgit2Exception] when [name] or [email] is empty or
  /// contains angle brackets.
  factory Signature.now({required String name, required String email}) {
    final handle = signatureNow(name, email);
    final sig = Signature._fromHandle(handle);
    signatureFree(handle);
    return sig;
  }

  /// Creates a signature from `user.name`/`user.email` in [repo]'s
  /// configuration, stamped with the current time.
  ///
  /// Environment variables are ignored — use [Signature.defaultFromEnv]
  /// when `GIT_AUTHOR_*` or `GIT_COMMITTER_*` should override config.
  ///
  /// Throws [NotFoundException] when either `user.name` or
  /// `user.email` is unset.
  factory Signature.defaultFor(Repository repo) {
    final handle = signatureDefault(repo._handle);
    final sig = Signature._fromHandle(handle);
    signatureFree(handle);
    return sig;
  }

  /// Resolves default author and committer signatures for [repo],
  /// honoring `GIT_AUTHOR_*` and `GIT_COMMITTER_*` environment
  /// variables before falling back to configuration.
  ///
  /// At least one of [author] or [committer] must be true. When both
  /// are requested and neither `GIT_AUTHOR_DATE` nor
  /// `GIT_COMMITTER_DATE` is set, both signatures carry the same wall
  /// clock value.
  ///
  /// Throws [NotFoundException] when no source for name or email is
  /// available.
  static ({Signature? author, Signature? committer}) defaultFromEnv(
    Repository repo, {
    bool author = true,
    bool committer = true,
  }) {
    final raw = signatureDefaultFromEnv(
      repo._handle,
      wantAuthor: author,
      wantCommitter: committer,
    );
    Signature? build(int? handle) {
      if (handle == null) return null;
      final sig = Signature._fromHandle(handle);
      signatureFree(handle);
      return sig;
    }

    return (author: build(raw.author), committer: build(raw.committer));
  }

  const Signature._({
    required this.name,
    required this.email,
    required this.when,
    required this.offset,
  });

  factory Signature._fromHandle(int handle) {
    final r = signatureRead(handle);
    return Signature._(
      name: r.name,
      email: r.email,
      when: DateTime.fromMillisecondsSinceEpoch(r.time * 1000, isUtc: true),
      offset: r.offset,
    );
  }

  @override
  int get hashCode => Object.hash(name, email, when, offset);

  /// Internal flattened form used when other wrappers need to pass
  /// this signature to the binding layer.
  ({String name, String email, int time, int offset}) get _record {
    return (
      name: name,
      email: email,
      time: when.toUtc().millisecondsSinceEpoch ~/ 1000,
      offset: offset,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Signature &&
      name == other.name &&
      email == other.email &&
      when == other.when &&
      offset == other.offset;

  /// Returns `name <email>`.
  @override
  String toString() => '$name <$email>';
}
