@Tags(['ffi'])
library;

import 'dart:io';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('RepositoryCherryPick', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('main1', files: {'a.txt': 'main\n'});
      git.git(['checkout', '-b', 'feature']);
      git.commit('feature1', files: {'b.txt': 'feature\n'});
      git.git(['checkout', 'main']);
      git.commit('main2', files: {'a.txt': 'main2\n'});

      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('cherryPick', () {
      test('replays a commit from another branch onto HEAD', () {
        final commit = Commit.lookup(repo, git.oid('refs/heads/feature'));
        addTearDown(commit.dispose);

        repo.cherryPick(commit);

        expect(File('${git.path}/b.txt').readAsStringSync(), 'feature\n');
      });
    });

    group('cherryPickCommit', () {
      test('returns an index previewing the cherry-pick', () {
        final picked = Commit.lookup(repo, git.oid('refs/heads/feature'));
        addTearDown(picked.dispose);
        final ours = Commit.lookup(repo, git.oid('HEAD'));
        addTearDown(ours.dispose);

        final index = repo.cherryPickCommit(picked, ours);
        addTearDown(index.dispose);

        expect(index.hasConflicts, isFalse);
      });
    });
  });
}
