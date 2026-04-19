part of 'api.dart';

/// A SHA-1 object identifier: the unique 20-byte name of any commit,
/// tree, blob, or tag stored in a Git object database.
///
/// [Oid] is an immutable value type backed by a private copy of the
/// 20 SHA-1 bytes. There is no `dispose()` to call; equality is
/// byte-for-byte and [hashCode] is stable across instances that
/// represent the same object.
///
/// ```dart
/// final id = Oid.fromString('5b5b025afb0b4c913b4c338a42934a3863bf3644');
/// print(id.sha);          // 5b5b025afb0b4c913b4c338a42934a3863bf3644
/// print(id.shortSha());   // 5b5b025
/// print(id.loosePath);    // 5b/5b025afb0b4c913b4c338a42934a3863bf3644
/// print(id.isZero);       // false
/// ```
@immutable
final class Oid implements Comparable<Oid> {
  /// Number of raw bytes in a SHA-1 OID.
  static const rawSize = oidRawSize;

  /// Number of hex characters in a formatted SHA-1 OID.
  static const hexSize = oidHexSize;

  /// Minimum hex prefix length accepted by libgit2 lookups.
  static const minPrefixLength = oidMinPrefixLen;

  /// String form of the all-zero null SHA-1 OID.
  static const hexZero = oidHexZero;

  static final _zero = Oid._(Uint8List(rawSize));

  final Uint8List _bytes;

  /// Copies a 20-byte raw SHA-1 buffer into a new [Oid].
  ///
  /// Throws [ArgumentError] when [raw] is not exactly [rawSize] bytes
  /// long.
  factory Oid.fromBytes(Uint8List raw) => Oid._(oidFromRaw(raw));

  /// Parses the first [length] characters of [hex] into an [Oid].
  ///
  /// Pulls a hex prefix out of a larger string buffer without
  /// allocating a substring. Bytes beyond `length / 2` are zero; an
  /// odd [length] stores the final nibble in the high half of the
  /// next byte and zeros the low half.
  ///
  /// Throws [ArgumentError] when [length] is negative or greater than
  /// the length of [hex]. Throws [Libgit2Exception] when [length] is
  /// greater than [hexSize] or the slice contains non-hex characters.
  factory Oid.fromHexN(String hex, int length) =>
      Oid._(oidFromStrn(hex, length));

  /// Parses a hex string of zero to [hexSize] characters.
  ///
  /// Use this for user-supplied short SHAs. Bytes beyond the input
  /// length are zero, an odd-length input stores its trailing nibble
  /// in the high half of the next byte, and an empty [hex] produces
  /// the null OID. [Oid.minPrefixLength] is the floor libgit2 uses
  /// when looking objects up by short SHA. Parsing itself accepts
  /// shorter prefixes.
  ///
  /// Throws [Libgit2Exception] when [hex] is longer than [hexSize] or
  /// contains non-hex characters.
  factory Oid.fromHexPrefix(String hex) => Oid._(oidFromStrp(hex));

  /// Parses a 40-character hex SHA-1 string.
  ///
  /// Accepts mixed-case input. Short prefixes belong on
  /// [Oid.fromHexPrefix] or [Oid.fromHexN].
  ///
  /// Throws [ArgumentError] when [hex] is not exactly [hexSize]
  /// characters long. Throws [Libgit2Exception] when [hex] contains
  /// non-hex characters.
  ///
  /// ```dart
  /// final id = Oid.fromString('5b5b025afb0b4c913b4c338a42934a3863bf3644');
  /// ```
  factory Oid.fromString(String hex) => Oid._(oidFromStr(hex));

  /// Returns the all-zero null OID.
  ///
  /// Git uses this value as a sentinel for "no object": the `old_id`
  /// of a brand-new reference and the `new_id` of a just-deleted one.
  factory Oid.zero() => _zero;

  const Oid._(this._bytes);

  /// A fresh copy of the 20 raw SHA-1 bytes.
  ///
  /// Mutating the returned buffer has no effect on this [Oid].
  Uint8List get bytes => Uint8List.fromList(_bytes);

  @override
  int get hashCode => Object.hashAll(_bytes);

  /// Whether this is the all-zero null OID.
  bool get isZero => oidIsZero(_bytes);

  /// The loose-object path string for this OID (e.g. `5b/5b025...`).
  ///
  /// The first two hex digits form the directory and the remaining 38
  /// form the file name, matching how Git stores loose objects on disk.
  String get loosePath => oidPathfmt(_bytes);

  /// The full 40-character lowercase hex string of this OID.
  String get sha => oidFmt(_bytes);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Oid) return false;
    if (_bytes.length != other._bytes.length) return false;
    for (var i = 0; i < _bytes.length; i++) {
      if (_bytes[i] != other._bytes[i]) return false;
    }
    return true;
  }

  /// Compares the first [hexLength] hex characters of this OID with
  /// [other].
  ///
  /// [hexLength] counts hex digits (4 bits each), so an odd value
  /// compares down to a single nibble. Returns 0 when the prefixes
  /// match. Use this to test short-SHA equality without formatting
  /// the OIDs back into hex strings.
  ///
  /// Throws [ArgumentError] when [hexLength] is negative.
  int compareHexPrefix(Oid other, int hexLength) =>
      oidNcmp(_bytes, other._bytes, hexLength);

  /// Compares this OID lexicographically with [other].
  ///
  /// Returns a negative value when this sorts before [other], zero
  /// when they are equal, and a positive value when this sorts after.
  @override
  int compareTo(Oid other) => oidCmp(_bytes, other._bytes);

  /// Lexicographically compares this OID with the hex string [hex].
  ///
  /// Returns a negative value when this sorts before [hex], zero on a
  /// match, and a positive value when this sorts after. The same
  /// return is `-1` when [hex] is not valid hex; callers that need to
  /// distinguish that case should validate [hex] separately.
  int compareToHex(String hex) => oidStrcmp(_bytes, hex);

  /// Returns an equal but distinct [Oid] instance.
  ///
  /// Rarely needed. [Oid] is an immutable value type, so two
  /// instances constructed from the same bytes already compare
  /// equal and share no mutable state.
  Oid copy() => Oid._(oidCpy(_bytes));

  /// Whether this OID equals the hex string [hex].
  ///
  /// Returns false when [hex] is not a valid 40-character hex SHA-1 or
  /// the values differ.
  bool equalsHex(String hex) => oidStreq(_bytes, hex);

  /// Formats this OID as hex capped at `bufferSize - 1` characters.
  ///
  /// A [bufferSize] of `hexSize + 1` (41 for SHA-1) returns the full
  /// 40-character SHA; smaller values return a shorter prefix.
  /// Returns the empty string when [bufferSize] is zero.
  ///
  /// Throws [ArgumentError] when [bufferSize] is negative.
  String formatTruncated(int bufferSize) => oidTostr(_bytes, bufferSize);

  /// Returns the first [length] characters of [sha] (default `7`).
  ///
  /// A [length] of `0` returns the empty string. Values between `1`
  /// and [hexSize] return exactly that many hex characters. Values
  /// greater than [hexSize] are clamped, so the result is never
  /// longer than the full 40-character [sha].
  ///
  /// Throws [ArgumentError] when [length] is negative.
  String shortSha([int length = 7]) => oidNfmt(_bytes, length);

  /// Returns the full [sha] of this OID.
  @override
  String toString() => oidTostrS(_bytes);
}

/// An incremental OID shortener.
///
/// Computes the minimum hex prefix length needed to uniquely identify
/// every OID added to the set, mirroring `git log --abbrev`. OIDs are
/// added one at a time with [add], and each call returns the prefix
/// length that distinguishes every OID added so far. The shortener
/// has a hard cap of roughly 32 000 entries on a mostly-random
/// distribution; further additions throw [InvalidValueException].
///
/// Call [dispose] when you're finished with the shortener so its
/// underlying state is released.
///
/// ```dart
/// final shortener = OidShortener(minLength: 7);
/// shortener.add('5b5b025afb0b4c913b4c338a42934a3863bf3644');
/// final n = shortener.add('aa5b025afb0b4c913b4c338a42934a3863bf3644');
/// print(n); // 7 (only the first hex digit needs to differ)
/// shortener.dispose();
/// ```
final class OidShortener {
  static final _finalizer = Finalizer<int>(oidShortenFree);

  final int _handle;

  /// Creates a new shortener that never returns prefixes shorter
  /// than [minLength] characters.
  ///
  /// [minLength] is a hard floor: it is honoured even when a shorter
  /// prefix would already be unique across every OID in the set.
  /// Defaults to [Oid.minPrefixLength], the floor Git's own short
  /// SHA lookups use.
  ///
  /// Throws [ArgumentError] when [minLength] is negative. Throws
  /// [OutOfMemoryException] when the shortener cannot be allocated.
  factory OidShortener({int minLength = Oid.minPrefixLength}) =>
      OidShortener._(oidShortenNew(minLength));

  OidShortener._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Adds the hex [textId] to the set and returns the new minimum
  /// prefix length needed to distinguish every OID added so far.
  ///
  /// [textId] must be a 40-character hex SHA-1 string. The returned
  /// length is bounded below by the `minLength` passed to the
  /// constructor and above by [Oid.hexSize].
  ///
  /// Throws [InvalidValueException] when the shortener has hit its
  /// hard cap of roughly 32 000 entries.
  int add(String textId) => oidShortenAdd(_handle, textId);

  /// Releases the native shortener.
  void dispose() {
    _finalizer.detach(this);
    oidShortenFree(_handle);
  }
}
