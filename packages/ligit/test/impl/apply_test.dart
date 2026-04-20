@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('RepositoryApply', () {
    late GitFixture git;
    late Repository repo;
    late Oid first;
    late Oid second;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      first = git.commit('first', files: {'a.txt': 'a1\na2\n'});
      second = git.commit(
        'second',
        files: {'a.txt': 'a1\na2+\n', 'b.txt': 'b1\n'},
      );
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('apply', () {
      test('check mode succeeds without touching the workdir', () {
        final firstC = Commit.lookup(repo, first);
        addTearDown(firstC.dispose);
        final secondC = Commit.lookup(repo, second);
        addTearDown(secondC.dispose);
        final oldTree = firstC.tree();
        addTearDown(oldTree.dispose);
        final newTree = secondC.tree();
        addTearDown(newTree.dispose);
        final diff = Diff.treeToTree(
          repo: repo,
          oldTree: newTree,
          newTree: oldTree,
        );
        addTearDown(diff.dispose);

        repo.apply(diff, flags: {ApplyFlag.check});
      });
    });

    group('applyToTree', () {
      test('produces an index reflecting the diff applied to a tree', () {
        final firstC = Commit.lookup(repo, first);
        addTearDown(firstC.dispose);
        final secondC = Commit.lookup(repo, second);
        addTearDown(secondC.dispose);
        final oldTree = firstC.tree();
        addTearDown(oldTree.dispose);
        final newTree = secondC.tree();
        addTearDown(newTree.dispose);
        final diff = Diff.treeToTree(
          repo: repo,
          oldTree: oldTree,
          newTree: newTree,
        );
        addTearDown(diff.dispose);

        final index = repo.applyToTree(oldTree, diff);
        addTearDown(index.dispose);

        expect(index.getByPath('a.txt'), isNotNull);
        expect(index.getByPath('b.txt'), isNotNull);
      });
    });
  });
}
