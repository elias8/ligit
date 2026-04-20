@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('CommitEmail', () {
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

    group('toEmailPatch', () {
      test('formats an mbox-ready patch for a regular commit', () {
        final commit = Commit.lookup(repo, headId);
        addTearDown(commit.dispose);

        final patch = commit.toEmailPatch();
        expect(patch, startsWith('From '));
        expect(patch, contains('Subject: [PATCH] initial'));
        expect(patch, contains('+++ b/a.txt'));
      });

      test('uses a custom subject prefix when supplied', () {
        final commit = Commit.lookup(repo, headId);
        addTearDown(commit.dispose);

        final patch = commit.toEmailPatch(subjectPrefix: 'RFC');
        expect(patch, contains('Subject: [RFC] initial'));
      });

      test('accepts a custom startNumber without throwing', () {
        final commit = Commit.lookup(repo, headId);
        addTearDown(commit.dispose);

        // startNumber shifts the counter; with a single-patch series
        // the output still renders as [PATCH] (no N/M suffix), but the
        // call must succeed.
        final patch = commit.toEmailPatch(startNumber: 3);
        expect(patch, contains('Subject: [PATCH]'));
      });

      test('appends a reroll marker when rerollNumber is nonzero', () {
        final commit = Commit.lookup(repo, headId);
        addTearDown(commit.dispose);

        final patch = commit.toEmailPatch(rerollNumber: 2);
        expect(patch, contains('v2'));
      });
    });
  });
}
