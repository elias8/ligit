@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Transaction', () {
    late GitFixture git;
    late Repository repo;
    late Oid firstId;
    late Oid secondId;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      firstId = git.commit('one', files: {'a.txt': 'one\n'});
      secondId = git.commit('two', files: {'a.txt': 'two\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('commit', () {
      test('atomically updates a branch to a new target', () {
        final tx = Transaction(repo);
        addTearDown(tx.dispose);

        tx.lockReference('refs/heads/main');
        tx.setTarget('refs/heads/main', firstId);
        tx.commit();

        expect(git.oid('refs/heads/main'), firstId);
      });
    });

    group('setSymbolicTarget', () {
      test('redirects a symbolic ref to a different direct ref', () {
        // Create a second branch pointing at secondId.
        Reference.create(
          repo: repo,
          name: 'refs/heads/other',
          target: secondId,
        ).dispose();

        final tx = Transaction(repo);
        addTearDown(tx.dispose);

        tx.lockReference('HEAD');
        tx.setSymbolicTarget('HEAD', 'refs/heads/other');
        tx.commit();

        final head = Reference.lookup(repo, 'HEAD');
        addTearDown(head.dispose);
        expect(head.symbolicTarget, 'refs/heads/other');
      });
    });

    group('setReflog', () {
      test('replaces the reflog of a locked reference', () {
        final tx = Transaction(repo);
        addTearDown(tx.dispose);

        final reflog = Reflog.read(repo, 'refs/heads/main');
        addTearDown(reflog.dispose);

        tx.lockReference('refs/heads/main');
        tx.setTarget('refs/heads/main', secondId);
        tx.setReflog('refs/heads/main', reflog);
        tx.commit();

        // The operation should complete without throwing.
        expect(git.oid('refs/heads/main'), secondId);
      });
    });

    group('remove', () {
      test('deletes the reference when committed', () {
        final branch = Reference.create(
          repo: repo,
          name: 'refs/heads/ephemeral',
          target: secondId,
        );
        addTearDown(branch.dispose);

        final tx = Transaction(repo);
        addTearDown(tx.dispose);
        tx.lockReference('refs/heads/ephemeral');
        tx.remove('refs/heads/ephemeral');
        tx.commit();

        expect(
          () => Reference.lookup(repo, 'refs/heads/ephemeral'),
          throwsA(isA<NotFoundException>()),
        );
      });
    });
  });

  group('ConfigLockExt', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('seed', files: {'f.txt': 'x'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('lock', () {
      test('returns a Transaction that can commit config changes', () {
        final cfg = Config.fromRepository(repo);
        addTearDown(cfg.dispose);

        final tx = cfg.lock();
        addTearDown(tx.dispose);

        cfg.setString('test.key', 'locked-value');
        tx.commit();

        final cfg2 = Config.fromRepository(repo);
        addTearDown(cfg2.dispose);
        expect(cfg2.getString('test.key'), 'locked-value');
      });
    });
  });
}
