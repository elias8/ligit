@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('GitObject', () {
    late GitFixture git;
    late Repository repo;
    late Oid headId;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      headId = git.commit('initial', files: {'a.txt': 'hello world\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('lookup', () {
      test('returns an object with the expected id and type', () {
        final obj = GitObject.lookup(repo, headId);
        addTearDown(obj.dispose);

        expect(obj.id, headId);
        expect(obj.type, ObjectType.commit);
      });

      test('throws NotFoundException for a missing id', () {
        final missing = Oid.fromString(
          '0000000000000000000000000000000000000001',
        );

        expect(
          () => GitObject.lookup(repo, missing),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('lookupByPath', () {
      test('returns the blob for a file path relative to a treeish', () {
        final commit = GitObject.lookup(repo, headId);
        addTearDown(commit.dispose);

        final blob = GitObject.lookupByPath(commit, 'a.txt', ObjectType.blob);
        addTearDown(blob.dispose);

        expect(blob.type, ObjectType.blob);
      });

      test('throws NotFoundException when the path does not exist', () {
        final commit = GitObject.lookup(repo, headId);
        addTearDown(commit.dispose);

        expect(
          () => GitObject.lookupByPath(commit, 'missing.txt', ObjectType.blob),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('lookupPrefix', () {
      test('resolves an object by a short hex prefix', () {
        final obj = GitObject.lookupPrefix(repo, headId, 7);
        addTearDown(obj.dispose);

        expect(obj.id, headId);
      });
    });

    group('peel', () {
      test('peels a commit down to its root tree', () {
        final commit = GitObject.lookup(repo, headId);
        addTearDown(commit.dispose);

        final tree = commit.peel(ObjectType.tree);
        addTearDown(tree.dispose);

        expect(tree.type, ObjectType.tree);
      });
    });

    group('shortId', () {
      test('starts at core.abbrev length', () {
        final obj = GitObject.lookup(repo, headId);
        addTearDown(obj.dispose);

        expect(obj.shortId.length, greaterThanOrEqualTo(7));
        expect(headId.sha.startsWith(obj.shortId), isTrue);
      });
    });

    group('dup', () {
      test('produces an independent handle that compares equal', () {
        final a = GitObject.lookup(repo, headId);
        addTearDown(a.dispose);

        final b = a.dup();
        addTearDown(b.dispose);

        expect(identical(a, b), isFalse);
        expect(a, equals(b));
      });
    });

    group('==', () {
      test(
        'two lookups of the same id compare equal with the same hashCode',
        () {
          final a = GitObject.lookup(repo, headId);
          addTearDown(a.dispose);
          final b = GitObject.lookup(repo, headId);
          addTearDown(b.dispose);

          expect(a, equals(b));
          expect(a.hashCode, b.hashCode);
        },
      );
    });

    group('gitName / typeFromString', () {
      test('round-trips each type', () {
        for (final t in [
          ObjectType.commit,
          ObjectType.tree,
          ObjectType.blob,
          ObjectType.tag,
        ]) {
          expect(GitObject.typeFromString(t.gitName), t);
        }
      });
    });

    group('isLoose', () {
      test('is true for commit/tree/blob/tag', () {
        expect(ObjectType.commit.isLoose, isTrue);
        expect(ObjectType.tree.isLoose, isTrue);
        expect(ObjectType.blob.isLoose, isTrue);
        expect(ObjectType.tag.isLoose, isTrue);
      });
    });

    group('isValidRawContent', () {
      test('accepts any content as a blob', () {
        expect(
          GitObject.isValidRawContent(
            Uint8List.fromList('anything'.codeUnits),
            ObjectType.blob,
          ),
          isTrue,
        );
      });

      test('rejects malformed tree content', () {
        expect(
          GitObject.isValidRawContent(
            Uint8List.fromList('not a tree'.codeUnits),
            ObjectType.tree,
          ),
          isFalse,
        );
      });
    });
  });
}
