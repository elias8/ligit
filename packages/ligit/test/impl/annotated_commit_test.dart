@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('AnnotatedCommit', () {
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
      test('creates an annotated commit pointing at the given id', () {
        final ac = AnnotatedCommit.lookup(repo, headId);
        addTearDown(ac.dispose);

        expect(ac.id, headId);
        expect(ac.ref, isNull);
      });

      test('throws NotFoundException for an unknown id', () {
        final missing = Oid.fromString(
          '0000000000000000000000000000000000000001',
        );

        expect(
          () => AnnotatedCommit.lookup(repo, missing),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('fromRevSpec', () {
      test('resolves HEAD to the latest commit', () {
        final ac = AnnotatedCommit.fromRevSpec(repo, 'HEAD');
        addTearDown(ac.dispose);

        expect(ac.id, headId);
      });

      test('throws for a nonsense revSpec', () {
        expect(
          () => AnnotatedCommit.fromRevSpec(repo, 'no-such-thing'),
          throwsA(isA<Libgit2Exception>()),
        );
      });
    });

    group('fromFetchHead', () {
      test('records branch name and remote url alongside the id', () {
        final ac = AnnotatedCommit.fromFetchHead(
          repo: repo,
          branchName: 'main',
          remoteUrl: 'https://example.com/repo.git',
          commitId: headId,
        );
        addTearDown(ac.dispose);

        expect(ac.id, headId);
      });
    });

    group('fromRef', () {
      test('resolves the ref and records its name', () {
        final ref = Reference.lookup(repo, 'refs/heads/main');
        addTearDown(ref.dispose);

        final ac = AnnotatedCommit.fromRef(repo, ref);
        addTearDown(ac.dispose);

        expect(ac.id, headId);
        expect(ac.ref, 'refs/heads/main');
      });
    });

    group('Repository.setHeadDetachedFromAnnotated', () {
      test('moves HEAD to the annotated commit', () {
        final ac = AnnotatedCommit.lookup(repo, headId);
        addTearDown(ac.dispose);

        repo.setHeadDetachedFromAnnotated(ac);

        expect(repo.isHeadDetached, isTrue);
      });
    });
  });
}
