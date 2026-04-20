@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Repository revParse', () {
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

    group('revParseSingle', () {
      test('resolves HEAD to the tip commit', () {
        final obj = repo.revParseSingle('HEAD');
        addTearDown(obj.dispose);

        expect(obj.id, secondId);
        expect(obj.type, ObjectType.commit);
      });

      test('resolves HEAD~ to the first commit', () {
        final obj = repo.revParseSingle('HEAD~');
        addTearDown(obj.dispose);

        expect(obj.id, firstId);
      });

      test('throws NotFoundException for an unknown spec', () {
        expect(
          () => repo.revParseSingle('refs/heads/missing'),
          throwsA(isA<NotFoundException>()),
        );
      });

      test('throws on unparseable spec', () {
        expect(
          () => repo.revParseSingle('not a spec^^^bogus'),
          throwsA(isA<Libgit2Exception>()),
        );
      });
    });

    group('revParseExt', () {
      test('returns the resolved reference for a branch name', () {
        final result = repo.revParseExt('main');
        addTearDown(result.object.dispose);
        addTearDown(() => result.reference?.dispose());

        expect(result.object.id, secondId);
        expect(result.reference?.name, 'refs/heads/main');
      });

      test('returns a null reference for a raw commit spec', () {
        final result = repo.revParseExt(secondId.sha);
        addTearDown(result.object.dispose);
        addTearDown(() => result.reference?.dispose());

        expect(result.object.id, secondId);
        expect(result.reference, isNull);
      });
    });

    group('revParseRange', () {
      test('parses a `..` range into both endpoints', () {
        final spec = repo.revParseRange('HEAD~..HEAD');
        addTearDown(spec.dispose);

        expect(spec.from.id, firstId);
        expect(spec.to?.id, secondId);
        expect(spec.isRange, isTrue);
        expect(spec.isSingle, isFalse);
        expect(spec.isMergeBase, isFalse);
      });

      test('parses a `...` merge-base range', () {
        final spec = repo.revParseRange('HEAD~...HEAD');
        addTearDown(spec.dispose);

        expect(spec.from.id, firstId);
        expect(spec.to?.id, secondId);
        expect(spec.isMergeBase, isTrue);
      });

      test('parses a single spec with no range operator', () {
        final spec = repo.revParseRange('HEAD');
        addTearDown(spec.dispose);

        expect(spec.from.id, secondId);
        expect(spec.to, isNull);
        expect(spec.isSingle, isTrue);
      });
    });
  });
}
