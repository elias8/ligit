@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

const _shaA = '5b5b025afb0b4c913b4c338a42934a3863bf3644';
const _shaB = 'aa5b025afb0b4c913b4c338a42934a3863bf3644';
const _shaZero = '0000000000000000000000000000000000000000';

void main() {
  group('Oid', () {
    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    group('fromString', () {
      test('parses a 40-character hex SHA into the same hex form', () {
        final id = Oid.fromString(_shaA);
        expect(id.sha, _shaA);
        expect(id.bytes, hasLength(Oid.rawSize));
      });

      test('throws ArgumentError on the wrong length', () {
        expect(() => Oid.fromString('5b5b025'), throwsA(isA<ArgumentError>()));
      });

      test('throws Libgit2Exception on non-hex characters', () {
        expect(
          () => Oid.fromString('zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz'),
          throwsA(isA<Libgit2Exception>()),
        );
      });
    });

    group('fromHexPrefix', () {
      test('parses a short hex prefix and zero-pads the remainder', () {
        final id = Oid.fromHexPrefix('5b5b02');
        expect(id.shortSha(6), '5b5b02');
        expect(id.bytes.skip(3).every((b) => b == 0), isTrue);
      });
    });

    group('fromHexN', () {
      test('parses the first N characters from a longer string', () {
        final id = Oid.fromHexN('${_shaA}garbage', Oid.hexSize);
        expect(id.sha, _shaA);
      });

      test('throws ArgumentError when length is out of range', () {
        expect(
          () => Oid.fromHexN(_shaA, _shaA.length + 1),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('fromBytes', () {
      test('round-trips a 20-byte raw buffer', () {
        final raw = Oid.fromString(_shaA).bytes;
        final id = Oid.fromBytes(raw);
        expect(id.sha, _shaA);
      });

      test('throws ArgumentError on the wrong byte count', () {
        expect(
          () => Oid.fromBytes(Uint8List(19)),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('zero', () {
      test('returns the all-zero null OID', () {
        final id = Oid.zero();
        expect(id.isZero, isTrue);
        expect(id.sha, _shaZero);
        expect(Oid.hexZero, _shaZero);
      });

      test('shares a single instance', () {
        expect(identical(Oid.zero(), Oid.zero()), isTrue);
      });
    });

    group('copy', () {
      test('produces an equal but distinct instance', () {
        final a = Oid.fromString(_shaA);
        final b = a.copy();
        expect(b, equals(a));
        expect(identical(a, b), isFalse);
      });
    });

    group('sha', () {
      test('returns the full lowercase 40-character form', () {
        expect(Oid.fromString(_shaA).sha, _shaA);
      });
    });

    group('shortSha', () {
      test('defaults to 7 hex characters', () {
        expect(Oid.fromString(_shaA).shortSha(), _shaA.substring(0, 7));
      });

      test('honours an explicit length', () {
        expect(Oid.fromString(_shaA).shortSha(12), _shaA.substring(0, 12));
      });

      test('returns an empty string for length zero', () {
        expect(Oid.fromString(_shaA).shortSha(0), isEmpty);
      });
    });

    group('formatTruncated', () {
      test('truncates to bufferSize - 1 hex characters', () {
        expect(Oid.fromString(_shaA).formatTruncated(8), _shaA.substring(0, 7));
      });

      test('returns the full SHA when the buffer is large enough', () {
        expect(Oid.fromString(_shaA).formatTruncated(Oid.hexSize + 1), _shaA);
      });
    });

    group('loosePath', () {
      test('returns the "aa/..." loose-object path', () {
        final path = Oid.fromString(_shaA).loosePath;
        expect(path, '${_shaA.substring(0, 2)}/${_shaA.substring(2)}');
        expect(path, hasLength(41));
      });
    });

    group('isZero', () {
      test('is true for the null OID and false otherwise', () {
        expect(Oid.fromString(_shaZero).isZero, isTrue);
        expect(Oid.fromString(_shaA).isZero, isFalse);
      });
    });

    group('compareTo', () {
      test('orders OIDs lexicographically', () {
        final a = Oid.fromString(_shaA);
        final b = Oid.fromString(_shaB);
        expect(a.compareTo(b), isNegative);
        expect(b.compareTo(a), isPositive);
        expect(a.compareTo(a), isZero);
      });
    });

    group('compareHexPrefix', () {
      test('returns 0 when the leading hex chars match', () {
        final a = Oid.fromString(_shaA);
        final b = Oid.fromHexPrefix('5b5b02');
        expect(a.compareHexPrefix(b, 6), isZero);
      });

      test('returns non-zero when the prefixes diverge', () {
        final a = Oid.fromString(_shaA);
        final b = Oid.fromString(_shaB);
        expect(a.compareHexPrefix(b, 2), isNot(0));
      });
    });

    group('equalsHex', () {
      test('matches the formatted SHA and rejects others', () {
        final id = Oid.fromString(_shaA);
        expect(id.equalsHex(_shaA), isTrue);
        expect(id.equalsHex(_shaB), isFalse);
        expect(id.equalsHex('not-hex'), isFalse);
      });
    });

    group('compareToHex', () {
      test('matches compareTo for valid hex inputs', () {
        final a = Oid.fromString(_shaA);
        expect(a.compareToHex(_shaA), isZero);
        expect(a.compareToHex(_shaB), isNegative);
      });
    });

    group('==', () {
      test('equal SHAs compare equal with matching hashCode; '
          'different SHAs are not equal', () {
        final a = Oid.fromString(_shaA);
        final b = Oid.fromString(_shaA);
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
        expect(Oid.fromString(_shaA), isNot(equals(Oid.fromString(_shaB))));
      });
    });
  });

  group('OidShortener', () {
    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    group('add', () {
      test('returns the minimal length to distinguish two OIDs', () {
        final shortener = OidShortener(minLength: 1);
        addTearDown(shortener.dispose);

        shortener.add(_shaA);
        final n = shortener.add(_shaB);

        expect(n, greaterThanOrEqualTo(1));
        expect(n, lessThanOrEqualTo(Oid.hexSize));
      });

      test('respects the minimum length floor', () {
        final shortener = OidShortener(minLength: 7);
        addTearDown(shortener.dispose);

        expect(shortener.add(_shaA), greaterThanOrEqualTo(7));
      });
    });

    group('dispose', () {
      test('releases the native shortener', () {
        final shortener = OidShortener();
        shortener.dispose();
      });
    });
  });
}
