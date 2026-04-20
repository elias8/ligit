@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Mailmap', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit(
        'initial',
        files: {
          '.mailmap': 'Ada Lovelace <ada@new.example> <ada@old.example>\n',
        },
      );
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('fromString', () {
      test('resolves a name/email pair through a rule', () {
        final mm = Mailmap.fromString(
          'Ada Lovelace <ada@new.example> <ada@old.example>\n',
        );
        addTearDown(mm.dispose);

        expect(mm.resolve(name: 'Ada', email: 'ada@old.example'), (
          name: 'Ada Lovelace',
          email: 'ada@new.example',
        ));
      });
    });

    group('addEntry', () {
      test('programmatic mapping beats the passthrough default', () {
        final mm = Mailmap.empty();
        addTearDown(mm.dispose);

        mm.addEntry(
          realName: 'Ada',
          realEmail: 'ada@new.example',
          replaceEmail: 'ada@old.example',
        );

        expect(mm.resolve(name: 'x', email: 'ada@old.example'), (
          name: 'Ada',
          email: 'ada@new.example',
        ));
      });
    });

    group('fromRepository', () {
      test('reads the .mailmap file from the working directory', () {
        final mm = Mailmap.fromRepository(repo);
        addTearDown(mm.dispose);

        expect(mm.resolve(name: 'x', email: 'ada@old.example'), (
          name: 'Ada Lovelace',
          email: 'ada@new.example',
        ));
      });
    });

    group('resolveSignature', () {
      test('returns a new signature with canonical name and email', () {
        final mm = Mailmap.fromString(
          'Ada Lovelace <ada@new.example> <ada@old.example>\n',
        );
        addTearDown(mm.dispose);

        final input = Signature.now(name: 'x', email: 'ada@old.example');
        final resolved = mm.resolveSignature(input);

        expect(resolved.name, 'Ada Lovelace');
        expect(resolved.email, 'ada@new.example');
      });
    });

    group('passthrough', () {
      test('returns inputs unchanged when no mailmap is available', () {
        expect(Mailmap.passthrough(name: 'Ada', email: 'ada@x'), (
          name: 'Ada',
          email: 'ada@x',
        ));
      });
    });
  });

  group('CommitMailmapExt', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit(
        'initial',
        files: {
          '.mailmap':
              'Ada Lovelace <ada@new.example> Test <test@example.com>\n',
          'a.txt': 'hello\n',
        },
      );
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('authorWithMailmap', () {
      test('resolves the author through a supplied mailmap', () {
        final commit = Commit.lookup(repo, git.oid('HEAD'));
        addTearDown(commit.dispose);

        final mm = Mailmap.fromRepository(repo);
        addTearDown(mm.dispose);

        final resolved = commit.authorWithMailmap(mm);

        expect(resolved.name, 'Ada Lovelace');
        expect(resolved.email, 'ada@new.example');
      });
    });

    group('committerWithMailmap', () {
      test('resolves the committer through a supplied mailmap', () {
        final commit = Commit.lookup(repo, git.oid('HEAD'));
        addTearDown(commit.dispose);

        final mm = Mailmap.fromRepository(repo);
        addTearDown(mm.dispose);

        final resolved = commit.committerWithMailmap(mm);

        expect(resolved.name, 'Ada Lovelace');
        expect(resolved.email, 'ada@new.example');
      });
    });
  });
}
