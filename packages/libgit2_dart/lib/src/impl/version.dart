part of 'api.dart';

/// A libgit2 version triple with an optional Windows DLL [patch]
/// bump.
///
/// Follows semantic versioning (v2). Value-typed and [Comparable], so
/// instances sort and compare structurally; [check] tests a minimum
/// version.
@immutable
final class Libgit2Version implements Comparable<Libgit2Version> {
  /// Major component.
  final int major;

  /// Minor component.
  final int minor;

  /// Revision (teeny) component.
  final int revision;

  /// Windows DLL patch number, bumped for respins between releases.
  /// Zero on every other build.
  final int patch;

  /// Creates a version triple from its components.
  const Libgit2Version({
    required this.major,
    required this.minor,
    required this.revision,
    this.patch = 0,
  });

  @override
  int get hashCode => Object.hash(major, minor, revision, patch);

  /// Integer encoding suitable for numeric comparison:
  /// `major * 1_000_000 + minor * 10_000 + revision * 100`.
  int get number => major * 1000000 + minor * 10000 + revision * 100;

  @override
  bool operator ==(Object other) =>
      other is Libgit2Version &&
      major == other.major &&
      minor == other.minor &&
      revision == other.revision &&
      patch == other.patch;

  /// Whether this version is at least as recent as [other].
  ///
  /// Returns `true` when `compareTo(other) >= 0`. Useful for gating
  /// code on a minimum required libgit2 version.
  bool check(Libgit2Version other) => compareTo(other) >= 0;

  /// Compares this version with [other] lexicographically across
  /// [major], [minor], [revision], then [patch].
  ///
  /// Returns a negative value when this sorts before [other], zero
  /// when equal, and a positive value when this sorts after.
  @override
  int compareTo(Libgit2Version other) {
    if (major != other.major) return major - other.major;
    if (minor != other.minor) return minor - other.minor;
    if (revision != other.revision) return revision - other.revision;
    return patch - other.patch;
  }

  /// Returns the dotted version string (`major.minor.revision`, or
  /// `major.minor.revision.patch` when [patch] is non-zero).
  @override
  String toString() {
    if (patch == 0) return '$major.$minor.$revision';
    return '$major.$minor.$revision.$patch';
  }
}
