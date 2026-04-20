import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

void main() {
  group('Libgit2Version', () {
    const v190 = Libgit2Version(major: 1, minor: 9, revision: 0);
    const v192 = Libgit2Version(major: 1, minor: 9, revision: 2);
    const v192dup = Libgit2Version(major: 1, minor: 9, revision: 2);
    const v200 = Libgit2Version(major: 2, minor: 0, revision: 0);
    const v192p1 = Libgit2Version(major: 1, minor: 9, revision: 2, patch: 1);

    group('number', () {
      test('equals major*1_000_000 + minor*10_000 + revision*100', () {
        expect(v192.number, 1090200);
        expect(v200.number, 2000000);
      });
    });

    group('toString', () {
      test('prints the dotted triple when patch is zero', () {
        expect(v192.toString(), '1.9.2');
      });

      test('appends the patch when non zero', () {
        expect(v192p1.toString(), '1.9.2.1');
      });
    });

    group('compareTo', () {
      test('orders versions lexicographically across components', () {
        expect(v190.compareTo(v192), isNegative);
        expect(v192.compareTo(v190), isPositive);
        expect(v192.compareTo(v192dup), isZero);
        expect(v192.compareTo(v200), isNegative);
        expect(v192.compareTo(v192p1), isNegative);
      });
    });

    group('check', () {
      test('returns true when this is at least as recent as other', () {
        expect(v192.check(v190), isTrue);
        expect(v192.check(v192dup), isTrue);
        expect(v192p1.check(v192), isTrue);
      });

      test('returns false when this is strictly older than other', () {
        expect(v190.check(v192), isFalse);
        expect(v192.check(v200), isFalse);
      });
    });

    group('==', () {
      test('two versions with the same components are equal', () {
        expect(v192, equals(v192dup));
        expect(v192.hashCode, v192dup.hashCode);
      });

      test('different components are not equal', () {
        expect(v192, isNot(equals(v190)));
        expect(v192, isNot(equals(v192p1)));
      });
    });
  });

  group('Libgit2.version', () {
    test('matches the binding-layer component constants', () {
      expect(Libgit2.version.major, greaterThanOrEqualTo(0));
      expect(
        Libgit2.version.number,
        Libgit2.version.major * 1000000 +
            Libgit2.version.minor * 10000 +
            Libgit2.version.revision * 100,
      );
    });

    test('check returns true for strictly lower required versions', () {
      expect(
        Libgit2.version.check(
          const Libgit2Version(major: 0, minor: 0, revision: 0),
        ),
        isTrue,
      );
    });

    test('check returns false for a clearly higher required version', () {
      expect(
        Libgit2.version.check(
          Libgit2Version(
            major: Libgit2.version.major + 1,
            minor: 0,
            revision: 0,
          ),
        ),
        isFalse,
      );
    });
  });

  group('Libgit2.soversion', () {
    test('is a non-empty string', () {
      expect(Libgit2.soversion, isNotEmpty);
    });
  });
}
