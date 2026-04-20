@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
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

  group('Tag', () {
    group('lookup', () {
      test('returns the annotated tag by id', () {
        final target = GitObject.lookup(repo, headCommitId);
        addTearDown(target.dispose);

        final tagger = Signature.now(name: 'Tagger', email: 't@x.com');
        final tagId = repo.createTagAnnotation(
          name: 'lookup-me',
          target: target,
          tagger: tagger,
          message: 'anno\n',
        );

        final tag = Tag.lookup(repo, tagId);
        addTearDown(tag.dispose);

        expect(tag.id, tagId);
        expect(tag.name, 'lookup-me');
      });
    });

    group('lookupPrefix', () {
      test('resolves a tag from a short prefix', () {
        final target = GitObject.lookup(repo, headCommitId);
        addTearDown(target.dispose);

        final tagger = Signature.now(name: 'Tagger', email: 't@x.com');
        final tagId = repo.createTagAnnotation(
          name: 'prefix-tag',
          target: target,
          tagger: tagger,
          message: 'pre\n',
        );

        final tag = Tag.lookupPrefix(repo, tagId, 10);
        addTearDown(tag.dispose);

        expect(tag.id, tagId);
      });
    });

    group('dup', () {
      test(
        'produces an independent copy that compares equal to the original',
        () {
          final target = GitObject.lookup(repo, headCommitId);
          addTearDown(target.dispose);

          final tagger = Signature.now(name: 'Tagger', email: 't@x.com');
          final tagId = repo.createTagAnnotation(
            name: 'dup-tag',
            target: target,
            tagger: tagger,
            message: 'dup\n',
          );

          final tag = Tag.lookup(repo, tagId);
          addTearDown(tag.dispose);

          final copy = tag.dup();
          addTearDown(copy.dispose);

          expect(copy, equals(tag));
          expect(copy.name, tag.name);
        },
      );
    });

    group('target', () {
      test('loads the immediate target object of the tag', () {
        final target = GitObject.lookup(repo, headCommitId);
        addTearDown(target.dispose);

        final tagger = Signature.now(name: 'Tagger', email: 't@x.com');
        final tagId = repo.createTagAnnotation(
          name: 'target-tag',
          target: target,
          tagger: tagger,
          message: 'tgt\n',
        );

        final tag = Tag.lookup(repo, tagId);
        addTearDown(tag.dispose);

        final obj = tag.target();
        addTearDown(obj.dispose);

        expect(obj.id, headCommitId);
        expect(obj.type, ObjectType.commit);
      });
    });

    group('peel', () {
      test('resolves an annotated tag to its non-tag target', () {
        final target = GitObject.lookup(repo, headCommitId);
        addTearDown(target.dispose);

        final tagger = Signature.now(name: 'Tagger', email: 't@x.com');
        final tagId = repo.createTagAnnotation(
          name: 'peel-tag',
          target: target,
          tagger: tagger,
          message: 'anno\n',
        );

        final tag = Tag.lookup(repo, tagId);
        addTearDown(tag.dispose);

        final peeled = tag.peel();
        addTearDown(peeled.dispose);

        expect(peeled.type, ObjectType.commit);
        expect(peeled.id, headCommitId);
      });
    });

    group('nameIsValid', () {
      test('accepts well-formed names and rejects malformed ones', () {
        expect(Tag.nameIsValid('v1.2.3'), isTrue);
        expect(Tag.nameIsValid('has..dots'), isFalse);
        expect(Tag.nameIsValid(''), isFalse);
      });
    });

    group('==', () {
      test('two lookups of the same tag compare equal', () {
        final target = GitObject.lookup(repo, headCommitId);
        addTearDown(target.dispose);

        final tagger = Signature.now(name: 'Tagger', email: 't@x.com');
        final tagId = repo.createTagAnnotation(
          name: 'eqtag',
          target: target,
          tagger: tagger,
          message: 'hi\n',
        );

        final a = Tag.lookup(repo, tagId);
        addTearDown(a.dispose);
        final b = Tag.lookup(repo, tagId);
        addTearDown(b.dispose);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });
    });
  });

  group('RepositoryTag', () {
    group('createTag', () {
      test('writes a tag object and creates refs/tags/<name>', () {
        final target = GitObject.lookup(repo, headCommitId);
        addTearDown(target.dispose);

        final tagger = Signature(
          name: 'Tagger',
          email: 'tagger@example.com',
          when: DateTime.utc(2026, 4, 14, 12),
        );

        final tagId = repo.createTag(
          name: 'v1.0.0',
          target: target,
          tagger: tagger,
          message: 'release 1.0.0\n',
        );

        final tag = Tag.lookup(repo, tagId);
        addTearDown(tag.dispose);

        expect(tag.name, 'v1.0.0');
        expect(tag.message, 'release 1.0.0\n');
        expect(tag.targetId, headCommitId);
        expect(tag.targetType, ObjectType.commit);
        expect(tag.tagger?.name, 'Tagger');
      });
    });

    group('createTagFromBuffer', () {
      test(
        'parses raw tag bytes and creates refs/tags from the embedded name',
        () {
          final sha = headCommitId.sha;
          final buffer =
              'object $sha\ntype commit\ntag from-buffer\n'
              'tagger T <t@x.com> 0 +0000\n\nbuffer tag\n';

          final tagId = repo.createTagFromBuffer(buffer);

          expect(repo.tagNames(), contains('from-buffer'));

          final tag = Tag.lookup(repo, tagId);
          addTearDown(tag.dispose);
          expect(tag.name, 'from-buffer');
        },
      );
    });

    group('createLightweightTag', () {
      test('creates a plain ref with no tag object', () {
        final target = GitObject.lookup(repo, headCommitId);
        addTearDown(target.dispose);

        final result = repo.createLightweightTag(name: 'light', target: target);

        expect(result, headCommitId);
        expect(repo.tagNames(), contains('light'));
      });
    });

    group('tagNames', () {
      test('returns every created tag name, optionally fnmatch-filtered', () {
        final target = GitObject.lookup(repo, headCommitId);
        addTearDown(target.dispose);

        repo.createLightweightTag(name: 'alpha', target: target, force: true);
        repo.createLightweightTag(name: 'beta', target: target, force: true);

        expect(repo.tagNames(), containsAll(['alpha', 'beta']));
        expect(repo.tagNames(match: 'a*'), contains('alpha'));
        expect(repo.tagNames(match: 'a*'), isNot(contains('beta')));
      });
    });

    group('forEachTag', () {
      test('visits every tag reference and resolves its target id', () {
        final target = GitObject.lookup(repo, headCommitId);
        addTearDown(target.dispose);

        repo.createLightweightTag(name: 'visited', target: target);

        final names = <String>[];
        repo.forEachTag((name, id) {
          names.add(name);
          return 0;
        });

        expect(names, contains('refs/tags/visited'));
      });
    });

    group('deleteTag', () {
      test('removes the tag reference', () {
        final target = GitObject.lookup(repo, headCommitId);
        addTearDown(target.dispose);

        repo.createLightweightTag(name: 'trash', target: target);
        expect(repo.tagNames(), contains('trash'));

        repo.deleteTag('trash');
        expect(repo.tagNames(), isNot(contains('trash')));
      });
    });
  });
}
