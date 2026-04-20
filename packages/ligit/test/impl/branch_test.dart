@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Branch', () {
    late GitFixture git;
    late Repository repo;
    late Oid headId;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      headId = git.commit('initial', files: {'a.txt': 'hello\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('lookup', () {
      test('returns the local branch by short name', () {
        final branch = Branch.lookup(repo, 'main', BranchType.local);
        addTearDown(branch.dispose);

        expect(branch.name, 'main');
        expect(branch.isHead, isTrue);
      });

      test('throws NotFoundException for a missing branch', () {
        expect(
          () => Branch.lookup(repo, 'no-such-branch', BranchType.local),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('create', () {
      test('makes a new branch at the given commit', () {
        final tip = Commit.lookup(repo, headId);
        addTearDown(tip.dispose);

        final branch = Branch.create(repo: repo, name: 'feature', target: tip);
        addTearDown(branch.dispose);

        expect(branch.name, 'feature');
        expect(branch.isHead, isFalse);
      });

      test('throws ExistsException without force when name is taken', () {
        final tip = Commit.lookup(repo, headId);
        addTearDown(tip.dispose);

        Branch.create(repo: repo, name: 'taken', target: tip).dispose();

        expect(
          () => Branch.create(repo: repo, name: 'taken', target: tip),
          throwsA(isA<ExistsException>()),
        );
      });
    });

    group('createFromAnnotated', () {
      test('creates a branch from an annotated commit', () {
        final ac = AnnotatedCommit.fromRevSpec(repo, 'HEAD');
        addTearDown(ac.dispose);

        final branch = Branch.createFromAnnotated(
          repo: repo,
          name: 'from-annotated',
          target: ac,
        );
        addTearDown(branch.dispose);

        expect(branch.name, 'from-annotated');
        expect(branch.isHead, isFalse);
      });
    });

    group('rename', () {
      test('moves a branch to a new name', () {
        final tip = Commit.lookup(repo, headId);
        addTearDown(tip.dispose);

        final original = Branch.create(
          repo: repo,
          name: 'original',
          target: tip,
        );
        addTearDown(original.dispose);

        final moved = original.rename('renamed');
        addTearDown(moved.dispose);

        expect(moved.name, 'renamed');
      });
    });

    group('delete', () {
      test('removes the branch from the repository', () {
        final tip = Commit.lookup(repo, headId);
        addTearDown(tip.dispose);

        final trash = Branch.create(repo: repo, name: 'trash', target: tip);
        addTearDown(trash.dispose);

        trash.delete();
        expect(
          () => Branch.lookup(repo, 'trash', BranchType.local),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('isCheckedOut', () {
      test('main is checked out in the only worktree', () {
        final branch = Branch.lookup(repo, 'main', BranchType.local);
        addTearDown(branch.dispose);

        expect(branch.isCheckedOut, isTrue);
      });

      test('a newly created branch is not checked out', () {
        final tip = Commit.lookup(repo, headId);
        addTearDown(tip.dispose);

        final branch = Branch.create(
          repo: repo,
          name: 'not-checked-out',
          target: tip,
        );
        addTearDown(branch.dispose);

        expect(branch.isCheckedOut, isFalse);
      });
    });

    group('nameIsValid', () {
      test('accepts well-formed names and rejects malformed ones', () {
        expect(Branch.nameIsValid('feature/x'), isTrue);
        expect(Branch.nameIsValid(''), isFalse);
        expect(Branch.nameIsValid('has space'), isFalse);
      });
    });

    group('==', () {
      test('two lookups of the same branch compare equal', () {
        final a = Branch.lookup(repo, 'main', BranchType.local);
        addTearDown(a.dispose);
        final b = Branch.lookup(repo, 'main', BranchType.local);
        addTearDown(b.dispose);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });
    });
  });

  group('RepositoryBranch', () {
    late GitFixture git;
    late Repository repo;
    late Oid headId;

    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      headId = git.commit('initial', files: {'a.txt': 'hello\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('branches', () {
      test('lists every local branch', () {
        final tip = Commit.lookup(repo, headId);
        addTearDown(tip.dispose);

        Branch.create(repo: repo, name: 'iter-a', target: tip).dispose();
        Branch.create(repo: repo, name: 'iter-b', target: tip).dispose();

        final all = repo.branches();
        final names = all.where((b) => b.name != '').map((b) {
          addTearDown(b.dispose);
          return b.name;
        }).toList();

        expect(names, containsAll(['iter-a', 'iter-b', 'main']));
      });
    });

    group('upstream and remote', () {
      late GitFixture bare;
      late Repository bareRepo;

      setUp(() {
        bare = GitFixture.init();
        // Seed the bare repo so it has objects.
        bare.commit('initial', files: {'a.txt': 'hello\n'});
        bareRepo = Repository.open(bare.path);

        // Add bare as a remote named 'origin' and fetch.
        git.git(['remote', 'add', 'origin', bare.path]);
        git.git(['fetch', 'origin']);
        git.git(['config', 'branch.main.remote', 'origin']);
        git.git(['config', 'branch.main.merge', 'refs/heads/main']);
      });

      tearDown(() {
        bareRepo.dispose();
        bare.dispose();
      });

      group('upstream', () {
        test('resolves the remote-tracking branch for a local branch', () {
          repo.dispose();
          repo = Repository.open(git.path);

          final local = Branch.lookup(repo, 'main', BranchType.local);
          addTearDown(local.dispose);

          final up = local.upstream();
          addTearDown(up.dispose);

          expect(up.name, contains('main'));
        });
      });

      group('upstreamMergeFor / upstreamRemoteFor', () {
        test('returns the configured merge and remote values', () {
          repo.dispose();
          repo = Repository.open(git.path);

          expect(repo.upstreamMergeFor('refs/heads/main'), 'refs/heads/main');
          expect(repo.upstreamRemoteFor('refs/heads/main'), 'origin');
        });
      });

      group('remoteNameFor', () {
        test('extracts the remote name from a remote-tracking refname', () {
          repo.dispose();
          repo = Repository.open(git.path);

          expect(repo.remoteNameFor('refs/remotes/origin/main'), 'origin');
        });
      });
    });
  });
}
