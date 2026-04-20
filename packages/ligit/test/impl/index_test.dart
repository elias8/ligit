@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Index', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('seed', files: {'a.txt': 'a\n', 'sub/b.txt': 'b\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('fromRepository', () {
      test('returns an index with the expected entry count', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        expect(index.entryCount, 2);
      });

      test('returns an index backed by the on-disk index file', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        expect(index.path, endsWith('index'));
      });

      test('reports no conflicts on a clean working tree', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        expect(index.hasConflicts, isFalse);
      });
    });

    group('inMemory', () {
      test('creates an empty index with no backing path', () {
        final index = Index.inMemory();
        addTearDown(index.dispose);

        expect(index.entryCount, 0);
        expect(index.path, isNull);
      });
    });

    group('getByPath', () {
      test('returns the entry with the expected metadata', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        final entry = index.getByPath('a.txt')!;

        expect(entry.path, 'a.txt');
        expect(entry.stage, 0);
        expect(entry.isConflict, isFalse);
        expect(entry.id.isZero, isFalse);
      });

      test('returns null for a missing path', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        expect(index.getByPath('nope'), isNull);
      });
    });

    group('getByIndex', () {
      test('returns null past the end', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        expect(index.getByIndex(0), isNotNull);
        expect(index.getByIndex(999), isNull);
      });
    });

    group('entries', () {
      test('yields entries in path order', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        final paths = index.entries().map((e) => e.path).toList();

        expect(paths, ['a.txt', 'sub/b.txt']);
      });
    });

    group('add', () {
      test(
        'inserts an in-memory entry replacing any prior entry at the path',
        () {
          final index = Index.fromRepository(repo);
          addTearDown(index.dispose);

          final existing = index.getByPath('a.txt')!;
          final replacement = IndexEntry(
            path: 'a.txt',
            id: existing.id,
            fileSize: 99,
          );
          index.add(replacement);

          expect(index.getByPath('a.txt')!.fileSize, 99);
        },
      );
    });

    group('addByPath / write / writeTree', () {
      test('stages a new file and writes a tree', () {
        git.writeFile('c.txt', 'c\n');

        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        index.addByPath('c.txt');
        index.write();
        final treeId = index.writeTree();

        expect(index.entryCount, 3);
        expect(index.getByPath('c.txt'), isNotNull);
        expect(treeId.isZero, isFalse);
      });
    });

    group('writeTreeTo', () {
      test(
        'writes the index tree into a target repository and returns an oid',
        () {
          final index = Index.fromRepository(repo);
          addTearDown(index.dispose);

          final treeId = index.writeTreeTo(repo);

          expect(treeId.isZero, isFalse);
          expect(treeId, equals(index.writeTree()));
        },
      );
    });

    group('addFromBuffer', () {
      test('creates a blob and indexes it under the entry path', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        final entry = IndexEntry(path: 'virtual.txt');
        index.addFromBuffer(entry, Uint8List.fromList([104, 105, 10]));

        final stored = index.getByPath('virtual.txt')!;
        expect(stored.path, 'virtual.txt');
        expect(stored.fileSize, 3);
      });
    });

    group('remove', () {
      test('drops the named entry from the index', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        index.remove('a.txt');

        expect(index.getByPath('a.txt'), isNull);
        expect(index.entryCount, 1);
      });
    });

    group('removeByPath', () {
      test('removes an entry by working-directory path', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        index.removeByPath('a.txt');

        expect(index.getByPath('a.txt'), isNull);
        expect(index.entryCount, 1);
      });
    });

    group('removeDirectory', () {
      test('removes all entries under a directory prefix', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        index.removeDirectory('sub');

        expect(index.getByPath('sub/b.txt'), isNull);
        expect(index.entryCount, 1);
      });
    });

    group('removeAll', () {
      test('removes entries matching pathspecs', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        index.removeAll(['sub/*']);

        expect(index.getByPath('sub/b.txt'), isNull);
        expect(index.getByPath('a.txt'), isNotNull);
      });

      test('skips entries when the callback returns a positive value', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        final visited = <String>[];
        index.removeAll(
          ['*.txt'],
          onMatch: (path, _) {
            visited.add(path);
            return 1; // skip all
          },
        );

        expect(visited, isNotEmpty);
        expect(index.entryCount, 2);
      });
    });

    group('updateAll', () {
      test('re-hashes a modified file and updates its index entry', () {
        git.writeFile('a.txt', 'updated\n');

        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        final before = index.getByPath('a.txt')!.id;
        index.updateAll(['a.txt']);
        final after = index.getByPath('a.txt')!.id;

        expect(after, isNot(equals(before)));
      });
    });

    group('clear', () {
      test('empties the index in memory', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        index.clear();

        expect(index.entryCount, 0);
      });
    });

    group('find / findPrefix', () {
      test('returns positions for exact and prefix matches', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        expect(index.find('a.txt'), 0);
        expect(index.find('missing'), isNull);
        expect(index.findPrefix('sub/'), 1);
      });
    });

    group('addAll', () {
      test('adds matching files and honors a skip callback', () {
        git.writeFile('c.txt', 'c\n');
        git.writeFile('d.txt', 'd\n');

        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        final visited = <String>[];
        index.addAll(
          ['*.txt'],
          onMatch: (path, _) {
            visited.add(path);
            return path == 'd.txt' ? 1 : 0;
          },
        );

        expect(visited, containsAll(['c.txt', 'd.txt']));
        expect(index.getByPath('c.txt'), isNotNull);
        expect(index.getByPath('d.txt'), isNull);
      });
    });

    group('readTree', () {
      test('replaces the index contents with a tree', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        final treeId = git.oid('HEAD^{tree}');
        final tree = Tree.lookup(repo, treeId);
        addTearDown(tree.dispose);

        index.clear();
        index.readTree(tree);

        expect(index.entryCount, 2);
      });
    });

    group('conflicts', () {
      test('records, reads, lists, and removes a conflict', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        final oid = index.getByPath('a.txt')!.id;
        final ancestor = IndexEntry(
          path: 'merge.txt',
          id: oid,
          flags: 1 << Index.entryStageShift,
        );
        final ours = IndexEntry(
          path: 'merge.txt',
          id: oid,
          flags: 2 << Index.entryStageShift,
        );
        final theirs = IndexEntry(
          path: 'merge.txt',
          id: oid,
          flags: 3 << Index.entryStageShift,
        );

        index.addConflict(ancestor: ancestor, ours: ours, theirs: theirs);

        expect(index.hasConflicts, isTrue);
        final got = index.getConflict('merge.txt')!;
        expect(got.ancestor!.path, 'merge.txt');
        expect(got.ours!.stage, 2);
        expect(got.theirs!.stage, 3);

        final listed = index.conflicts().toList();
        expect(listed.length, 1);

        index.cleanupConflicts();
        expect(index.hasConflicts, isFalse);
      });
    });

    group('capabilities', () {
      test('round-trips capability flags', () {
        final index = Index.fromRepository(repo);
        addTearDown(index.dispose);

        index.capabilities = {IndexCapability.noFilemode};

        expect(index.capabilities, contains(IndexCapability.noFilemode));
      });
    });

    group('==', () {
      test('different handles are not equal', () {
        final a = Index.fromRepository(repo);
        addTearDown(a.dispose);
        final b = Index.fromRepository(repo);
        addTearDown(b.dispose);

        expect(a, isNot(equals(b)));
      });
    });
  });

  group('IndexEntry', () {
    group('==', () {
      test('entries with identical fields compare equal', () {
        final a = IndexEntry(path: 'a', fileSize: 10);
        final b = IndexEntry(path: 'a', fileSize: 10);
        final c = IndexEntry(path: 'a', fileSize: 11);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
        expect(a, isNot(equals(c)));
      });
    });

    group('stage', () {
      test('extracts the stage from the flags field', () {
        final entry = IndexEntry(path: 'x', flags: 2 << Index.entryStageShift);

        expect(entry.stage, 2);
        expect(entry.isConflict, isTrue);
      });
    });
  });
}
