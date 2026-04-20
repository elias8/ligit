@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Rebase', () {
    late GitFixture git;
    late Repository repo;
    late Signature me;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('base', files: {'base.txt': 'base\n'});
      git.git(['checkout', '-b', 'feature']);
      git.commit('feature commit', files: {'feature.txt': 'feature\n'});
      git.git(['checkout', 'main']);
      git.commit('main commit', files: {'main.txt': 'main\n'});

      repo = Repository.open(git.path);
      me = Signature.now(name: 'Test', email: 'test@example.com');
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('start / next / commitStep / finish', () {
      test('replays feature commits onto main and finishes cleanly', () {
        final branch = AnnotatedCommit.fromRevSpec(repo, 'feature');
        addTearDown(branch.dispose);
        final onto = AnnotatedCommit.fromRevSpec(repo, 'main');
        addTearDown(onto.dispose);

        final rebase = Rebase.start(
          repo: repo,
          branch: branch,
          upstream: onto,
          onto: onto,
          inMemory: true,
        );
        addTearDown(rebase.dispose);

        expect(rebase.operationCount, greaterThan(0));

        for (var i = 0; i < rebase.operationCount; i++) {
          rebase.next();
          rebase.commitStep(committer: me);
        }

        rebase.finish(signature: me);
      });
    });

    group('open', () {
      test('reopens an in-progress on-disk rebase', () {
        final branch = AnnotatedCommit.fromRevSpec(repo, 'feature');
        addTearDown(branch.dispose);
        final onto = AnnotatedCommit.fromRevSpec(repo, 'main');
        addTearDown(onto.dispose);

        final started = Rebase.start(
          repo: repo,
          branch: branch,
          upstream: onto,
          onto: onto,
        );
        started.next();
        started.dispose();

        final reopened = Rebase.open(repo);
        addTearDown(reopened.dispose);

        expect(reopened.operationCount, greaterThan(0));
      });
    });

    group('inMemoryIndex', () {
      test('returns the staging index for the current in-memory step', () {
        final branch = AnnotatedCommit.fromRevSpec(repo, 'feature');
        addTearDown(branch.dispose);
        final onto = AnnotatedCommit.fromRevSpec(repo, 'main');
        addTearDown(onto.dispose);

        final rebase = Rebase.start(
          repo: repo,
          branch: branch,
          upstream: onto,
          onto: onto,
          inMemory: true,
        );
        addTearDown(rebase.dispose);

        rebase.next();
        final index = rebase.inMemoryIndex();
        addTearDown(index.dispose);

        expect(index.hasConflicts, isFalse);
      });
    });

    group('abort', () {
      test('cleans up an in-progress rebase without touching HEAD', () {
        git.git(['checkout', 'feature']);
        final branch = AnnotatedCommit.fromRevSpec(repo, 'feature');
        addTearDown(branch.dispose);
        final onto = AnnotatedCommit.fromRevSpec(repo, 'main');
        addTearDown(onto.dispose);

        final rebase = Rebase.start(
          repo: repo,
          branch: branch,
          upstream: onto,
          onto: onto,
        );
        expect(rebase.operationCount, greaterThan(0));
        rebase.abort();
        rebase.dispose();
      });
    });
  });

  group('RebaseOperation', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('base', files: {'base.txt': 'base\n'});
      git.git(['checkout', '-b', 'feature']);
      git.commit('feature commit 1', files: {'f1.txt': 'f1\n'});
      git.commit('feature commit 2', files: {'f2.txt': 'f2\n'});
      git.git(['checkout', 'main']);
      git.commit('main commit', files: {'main.txt': 'main\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('==', () {
      test('two reads of the same operation compare equal', () {
        final branch = AnnotatedCommit.fromRevSpec(repo, 'feature');
        addTearDown(branch.dispose);
        final onto = AnnotatedCommit.fromRevSpec(repo, 'main');
        addTearDown(onto.dispose);

        final rebase = Rebase.start(
          repo: repo,
          branch: branch,
          upstream: onto,
          onto: onto,
          inMemory: true,
        );
        addTearDown(rebase.dispose);

        final op0a = rebase.operationAt(0)!;
        final op0b = rebase.operationAt(0)!;

        expect(op0a, equals(op0b));
        expect(op0a.hashCode, op0b.hashCode);
      });

      test('operations at different positions compare unequal', () {
        final branch = AnnotatedCommit.fromRevSpec(repo, 'feature');
        addTearDown(branch.dispose);
        final onto = AnnotatedCommit.fromRevSpec(repo, 'main');
        addTearDown(onto.dispose);

        final rebase = Rebase.start(
          repo: repo,
          branch: branch,
          upstream: onto,
          onto: onto,
          inMemory: true,
        );
        addTearDown(rebase.dispose);

        expect(rebase.operationCount, greaterThanOrEqualTo(2));
        final op0 = rebase.operationAt(0)!;
        final op1 = rebase.operationAt(1)!;

        expect(op0, isNot(equals(op1)));
      });
    });
  });
}
