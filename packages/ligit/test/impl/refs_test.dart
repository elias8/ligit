@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Reference', () {
    late GitFixture git;
    late Repository repo;
    late Oid headCommitId;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      headCommitId = git.commit('initial', files: {'a.txt': 'hello\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('lookup', () {
      test('returns the branch reference by its full name', () {
        final ref = Reference.lookup(repo, 'refs/heads/main');
        addTearDown(ref.dispose);

        expect(ref.name, 'refs/heads/main');
        expect(ref.shorthand, 'main');
        expect(ref.target, headCommitId);
        expect(ref.isBranch, isTrue);
      });

      test('throws NotFoundException for a missing reference', () {
        expect(
          () => Reference.lookup(repo, 'refs/heads/does-not-exist'),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('dwim', () {
      test('resolves a short name to its full reference', () {
        final ref = Reference.dwim(repo, 'main');
        addTearDown(ref.dispose);

        expect(ref.name, 'refs/heads/main');
      });
    });

    group('create', () {
      test('creates a direct ref', () {
        final ref = Reference.create(
          repo: repo,
          name: 'refs/heads/feature',
          target: headCommitId,
        );
        addTearDown(ref.dispose);

        expect(repo.referenceNames(), contains('refs/heads/feature'));
      });
    });

    group('symbolicCreate', () {
      test('creates a symbolic ref pointing at another ref', () {
        final ref = Reference.symbolicCreate(
          repo: repo,
          name: 'refs/heads/alias',
          target: 'refs/heads/main',
        );
        addTearDown(ref.dispose);

        expect(ref.isSymbolic, isTrue);
        expect(ref.symbolicTarget, 'refs/heads/main');
      });
    });

    group('setTarget', () {
      test('advances a branch to a new commit', () {
        final git2 = GitFixture.init();
        addTearDown(git2.dispose);
        git2.commit('first', files: {'a.txt': 'one\n'});
        final secondId = git2.commit('second', files: {'a.txt': 'two\n'});
        final firstId = git2.oid('HEAD~');

        final repo2 = Repository.open(git2.path);
        addTearDown(repo2.dispose);

        final head = Reference.lookup(repo2, 'refs/heads/main');
        addTearDown(head.dispose);

        expect(head.target, secondId);
        final moved = head.setTarget(firstId);
        addTearDown(moved.dispose);

        expect(moved.target, firstId);
      });
    });

    group('delete', () {
      test('removes the reference via the instance handle', () {
        final ref = Reference.create(
          repo: repo,
          name: 'refs/heads/scratch',
          target: headCommitId,
        );
        addTearDown(ref.dispose);

        ref.delete();
        expect(repo.referenceNames(), isNot(contains('refs/heads/scratch')));
      });
    });

    group('nameIsValid', () {
      test('accepts and rejects by libgit2 grammar', () {
        expect(Reference.nameIsValid('refs/heads/x'), isTrue);
        expect(Reference.nameIsValid(''), isFalse);
      });
    });

    group('==', () {
      test('two lookups of the same ref compare equal', () {
        final a = Reference.lookup(repo, 'refs/heads/main');
        addTearDown(a.dispose);
        final b = Reference.lookup(repo, 'refs/heads/main');
        addTearDown(b.dispose);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });
    });
  });

  group('RepositoryReference', () {
    late GitFixture git;
    late Repository repo;
    late Oid headCommitId;

    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      headCommitId = git.commit('initial', files: {'a.txt': 'hello\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('referenceNames', () {
      test('returns every ref name', () {
        expect(repo.referenceNames(), contains('refs/heads/main'));
      });
    });

    group('resolveReferenceName', () {
      test('resolves a name straight to its OID', () {
        expect(repo.resolveReferenceName('refs/heads/main'), headCommitId);
      });
    });

    group('references', () {
      test('returns every reference in the repository', () {
        final refs = repo.references();
        for (final r in refs) {
          addTearDown(r.dispose);
        }

        expect(refs.map((r) => r.name), contains('refs/heads/main'));
      });
    });

    group('forEachReference', () {
      test('visits every ref without leaking handles', () {
        final names = <String>[];
        repo.forEachReference((ref) {
          names.add(ref.name);
          return 0;
        });

        expect(names, contains('refs/heads/main'));
      });
    });

    group('forEachReferenceName', () {
      test('lists matching names when a glob is given', () {
        final names = <String>[];
        repo.forEachReferenceName((name) {
          names.add(name);
          return 0;
        }, glob: 'refs/heads/*');

        expect(names, contains('refs/heads/main'));
        expect(names.every((n) => n.startsWith('refs/heads/')), isTrue);
      });
    });

    group('deleteReference', () {
      test('removes a ref by name', () {
        Reference.create(
          repo: repo,
          name: 'refs/heads/doomed',
          target: headCommitId,
        ).dispose();
        expect(repo.referenceNames(), contains('refs/heads/doomed'));

        repo.deleteReference('refs/heads/doomed');
        expect(repo.referenceNames(), isNot(contains('refs/heads/doomed')));
      });
    });

    group('hasReflog', () {
      test('returns true for a branch that has recorded commits', () {
        expect(repo.hasReflog('refs/heads/main'), isTrue);
      });
    });

    group('ensureReflog', () {
      test('guarantees subsequent updates will append to the reflog', () {
        // Create a direct ref without going through a branch operation so it
        // may not have a reflog yet; then call ensureReflog and verify.
        Reference.create(
          repo: repo,
          name: 'refs/heads/newbranch',
          target: headCommitId,
        ).dispose();

        // ensureReflog must not throw and must cause hasReflog to return true.
        repo.ensureReflog('refs/heads/newbranch');
        expect(repo.hasReflog('refs/heads/newbranch'), isTrue);
      });
    });
  });

  group('Repository.head', () {
    late GitFixture git;
    late Repository repo;
    late Oid headCommitId;

    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      headCommitId = git.commit('initial', files: {'a.txt': 'hello\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    test('returns a reference pointing at the current branch', () {
      final head = repo.head();
      addTearDown(head.dispose);

      expect(head.name, 'refs/heads/main');
      expect(head.target, headCommitId);
    });

    test('throws UnbornBranchException on a freshly initialized repo', () {
      final git2 = GitFixture.init();
      addTearDown(git2.dispose);

      final repo2 = Repository.open(git2.path);
      addTearDown(repo2.dispose);

      expect(repo2.head, throwsA(isA<UnbornBranchException>()));
    });
  });
}
