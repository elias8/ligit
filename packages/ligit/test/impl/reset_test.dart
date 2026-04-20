@Tags(['ffi'])
library;

import 'dart:io';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('RepositoryReset', () {
    late GitFixture git;
    late Repository repo;
    late Oid firstId;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      firstId = git.commit('initial', files: {'a.txt': 'hello\n'});
      git.commit('second', files: {'a.txt': 'second\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('reset', () {
      test('soft moves HEAD without touching the worktree', () {
        final target = GitObject.lookup(repo, firstId);
        addTearDown(target.dispose);
        repo.reset(target, ResetMode.soft);

        expect(git.oid('HEAD'), firstId);
        expect(File('${git.path}/a.txt').readAsStringSync(), 'second\n');
      });

      test('hard rewrites the worktree to the target commit', () {
        final target = GitObject.lookup(repo, firstId);
        addTearDown(target.dispose);
        repo.reset(target, ResetMode.hard);

        expect(File('${git.path}/a.txt').readAsStringSync(), 'hello\n');
      });
    });

    group('resetDefault', () {
      test('unstages paths when target is null', () {
        File('${git.path}/new.txt').writeAsStringSync('fresh\n');
        git.git(['add', 'new.txt']);

        repo.resetDefault(target: null, pathspecs: ['new.txt']);

        final status = git.git(['status', '--porcelain']).stdout as String;
        expect(status, contains('?? new.txt'));
      });
    });

    group('resetFromAnnotated', () {
      test('moves HEAD to an annotated commit', () {
        final ac = AnnotatedCommit.fromRevSpec(repo, 'HEAD~');
        addTearDown(ac.dispose);
        repo.resetFromAnnotated(ac, ResetMode.soft);

        expect(git.oid('HEAD'), firstId);
      });
    });
  });
}
