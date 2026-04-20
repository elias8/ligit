@Tags(['ffi'])
library;

import 'dart:io';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('RepositoryCheckout', () {
    late GitFixture git;
    late Repository repo;
    late Oid firstId;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      firstId = git.commit(
        'first',
        files: {'a.txt': 'first\n', 'b.txt': 'b1\n'},
      );
      git.commit('second', files: {'a.txt': 'second\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('checkoutHead', () {
      test('overwrites local changes with force', () {
        File('${git.path}/a.txt').writeAsStringSync('dirty\n');
        repo.checkoutHead(strategies: {CheckoutStrategy.force});
        expect(File('${git.path}/a.txt').readAsStringSync(), 'second\n');
      });
    });

    group('checkoutTree', () {
      test('writes a different commit tree into the worktree', () {
        final treeish = GitObject.lookup(repo, firstId);
        addTearDown(treeish.dispose);

        repo.checkoutTree(treeish, strategies: {CheckoutStrategy.force});
        expect(File('${git.path}/a.txt').readAsStringSync(), 'first\n');
      });

      test('restricts the checkout to matching paths', () {
        File('${git.path}/b.txt').writeAsStringSync('dirty-b\n');
        File('${git.path}/a.txt').writeAsStringSync('dirty-a\n');

        final treeish = GitObject.lookup(repo, firstId);
        addTearDown(treeish.dispose);
        repo.checkoutTree(
          treeish,
          strategies: {CheckoutStrategy.force},
          paths: ['a.txt'],
        );

        expect(File('${git.path}/a.txt').readAsStringSync(), 'first\n');
        expect(File('${git.path}/b.txt').readAsStringSync(), 'dirty-b\n');
      });
    });

    group('checkoutIndex', () {
      test('writes index contents back to the working tree with force', () {
        // Stage a known content for a.txt without committing.
        File('${git.path}/a.txt').writeAsStringSync('indexed\n');
        git.git(['add', 'a.txt']);
        // Overwrite the file on disk to create a divergence.
        File('${git.path}/a.txt').writeAsStringSync('dirty-again\n');

        repo.checkoutIndex(strategies: {CheckoutStrategy.force});

        expect(File('${git.path}/a.txt').readAsStringSync(), 'indexed\n');
      });
    });
  });
}
