@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Signature', () {
    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    group('constructor', () {
      test('sets name, email, when, and offset', () {
        final when = DateTime.utc(2026, 4, 12, 12, 30);
        final sig = Signature(
          name: 'Ada Lovelace',
          email: 'ada@example.com',
          when: when,
          offset: 60,
        );

        expect(sig.name, 'Ada Lovelace');
        expect(sig.email, 'ada@example.com');
        expect(sig.when, when);
        expect(sig.offset, 60);
      });

      test('throws on invalid inputs', () {
        expect(
          () => Signature(name: '', email: 'a@b.com', when: DateTime.utc(2026)),
          throwsA(isA<Libgit2Exception>()),
        );
        expect(
          () => Signature(name: 'A', email: '', when: DateTime.utc(2026)),
          throwsA(isA<Libgit2Exception>()),
        );
        expect(
          () => Signature(
            name: 'A <B>',
            email: 'a@b.com',
            when: DateTime.utc(2026),
          ),
          throwsA(isA<Libgit2Exception>()),
        );
      });
    });

    group('now', () {
      test('creates a signature near the current time', () {
        final sig = Signature.now(name: 'Test', email: 'test@example.com');
        final delta = DateTime.now().difference(sig.when).inSeconds.abs();

        expect(delta, lessThan(5));
        expect(sig.name, 'Test');
        expect(sig.email, 'test@example.com');
      });
    });

    group('fromBuffer', () {
      test('parses name, email, timestamp, and timezone offset', () {
        final sig = Signature.fromBuffer(
          'Ada Lovelace <ada@example.com> 1234567890 +0100',
        );

        expect(sig.name, 'Ada Lovelace');
        expect(sig.email, 'ada@example.com');
        expect(
          sig.when,
          DateTime.fromMillisecondsSinceEpoch(1234567890 * 1000, isUtc: true),
        );
        expect(sig.offset, 60);
      });

      test('throws on unparseable input', () {
        expect(
          () => Signature.fromBuffer('not a valid signature'),
          throwsA(isA<Libgit2Exception>()),
        );
      });
    });

    group('==', () {
      test('two signatures with the same fields are equal', () {
        final when = DateTime.utc(2026, 4, 12);
        final a = Signature(name: 'A', email: 'a@b.c', when: when);
        final b = Signature(name: 'A', email: 'a@b.c', when: when);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('different fields are not equal', () {
        final when = DateTime.utc(2026, 4, 12);
        final a = Signature(name: 'A', email: 'a@b.c', when: when);
        final b = Signature(
          name: 'A',
          email: 'a@b.c',
          when: when.add(const Duration(days: 1)),
        );

        expect(a, isNot(equals(b)));
      });
    });

    group('defaultFor', () {
      test('reads user.name and user.email from config', () {
        final git = GitFixture.init();
        addTearDown(git.dispose);
        git.git(['config', 'user.name', 'Ada']);
        git.git(['config', 'user.email', 'ada@example.com']);
        final repo = Repository.open(git.path);
        addTearDown(repo.dispose);

        final sig = Signature.defaultFor(repo);

        expect(sig.name, 'Ada');
        expect(sig.email, 'ada@example.com');
      });
    });

    group('defaultFromEnv', () {
      test('returns author and committer by default', () {
        final git = GitFixture.init();
        addTearDown(git.dispose);
        git.git(['config', 'user.name', 'Ada']);
        git.git(['config', 'user.email', 'ada@example.com']);
        final repo = Repository.open(git.path);
        addTearDown(repo.dispose);

        final pair = Signature.defaultFromEnv(repo);

        expect(pair.author!.name, 'Ada');
        expect(pair.committer!.email, 'ada@example.com');
      });

      test('omits signatures not requested', () {
        final git = GitFixture.init();
        addTearDown(git.dispose);
        git.git(['config', 'user.name', 'Ada']);
        git.git(['config', 'user.email', 'ada@example.com']);
        final repo = Repository.open(git.path);
        addTearDown(repo.dispose);

        final pair = Signature.defaultFromEnv(repo, committer: false);

        expect(pair.author, isNotNull);
        expect(pair.committer, isNull);
      });
    });
  });
}
