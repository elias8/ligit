@Tags(['ffi'])
library;

import 'dart:io';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  late GitFixture git;
  late Repository repo;
  late String worktreeParent;

  setUpAll(Libgit2.init);

  tearDownAll(Libgit2.shutdown);

  setUp(() {
    git = GitFixture.init();
    git.commit('initial', files: {'a.txt': 'hello\n'});
    worktreeParent = createTempDir();
    repo = Repository.open(git.path);
  });

  tearDown(() {
    repo.dispose();
    git.dispose();
    deleteTempDir(worktreeParent);
  });

  group('Worktree', () {
    group('add / lookup', () {
      test('adds a worktree and looks it up by name', () {
        final wtPath = '$worktreeParent/feature';
        final wt = Worktree.add(repo, 'feature', wtPath);
        addTearDown(wt.dispose);

        expect(wt.name, 'feature');
        expect(wt.path, endsWith('feature'));
        expect(wt.isValid, isTrue);

        final looked = Worktree.lookup(repo, 'feature');
        addTearDown(looked.dispose);
        expect(looked, equals(wt));
      });

      test('throws NotFoundException for an unknown worktree', () {
        expect(
          () => Worktree.lookup(repo, 'missing'),
          throwsA(isA<NotFoundException>()),
        );
      });

      test('add with lock:true creates the worktree in a locked state', () {
        final wtPath = '$worktreeParent/locked';
        final wt = Worktree.add(repo, 'locked', wtPath, lock: true);
        addTearDown(wt.dispose);

        expect(wt.isLocked, isTrue);
      });

      test('add with checkoutExisting:true reuses an existing branch', () {
        // Create the branch first, then add a worktree that reuses it.
        final branchRef = Reference.create(
          repo: repo,
          name: 'refs/heads/existing',
          target: git.oid('HEAD'),
        );
        addTearDown(branchRef.dispose);

        final wtPath = '$worktreeParent/existing';
        final wt = Worktree.add(
          repo,
          'existing',
          wtPath,
          checkoutExisting: true,
        );
        addTearDown(wt.dispose);

        expect(wt.name, 'existing');
        expect(wt.isValid, isTrue);
      });

      test('add with reference: checks out the specified ref', () {
        // Create a branch ref to attach the worktree to.
        final branchRef = Reference.create(
          repo: repo,
          name: 'refs/heads/wt-branch',
          target: git.oid('HEAD'),
        );
        addTearDown(branchRef.dispose);

        final wtPath = '$worktreeParent/wt-branch';
        final wt = Worktree.add(
          repo,
          'wt-branch',
          wtPath,
          reference: branchRef,
        );
        addTearDown(wt.dispose);

        expect(wt.name, 'wt-branch');
        expect(wt.isValid, isTrue);
      });
    });

    group('lock / unlock', () {
      test('locks with a reason and unlocks', () {
        final wt = Worktree.add(repo, 'wip', '$worktreeParent/wip');
        addTearDown(wt.dispose);
        expect(wt.isLocked, isFalse);

        wt.lock(reason: 'usb stick unplugged');
        expect(wt.isLocked, isTrue);
        expect(wt.lockReason, 'usb stick unplugged');

        expect(wt.unlock(), isTrue);
        expect(wt.isLocked, isFalse);
        expect(wt.unlock(), isFalse);
      });
    });

    group('prune', () {
      test('prunes a worktree whose working directory is gone', () {
        final wtPath = '$worktreeParent/gone';
        final wt = Worktree.add(repo, 'gone', wtPath);
        addTearDown(wt.dispose);

        Directory(wtPath).deleteSync(recursive: true);
        expect(wt.isPrunable(), isTrue);

        wt.prune();
        expect(repo.worktreeNames(), isNot(contains('gone')));
      });
    });

    group('fromRepository', () {
      test('opens the worktree backing a linked repository', () {
        final wtPath = '$worktreeParent/linked';
        final wt = Worktree.add(repo, 'linked', wtPath);
        addTearDown(wt.dispose);

        final linkedRepo = Repository.open(wtPath);
        addTearDown(linkedRepo.dispose);

        final reopened = Worktree.fromRepository(linkedRepo);
        addTearDown(reopened.dispose);
        expect(reopened.name, 'linked');
      });
    });
  });

  group('RepositoryWorktree', () {
    group('worktreeNames', () {
      test('enumerates every linked worktree', () {
        final wt = Worktree.add(repo, 'feature', '$worktreeParent/feature');
        addTearDown(wt.dispose);

        expect(repo.worktreeNames(), contains('feature'));
      });
    });
  });
}
