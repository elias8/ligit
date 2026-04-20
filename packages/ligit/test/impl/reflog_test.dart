@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Reflog', () {
    late GitFixture git;
    late Repository repo;
    late Oid firstId;
    late Oid secondId;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      firstId = git.commit('initial', files: {'a.txt': 'hello\n'});
      secondId = git.commit('second', files: {'a.txt': 'second\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('read', () {
      test('loads entries for HEAD in newest-first order', () {
        final log = Reflog.read(repo, 'HEAD');
        addTearDown(log.dispose);

        expect(log.length, greaterThanOrEqualTo(2));
        expect(log[0].newId, secondId);
        expect(log[0].oldId, firstId);
      });

      test('throws RangeError for an out-of-bounds index', () {
        final log = Reflog.read(repo, 'HEAD');
        addTearDown(log.dispose);

        expect(() => log[-1], throwsRangeError);
        expect(() => log[log.length], throwsRangeError);
      });
    });

    group('append / write', () {
      test('adds a new entry and persists it to disk', () {
        final log = Reflog.read(repo, 'HEAD');
        addTearDown(log.dispose);

        final before = log.length;
        final committer = Signature(
          name: 'Ada',
          email: 'ada@example.com',
          when: DateTime.utc(2020),
        );
        log.append(newId: firstId, committer: committer, message: 'manual');
        expect(log[0].newId, firstId);
        log.write();

        final reread = Reflog.read(repo, 'HEAD');
        addTearDown(reread.dispose);
        expect(reread.length, before + 1);
        expect(reread[0].message, 'manual');
        expect(reread[0].committer.name, 'Ada');
        expect(reread[0].newId, firstId);
      });
    });

    group('drop', () {
      test('removes the entry at the given index', () {
        final log = Reflog.read(repo, 'HEAD');
        addTearDown(log.dispose);

        final before = log.length;
        log.drop(0);
        log.write();

        final reread = Reflog.read(repo, 'HEAD');
        addTearDown(reread.dispose);
        expect(reread.length, before - 1);
      });
    });

    group('==', () {
      test('two entry value copies from the same index compare equal', () {
        final log = Reflog.read(repo, 'HEAD');
        addTearDown(log.dispose);

        expect(log[0], equals(log[0]));
        expect(log[0].hashCode, log[0].hashCode);
      });

      test('entries at different positions compare unequal', () {
        final log = Reflog.read(repo, 'HEAD');
        addTearDown(log.dispose);

        expect(log.length, greaterThanOrEqualTo(2));
        expect(log[0], isNot(equals(log[1])));
      });
    });
  });

  group('RepositoryReflog', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('initial', files: {'a.txt': 'hello\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('renameReflog / deleteReflog', () {
      test('renames a reflog and then deletes it', () {
        repo.renameReflog('refs/heads/main', 'refs/heads/renamed');
        final log = Reflog.read(repo, 'refs/heads/renamed');
        addTearDown(log.dispose);
        expect(log.length, greaterThan(0));

        repo.deleteReflog('refs/heads/renamed');
        final empty = Reflog.read(repo, 'refs/heads/renamed');
        addTearDown(empty.dispose);
        expect(empty.length, 0);
      });
    });
  });
}
