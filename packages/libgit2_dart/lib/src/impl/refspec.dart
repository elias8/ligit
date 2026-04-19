part of 'api.dart';

/// A parsed refspec.
///
/// A refspec describes how one side of a fetch or push maps
/// references to the other — for example
/// `+refs/heads/*:refs/remotes/origin/*`. Parse one with
/// [Refspec.parseFetch] or [Refspec.parsePush] and then use the
/// accessors to query the parsed pieces, [matchesSource] /
/// [matchesDestination] to test reference names, and [transform] /
/// [reverseTransform] to map names across the `src:dst` boundary.
///
/// Instances own native memory and must be [dispose]d when no longer
/// needed. Two [Refspec] instances that parse the same input with
/// the same direction compare equal.
///
/// ```dart
/// final spec = Refspec.parseFetch('+refs/heads/*:refs/remotes/origin/*');
/// try {
///   print(spec.source);        // refs/heads/*
///   print(spec.destination);   // refs/remotes/origin/*
///   print(spec.isForced);      // true
///   spec.matchesSource('refs/heads/main');
/// } finally {
///   spec.dispose();
/// }
/// ```
@immutable
final class Refspec {
  static final _finalizer = Finalizer<int>(refspecFree);

  final int _handle;

  /// The original refspec string.
  final String raw;

  /// Parses [input] as a fetch refspec.
  ///
  /// Throws [Libgit2Exception] when [input] is not a valid refspec.
  factory Refspec.parseFetch(String input) {
    final handle = refspecParse(input, isFetch: true);
    return Refspec._(handle, refspecString(handle));
  }

  /// Parses [input] as a push refspec.
  ///
  /// Throws [Libgit2Exception] when [input] is not a valid refspec.
  factory Refspec.parsePush(String input) {
    final handle = refspecParse(input, isFetch: false);
    return Refspec._(handle, refspecString(handle));
  }

  Refspec._(this._handle, this.raw) {
    _finalizer.attach(this, _handle, detach: this);
  }

  @override
  int get hashCode => Object.hash(raw, direction);

  /// The source specifier — the left side of `src:dst`.
  String get source => refspecSrc(_handle);

  /// The destination specifier — the right side of `src:dst`.
  String get destination => refspecDst(_handle);

  /// Whether the refspec carries the `+` force-update prefix.
  bool get isForced => refspecForce(_handle);

  /// The direction (fetch or push) this refspec was parsed for.
  Direction get direction => refspecDirection(_handle);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Refspec && other.raw == raw && other.direction == direction);

  /// Releases the native refspec handle.
  void dispose() {
    _finalizer.detach(this);
    refspecFree(_handle);
  }

  /// Whether the source specifier matches the reference [refname].
  bool matchesSource(String refname) => refspecSrcMatches(_handle, refname);

  /// Whether the source specifier matches [refname] when interpreted
  /// as a negative (`^`-prefixed) refspec.
  bool matchesNegativeSource(String refname) =>
      refspecSrcMatchesNegative(_handle, refname);

  /// Whether the destination specifier matches the reference
  /// [refname].
  bool matchesDestination(String refname) =>
      refspecDstMatches(_handle, refname);

  /// Transforms [name] from source to destination following this
  /// refspec's rules.
  String transform(String name) => refspecTransform(_handle, name);

  /// Transforms [name] from destination back to source following
  /// this refspec's rules.
  String reverseTransform(String name) => refspecRtransform(_handle, name);

  @override
  String toString() => 'Refspec($raw)';
}
