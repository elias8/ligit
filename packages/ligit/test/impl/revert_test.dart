@Tags(['ffi'])
library;

import 'dart:io';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('RepositoryRevert', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('main1', files: {'a.txt': 'main\n'});
      git.commit('main2', files: {'a.txt': 'main2\n'});

      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('revert', () {
      test('applies the inverse of a commit to the worktree', () {
        final head = Commit.lookup(repo, git.oid('HEAD'));
        addTearDown(head.dispose);

        repo.revert(head);

        expect(File('${git.path}/a.txt').readAsStringSync(), 'main\n');
      });
    });

    group('revertCommit', () {
      test('returns a conflict-free index when reverting against self', () {
        final head = Commit.lookup(repo, git.oid('HEAD'));
        addTearDown(head.dispose);

        final index = repo.revertCommit(head, head);
        addTearDown(index.dispose);

        expect(index.hasConflicts, isFalse);
      });
    });
  });
}
