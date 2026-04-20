@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Tree', () {
    late GitFixture git;
    late Repository repo;
    late Oid rootTreeId;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit(
        'seed',
        files: {'README.md': '# Test\n', 'subdir/inner.txt': 'inside\n'},
      );
      repo = Repository.open(git.path);
      rootTreeId = git.oid('HEAD^{tree}');
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('lookup', () {
      test('returns the tree with the expected id', () {
        final tree = Tree.lookup(repo, rootTreeId);
        addTearDown(tree.dispose);

        expect(tree.id, rootTreeId);
      });

      test('throws NotFoundException for a missing id', () {
        expect(
          () => Tree.lookup(
            repo,
            Oid.fromString('0000000000000000000000000000000000000001'),
          ),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('lookupPrefix', () {
      test('resolves a tree from a short prefix', () {
        final tree = Tree.lookupPrefix(repo, rootTreeId, 10);
        addTearDown(tree.dispose);

        expect(tree.id, rootTreeId);
      });
    });

    group('dup', () {
      test(
        'produces an independent copy that compares equal to the original',
        () {
          final tree = Tree.lookup(repo, rootTreeId);
          addTearDown(tree.dispose);

          final copy = tree.dup();
          addTearDown(copy.dispose);

          expect(copy, equals(tree));
          expect(copy.id, tree.id);
        },
      );
    });

    group('entryCount', () {
      test('counts only direct entries', () {
        final tree = Tree.lookup(repo, rootTreeId);
        addTearDown(tree.dispose);

        expect(tree.entryCount, greaterThanOrEqualTo(2));
      });
    });

    group('entryByName', () {
      test('finds the README entry', () {
        final tree = Tree.lookup(repo, rootTreeId);
        addTearDown(tree.dispose);

        final entry = tree.entryByName('README.md');
        addTearDown(() => entry?.dispose());

        expect(entry, isNotNull);
        expect(entry!.name, 'README.md');
        expect(entry.type, ObjectType.blob);
        expect(entry.fileMode, FileMode.blob);
      });

      test('returns null for a missing name', () {
        final tree = Tree.lookup(repo, rootTreeId);
        addTearDown(tree.dispose);

        expect(tree.entryByName('no-such-file'), isNull);
      });
    });

    group('entryByIndex', () {
      test('retrieves entries in order', () {
        final tree = Tree.lookup(repo, rootTreeId);
        addTearDown(tree.dispose);

        final first = tree.entryByIndex(0);
        addTearDown(() => first?.dispose());

        expect(first, isNotNull);
        expect(first!.name, isNotEmpty);
      });

      test('returns null past the end', () {
        final tree = Tree.lookup(repo, rootTreeId);
        addTearDown(tree.dispose);

        expect(tree.entryByIndex(10000), isNull);
      });
    });

    group('entryById', () {
      test('returns the entry whose oid matches the blob id', () {
        final tree = Tree.lookup(repo, rootTreeId);
        addTearDown(tree.dispose);

        final readme = tree.entryByName('README.md')!;
        addTearDown(readme.dispose);

        final found = tree.entryById(readme.id);
        addTearDown(() => found?.dispose());

        expect(found, isNotNull);
        expect(found!.name, 'README.md');
      });

      test('returns null when no entry matches the id', () {
        final tree = Tree.lookup(repo, rootTreeId);
        addTearDown(tree.dispose);

        expect(
          tree.entryById(
            Oid.fromString('0000000000000000000000000000000000000001'),
          ),
          isNull,
        );
      });
    });

    group('entryByPath', () {
      test('resolves a nested path', () {
        final tree = Tree.lookup(repo, rootTreeId);
        addTearDown(tree.dispose);

        final entry = tree.entryByPath('subdir/inner.txt');
        addTearDown(() => entry?.dispose());

        expect(entry, isNotNull);
        expect(entry!.name, 'inner.txt');
        expect(entry.type, ObjectType.blob);
      });

      test('returns null for a missing path', () {
        final tree = Tree.lookup(repo, rootTreeId);
        addTearDown(tree.dispose);

        expect(tree.entryByPath('no/such/path'), isNull);
      });
    });

    group('objectAt', () {
      test('loads the blob referenced by an entry', () {
        final tree = Tree.lookup(repo, rootTreeId);
        addTearDown(tree.dispose);

        final entry = tree.entryByName('README.md')!;
        addTearDown(entry.dispose);

        final obj = tree.objectAt(entry, repo);
        addTearDown(obj.dispose);

        expect(obj.type, ObjectType.blob);
        expect(obj.id, entry.id);
      });
    });

    group('walk', () {
      test('visits every entry under the root', () {
        final tree = Tree.lookup(repo, rootTreeId);
        addTearDown(tree.dispose);

        final names = <String>[];
        tree.walk((root, entry) {
          names.add('$root${entry.name}');
          entry.dispose();
          return 0;
        });

        expect(names, contains('README.md'));
      });
    });

    group('createUpdated', () {
      test('applies a removal to produce a new tree id', () {
        final tree = Tree.lookup(repo, rootTreeId);
        addTearDown(tree.dispose);

        final newId = Tree.createUpdated(repo, tree, [
          TreeUpdate.remove('README.md'),
        ]);

        expect(newId, isNot(rootTreeId));
      });
    });

    group('==', () {
      test('two lookups of the same tree compare equal', () {
        final a = Tree.lookup(repo, rootTreeId);
        addTearDown(a.dispose);
        final b = Tree.lookup(repo, rootTreeId);
        addTearDown(b.dispose);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });
    });
  });

  group('TreeBuilder', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit(
        'seed',
        files: {'README.md': '# Test\n', 'subdir/inner.txt': 'inside\n'},
      );
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('insert / write', () {
      test('inserts an entry and writes a new tree', () {
        final bytes = Uint8List.fromList('hi\n'.codeUnits);
        final blob = Blob.fromBuffer(repo, bytes);
        addTearDown(blob.dispose);

        final builder = TreeBuilder(repo);
        addTearDown(builder.dispose);

        builder.insert('greet.txt', blob.id, FileMode.blob);
        expect(builder.length, 1);

        final id = builder.write();
        final tree = Tree.lookup(repo, id);
        addTearDown(tree.dispose);
        expect(tree.entryByName('greet.txt'), isNotNull);
      });
    });

    group('get', () {
      test('returns the staged entry by filename', () {
        final bytes = Uint8List.fromList('x\n'.codeUnits);
        final blob = Blob.fromBuffer(repo, bytes);
        addTearDown(blob.dispose);

        final builder = TreeBuilder(repo);
        addTearDown(builder.dispose);

        builder.insert('x.txt', blob.id, FileMode.blob);

        final entry = builder.get('x.txt');
        addTearDown(() => entry?.dispose());

        expect(entry, isNotNull);
        expect(entry!.name, 'x.txt');
      });

      test('returns null for an unknown filename', () {
        final builder = TreeBuilder(repo);
        addTearDown(builder.dispose);

        expect(builder.get('ghost.txt'), isNull);
      });
    });

    group('remove', () {
      test('drops an inserted entry so it no longer appears in get', () {
        final bytes = Uint8List.fromList('drop\n'.codeUnits);
        final blob = Blob.fromBuffer(repo, bytes);
        addTearDown(blob.dispose);

        final builder = TreeBuilder(repo);
        addTearDown(builder.dispose);

        builder.insert('drop.txt', blob.id, FileMode.blob);
        expect(builder.length, 1);

        builder.remove('drop.txt');
        expect(builder.length, 0);
        expect(builder.get('drop.txt'), isNull);
      });
    });

    group('clear', () {
      test('removes all entries, resetting length to zero', () {
        final bytes = Uint8List.fromList('a\n'.codeUnits);
        final blob = Blob.fromBuffer(repo, bytes);
        addTearDown(blob.dispose);

        final builder = TreeBuilder(repo);
        addTearDown(builder.dispose);

        builder.insert('a.txt', blob.id, FileMode.blob);
        builder.insert('b.txt', blob.id, FileMode.blob);
        expect(builder.length, 2);

        builder.clear();
        expect(builder.length, 0);
      });
    });

    group('filter', () {
      test('removes entries for which the predicate returns non-zero', () {
        final bytes = Uint8List.fromList('y\n'.codeUnits);
        final blob = Blob.fromBuffer(repo, bytes);
        addTearDown(blob.dispose);

        final builder = TreeBuilder(repo);
        addTearDown(builder.dispose);

        builder.insert('keep.txt', blob.id, FileMode.blob);
        builder.insert('drop.txt', blob.id, FileMode.blob);

        // Remove entries named 'drop.txt'.
        builder.filter((entry) => entry.name == 'drop.txt' ? 1 : 0);

        expect(builder.get('drop.txt'), isNull);
        expect(builder.get('keep.txt'), isNotNull);
      });
    });
  });

  group('TreeEntry', () {
    late GitFixture git;
    late Repository repo;
    late Oid rootTreeId;

    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit(
        'seed',
        files: {'README.md': '# Test\n', 'subdir/inner.txt': 'inside\n'},
      );
      repo = Repository.open(git.path);
      rootTreeId = git.oid('HEAD^{tree}');
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('compareTo', () {
      test('orders entries lexicographically', () {
        final tree = Tree.lookup(repo, rootTreeId);
        addTearDown(tree.dispose);

        final a = tree.entryByName('README.md')!;
        addTearDown(a.dispose);
        final b = tree.entryByName('subdir')!;
        addTearDown(b.dispose);

        expect(a.compareTo(a), isZero);
        expect(a.compareTo(b), isNot(isZero));
      });
    });

    group('==', () {
      test('two entries for the same name/id/type/mode compare equal', () {
        final tree = Tree.lookup(repo, rootTreeId);
        addTearDown(tree.dispose);

        final a = tree.entryByName('README.md')!;
        addTearDown(a.dispose);
        final b = tree.entryByName('README.md')!;
        addTearDown(b.dispose);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });
    });
  });
}
