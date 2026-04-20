@Tags(['ffi'])
library;

import 'dart:io';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('RepositoryStash', () {
    late GitFixture git;
    late Repository repo;
    late Signature sig;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('initial', files: {'a.txt': 'clean\n'});
      // Dirty the worktree without staging.
      File('${git.path}/a.txt').writeAsStringSync('dirty\n');
      repo = Repository.open(git.path);
      sig = Signature(
        name: 'Ada',
        email: 'ada@example.com',
        when: DateTime.utc(2021),
      );
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('stash', () {
      test('saves dirty changes and restores a clean worktree', () {
        expect(File('${git.path}/a.txt').readAsStringSync(), 'dirty\n');

        repo.stash(stasher: sig, message: 'wip');

        expect(File('${git.path}/a.txt').readAsStringSync(), 'clean\n');
      });

      test('throws NotFoundException when there is nothing to stash', () {
        repo.stash(stasher: sig);
        expect(
          () => repo.stash(stasher: sig),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('applyStash', () {
      test('reapplies stashed changes without removing the entry', () {
        repo.stash(stasher: sig, message: 'wip');

        repo.applyStash(0);

        expect(File('${git.path}/a.txt').readAsStringSync(), 'dirty\n');
        // Entry still exists — drop should succeed.
        expect(() => repo.dropStash(0), returnsNormally);
      });
    });

    group('dropStash', () {
      test('removes the stash entry at the given index', () {
        repo.stash(stasher: sig, message: 'wip');

        repo.dropStash(0);

        expect(() => repo.dropStash(0), throwsA(isA<NotFoundException>()));
      });
    });

    group('popStash', () {
      test('applies and removes in one step', () {
        repo.stash(stasher: sig);

        repo.popStash(0);

        expect(File('${git.path}/a.txt').readAsStringSync(), 'dirty\n');
        expect(() => repo.dropStash(0), throwsA(isA<NotFoundException>()));
      });
    });

    group('forEachStash', () {
      test('visits each stash entry with its index and message', () {
        repo.stash(stasher: sig, message: 'first');
        File('${git.path}/a.txt').writeAsStringSync('more\n');
        repo.stash(stasher: sig, message: 'second');

        final messages = <String>[];
        repo.forEachStash((index, message, stashId) {
          messages.add(message);
          return 0;
        });

        expect(messages, containsAll([contains('second'), contains('first')]));
      });
    });
  });
}
