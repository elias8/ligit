@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Commit', () {
    late GitFixture git;
    late Repository repo;
    late Oid initialId;
    late Oid secondId;
    late Oid initialTreeId;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      initialId = git.commit('initial', files: {'a.txt': 'one\n'});
      secondId = git.commit('second', files: {'a.txt': 'two\n'});
      initialTreeId = git.oid('HEAD~^{tree}');
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('lookup', () {
      test('returns a commit with the expected id', () {
        final commit = Commit.lookup(repo, secondId);
        addTearDown(commit.dispose);

        expect(commit.id, secondId);
      });

      test('throws NotFoundException for a missing id', () {
        expect(
          () => Commit.lookup(
            repo,
            Oid.fromString('0000000000000000000000000000000000000001'),
          ),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('lookupPrefix', () {
      test('resolves a commit from its abbreviated oid', () {
        final prefix = secondId.shortSha();
        final commit = Commit.lookupPrefix(repo, secondId, prefix.length);
        addTearDown(commit.dispose);

        expect(commit.id, secondId);
      });
    });

    group('message', () {
      test('returns the full commit message', () {
        final commit = Commit.lookup(repo, secondId);
        addTearDown(commit.dispose);

        expect(commit.message, contains('second'));
      });
    });

    group('summary', () {
      test('returns the first paragraph of the message', () {
        final commit = Commit.lookup(repo, secondId);
        addTearDown(commit.dispose);

        expect(commit.summary, isNotNull);
        expect(commit.summary, contains('second'));
      });
    });

    group('body', () {
      test('returns null for a single-line message', () {
        final commit = Commit.lookup(repo, secondId);
        addTearDown(commit.dispose);

        expect(commit.body, isNull);
      });
    });

    group('author', () {
      test('returns the recorded author signature', () {
        final commit = Commit.lookup(repo, secondId);
        addTearDown(commit.dispose);

        expect(commit.author.name, 'Test');
        expect(commit.author.email, 'test@example.com');
      });
    });

    group('committer', () {
      test('returns the recorded committer signature', () {
        final commit = Commit.lookup(repo, secondId);
        addTearDown(commit.dispose);

        expect(commit.committer.name, 'Test');
        expect(commit.committer.email, 'test@example.com');
      });
    });

    group('time', () {
      test('returns the committer time as a UTC DateTime', () {
        final commit = Commit.lookup(repo, secondId);
        addTearDown(commit.dispose);

        expect(commit.time.isUtc, isTrue);
      });
    });

    group('timeOffset', () {
      test('returns an integer offset in minutes', () {
        final commit = Commit.lookup(repo, secondId);
        addTearDown(commit.dispose);

        expect(commit.timeOffset, isA<int>());
      });
    });

    group('messageEncoding', () {
      test('returns null when no encoding header is present', () {
        final commit = Commit.lookup(repo, secondId);
        addTearDown(commit.dispose);

        expect(commit.messageEncoding, isNull);
      });
    });

    group('messageRaw', () {
      test('returns the raw stored message bytes', () {
        final commit = Commit.lookup(repo, secondId);
        addTearDown(commit.dispose);

        expect(commit.messageRaw, contains('second'));
      });
    });

    group('rawHeader', () {
      test('contains the tree and author fields', () {
        final commit = Commit.lookup(repo, secondId);
        addTearDown(commit.dispose);

        expect(commit.rawHeader, contains('tree'));
        expect(commit.rawHeader, contains('author'));
      });
    });

    group('tree / treeId', () {
      test('treeId matches the id of the loaded tree', () {
        final commit = Commit.lookup(repo, initialId);
        addTearDown(commit.dispose);

        expect(commit.treeId, initialTreeId);

        final tree = commit.tree();
        addTearDown(tree.dispose);

        expect(tree.id, initialTreeId);
      });
    });

    group('parentCount / parent / parentIdAt', () {
      test('root commit has no parents', () {
        final root = Commit.lookup(repo, initialId);
        addTearDown(root.dispose);

        expect(root.parentCount, 0);
      });

      test('second commit links to the initial via parent', () {
        final second = Commit.lookup(repo, secondId);
        addTearDown(second.dispose);

        expect(second.parentCount, 1);
        expect(second.parentIdAt(0), initialId);

        final parent = second.parent(0);
        addTearDown(parent.dispose);

        expect(parent.id, initialId);
      });
    });

    group('nthGenAncestor', () {
      test('walks first-parent history to the given generation', () {
        final second = Commit.lookup(repo, secondId);
        addTearDown(second.dispose);

        final gen1 = second.nthGenAncestor(1);
        addTearDown(gen1.dispose);

        expect(gen1.id, initialId);
      });
    });

    group('headerField', () {
      test('reads standard fields and returns null for absent ones', () {
        final commit = Commit.lookup(repo, secondId);
        addTearDown(commit.dispose);

        expect(commit.headerField('tree'), isNotNull);
        expect(commit.headerField('no-such-field'), isNull);
      });
    });

    group('dup', () {
      test('creates an independent copy with the same id', () {
        final commit = Commit.lookup(repo, secondId);
        addTearDown(commit.dispose);

        final copy = commit.dup();
        addTearDown(copy.dispose);

        expect(copy.id, secondId);
      });
    });

    group('create', () {
      test('writes a new commit that round-trips through lookup', () {
        final parent = Commit.lookup(repo, secondId);
        addTearDown(parent.dispose);

        final tree = parent.tree();
        addTearDown(tree.dispose);

        final sig = Signature(
          name: 'Author',
          email: 'author@example.com',
          when: DateTime.utc(2026, 4, 14, 10),
        );

        final newId = Commit.create(
          repo: repo,
          author: sig,
          committer: sig,
          message: 'third\n',
          tree: tree,
          parents: [parent],
        );

        final created = Commit.lookup(repo, newId);
        addTearDown(created.dispose);

        expect(created.message, 'third\n');
        expect(created.parentCount, 1);
        expect(created.parentIdAt(0), secondId);
      });
    });

    group('createBuffer', () {
      test('serializes commit text with author and committer fields', () {
        final parent = Commit.lookup(repo, secondId);
        addTearDown(parent.dispose);

        final tree = parent.tree();
        addTearDown(tree.dispose);

        final sig = Signature(
          name: 'Ada',
          email: 'ada@example.com',
          when: DateTime.utc(2026, 4, 14),
        );

        final text = Commit.createBuffer(
          repo: repo,
          author: sig,
          committer: sig,
          message: 'buffered\n',
          tree: tree,
          parents: [parent],
        );

        expect(text, contains('author Ada <ada@example.com>'));
        expect(text, contains('buffered'));
      });
    });

    group('createFromStage', () {
      test('commits staged changes and returns the new commit id', () {
        final staged = GitFixture.init();
        addTearDown(staged.dispose);
        staged.commit('base', files: {'x.txt': 'base\n'});
        staged.writeFile('new.txt', 'new\n');
        staged.git(['add', '.']);

        final r = Repository.open(staged.path);
        addTearDown(r.dispose);

        final newId = Commit.createFromStage(r, 'staged\n');
        final created = Commit.lookup(r, newId);
        addTearDown(created.dispose);

        expect(created.message, 'staged\n');
      });
    });

    group('amend', () {
      test('produces a new commit with the updated message', () {
        final base = Commit.lookup(repo, secondId);
        addTearDown(base.dispose);

        final amendedId = Commit.amend(base: base, message: 'amended\n');

        final amended = Commit.lookup(repo, amendedId);
        addTearDown(amended.dispose);

        expect(amended.message, 'amended\n');
      });
    });

    group('createWithSignature / extractSignature', () {
      test('persists a detached signature and extracts it back', () {
        final parent = Commit.lookup(repo, secondId);
        addTearDown(parent.dispose);
        final tree = parent.tree();
        addTearDown(tree.dispose);

        final sig = Signature(
          name: 'Ada',
          email: 'ada@example.com',
          when: DateTime.utc(2026, 4, 14),
        );

        final buffer = Commit.createBuffer(
          repo: repo,
          author: sig,
          committer: sig,
          message: 'signed\n',
          tree: tree,
          parents: [parent],
        );

        final signedId = Commit.createWithSignature(
          repo: repo,
          content: buffer,
          signature: '-----BEGIN SIG-----\nfake\n-----END SIG-----\n',
        );

        final extracted = Commit.extractSignature(repo, signedId);
        expect(extracted.signature, contains('fake'));
        expect(extracted.signedData, contains('signed'));
      });
    });

    group('authorWithMailmap / committerWithMailmap', () {
      test('resolves aliases through the provided mailmap', () {
        final commit = Commit.lookup(repo, secondId);
        addTearDown(commit.dispose);

        final mailmap = Mailmap.empty();
        addTearDown(mailmap.dispose);
        mailmap.addEntry(
          realName: 'Aliased',
          realEmail: 'aliased@example.com',
          replaceEmail: 'test@example.com',
        );

        expect(commit.authorWithMailmap(mailmap).name, 'Aliased');
        expect(
          commit.committerWithMailmap(mailmap).email,
          'aliased@example.com',
        );
      });
    });

    group('==', () {
      test('two lookups of the same id compare equal', () {
        final a = Commit.lookup(repo, secondId);
        addTearDown(a.dispose);
        final b = Commit.lookup(repo, secondId);
        addTearDown(b.dispose);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('commits with different ids are not equal', () {
        final a = Commit.lookup(repo, initialId);
        addTearDown(a.dispose);
        final b = Commit.lookup(repo, secondId);
        addTearDown(b.dispose);

        expect(a, isNot(equals(b)));
      });
    });
  });

  group('Repository.commitParents', () {
    late GitFixture git;
    late Repository repo;
    late Oid headId;

    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('first', files: {'a.txt': 'a\n'});
      headId = git.commit('second', files: {'a.txt': 'aa\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    test('returns HEAD on a clean repository', () {
      final parents = repo.commitParents();
      for (final p in parents) {
        addTearDown(p.dispose);
      }

      expect(parents, hasLength(1));
      expect(parents.single.id, headId);
    });
  });
}
