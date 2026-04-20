@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

void main() {
  group('Refspec', () {
    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    group('parseFetch', () {
      test('reads source, destination, force flag, and direction', () {
        final spec = Refspec.parseFetch('+refs/heads/*:refs/remotes/origin/*');
        addTearDown(spec.dispose);

        expect(spec.source, 'refs/heads/*');
        expect(spec.destination, 'refs/remotes/origin/*');
        expect(spec.isForced, isTrue);
        expect(spec.direction, Direction.fetch);
      });
    });

    group('parsePush', () {
      test('recognizes a non-forced push direction', () {
        final spec = Refspec.parsePush('refs/heads/main:refs/heads/main');
        addTearDown(spec.dispose);

        expect(spec.isForced, isFalse);
        expect(spec.direction, Direction.push);
      });

      test('throws on an invalid refspec', () {
        expect(
          () => Refspec.parsePush('not a ref'),
          throwsA(isA<Libgit2Exception>()),
        );
      });
    });

    group('matchesSource', () {
      test('returns true when the source glob matches the reference', () {
        final spec = Refspec.parseFetch('refs/heads/*:refs/remotes/origin/*');
        addTearDown(spec.dispose);

        expect(spec.matchesSource('refs/heads/main'), isTrue);
        expect(spec.matchesSource('refs/tags/v1'), isFalse);
      });
    });

    group('matchesDestination', () {
      test('returns true when the destination glob matches the reference', () {
        final spec = Refspec.parseFetch('refs/heads/*:refs/remotes/origin/*');
        addTearDown(spec.dispose);

        expect(spec.matchesDestination('refs/remotes/origin/main'), isTrue);
        expect(spec.matchesDestination('refs/heads/main'), isFalse);
      });
    });

    group('matchesNegativeSource', () {
      test('excludes refs matched by a negative refspec', () {
        // A negative refspec uses a ^ prefix to exclude matching refs.
        final spec = Refspec.parseFetch('^refs/heads/private');
        addTearDown(spec.dispose);

        expect(spec.matchesNegativeSource('refs/heads/private'), isTrue);
        expect(spec.matchesNegativeSource('refs/heads/main'), isFalse);
      });
    });

    group('transform', () {
      test('maps a source name to its destination counterpart', () {
        final spec = Refspec.parseFetch('refs/heads/*:refs/remotes/origin/*');
        addTearDown(spec.dispose);

        expect(spec.transform('refs/heads/main'), 'refs/remotes/origin/main');
      });
    });

    group('reverseTransform', () {
      test('maps a destination name back to its source counterpart', () {
        final spec = Refspec.parseFetch('refs/heads/*:refs/remotes/origin/*');
        addTearDown(spec.dispose);

        expect(
          spec.reverseTransform('refs/remotes/origin/main'),
          'refs/heads/main',
        );
      });
    });

    group('==', () {
      test('two parses of the same input compare equal', () {
        final a = Refspec.parseFetch('refs/heads/*:refs/remotes/origin/*');
        addTearDown(a.dispose);
        final b = Refspec.parseFetch('refs/heads/*:refs/remotes/origin/*');
        addTearDown(b.dispose);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('different refspecs compare unequal', () {
        final a = Refspec.parseFetch('refs/heads/*:refs/remotes/origin/*');
        addTearDown(a.dispose);
        final b = Refspec.parseFetch('refs/heads/main:refs/heads/main');
        addTearDown(b.dispose);

        expect(a, isNot(equals(b)));
      });
    });
  });
}
