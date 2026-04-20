@Tags(['ffi'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Diff', () {
    late GitFixture git;
    late Repository repo;
    late Oid firstCommit;
    late Oid secondCommit;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      firstCommit = git.commit('first', files: {'a.txt': 'a1\na2\n'});
      secondCommit = git.commit(
        'second',
        files: {'a.txt': 'a1\na2+\n', 'b.txt': 'b1\n'},
      );
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('treeToTree', () {
      test('detects changes between two commit trees', () {
        final oldCommit = Commit.lookup(repo, firstCommit);
        addTearDown(oldCommit.dispose);
        final newCommit = Commit.lookup(repo, secondCommit);
        addTearDown(newCommit.dispose);
        final oldTree = oldCommit.tree();
        addTearDown(oldTree.dispose);
        final newTree = newCommit.tree();
        addTearDown(newTree.dispose);

        final diff = Diff.treeToTree(
          repo: repo,
          oldTree: oldTree,
          newTree: newTree,
        );
        addTearDown(diff.dispose);

        expect(diff.numDeltas, 2);
        final paths = diff.deltas.map((d) => d.newFile.path).toSet();
        expect(paths, {'a.txt', 'b.txt'});
        expect(
          diff.countDeltasOfType(DeltaStatus.added),
          1,
          reason: 'b.txt added',
        );
      });
    });

    group('treeToIndex', () {
      test('shows staged changes relative to a tree', () {
        // Stage a new file on top of the second commit.
        git.writeFile('c.txt', 'c\n');
        git.git(['add', 'c.txt']);

        final head = Commit.lookup(repo, secondCommit);
        addTearDown(head.dispose);
        final headTree = head.tree();
        addTearDown(headTree.dispose);

        final diff = Diff.treeToIndex(repo: repo, oldTree: headTree);
        addTearDown(diff.dispose);

        final paths = diff.deltas.map((d) => d.newFile.path).toSet();
        expect(paths, contains('c.txt'));
      });
    });

    group('treeToWorkdir', () {
      test('shows differences between a tree and the working directory', () {
        // Modify a.txt without staging.
        File('${git.path}/a.txt').writeAsStringSync('modified\n');

        final head = Commit.lookup(repo, secondCommit);
        addTearDown(head.dispose);
        final headTree = head.tree();
        addTearDown(headTree.dispose);

        final diff = Diff.treeToWorkdir(repo: repo, oldTree: headTree);
        addTearDown(diff.dispose);

        final paths = diff.deltas.map((d) => d.newFile.path).toSet();
        expect(paths, contains('a.txt'));
      });
    });

    group('treeToWorkdirWithIndex', () {
      test('blends tree-to-index and index-to-workdir diffs', () {
        // Modify a.txt without staging.
        File('${git.path}/a.txt').writeAsStringSync('modified\n');

        final head = Commit.lookup(repo, secondCommit);
        addTearDown(head.dispose);
        final headTree = head.tree();
        addTearDown(headTree.dispose);

        final diff = Diff.treeToWorkdirWithIndex(repo: repo, oldTree: headTree);
        addTearDown(diff.dispose);

        expect(diff.numDeltas, greaterThan(0));
      });
    });

    group('indexToWorkdir', () {
      test('detects unstaged edits in the working tree', () {
        File('${git.path}/a.txt').writeAsStringSync('a1\na2\na3\n');

        final diff = Diff.indexToWorkdir(repo: repo);
        addTearDown(diff.dispose);

        expect(diff.numDeltas, 1);
        expect(diff.getDelta(0)!.oldFile.path, 'a.txt');
      });
    });

    group('indexToIndex', () {
      test('diffs an empty index against a populated in-memory index', () {
        final oldIndex = Index.inMemory();
        addTearDown(oldIndex.dispose);

        // Build new index with one entry.
        final newIndex = Index.inMemory();
        addTearDown(newIndex.dispose);
        final blob = Blob.fromBuffer(
          repo,
          Uint8List.fromList('extra\n'.codeUnits),
        );
        addTearDown(blob.dispose);
        newIndex.add(IndexEntry(path: 'extra.txt', id: blob.id));

        final diff = Diff.indexToIndex(
          repo: repo,
          oldIndex: oldIndex,
          newIndex: newIndex,
        );
        addTearDown(diff.dispose);

        expect(diff.deltas.map((d) => d.newFile.path), contains('extra.txt'));
      });
    });

    group('compareBlobs', () {
      test('diffs two blobs and fires onLine for each changed line', () {
        final oldBlob = Blob.fromBuffer(
          repo,
          Uint8List.fromList('a\n'.codeUnits),
        );
        addTearDown(oldBlob.dispose);
        final newBlob = Blob.fromBuffer(
          repo,
          Uint8List.fromList('b\n'.codeUnits),
        );
        addTearDown(newBlob.dispose);

        var addedLines = 0;
        Diff.compareBlobs(
          oldBlob: oldBlob,
          newBlob: newBlob,
          oldAsPath: 'f.txt',
          newAsPath: 'f.txt',
          onLine: (d, h, l) {
            if (l.origin == '+'.codeUnitAt(0)) addedLines++;
            return 0;
          },
        );

        expect(addedLines, greaterThan(0));
      });
    });

    group('compareBlobToBuffer', () {
      test('diffs a blob against an in-memory buffer', () {
        final oldBlob = Blob.fromBuffer(
          repo,
          Uint8List.fromList('old\n'.codeUnits),
        );
        addTearDown(oldBlob.dispose);

        var addedLines = 0;
        Diff.compareBlobToBuffer(
          oldBlob: oldBlob,
          oldAsPath: 'f.txt',
          newBuffer: Uint8List.fromList('new\n'.codeUnits),
          newAsPath: 'f.txt',
          onLine: (d, h, l) {
            if (l.origin == '+'.codeUnitAt(0)) addedLines++;
            return 0;
          },
        );

        expect(addedLines, greaterThan(0));
      });
    });

    group('isSortedIcase', () {
      test('returns a bool for a freshly computed diff', () {
        final oldCommit = Commit.lookup(repo, firstCommit);
        addTearDown(oldCommit.dispose);
        final newCommit = Commit.lookup(repo, secondCommit);
        addTearDown(newCommit.dispose);
        final oldTree = oldCommit.tree();
        addTearDown(oldTree.dispose);
        final newTree = newCommit.tree();
        addTearDown(newTree.dispose);

        final diff = Diff.treeToTree(
          repo: repo,
          oldTree: oldTree,
          newTree: newTree,
        );
        addTearDown(diff.dispose);

        expect(diff.isSortedIcase, isA<bool>());
      });
    });

    group('merge', () {
      test('combines two diffs so all deltas are visible', () {
        File('${git.path}/a.txt').writeAsStringSync('modified\n');
        final left = Diff.indexToWorkdir(repo: repo);
        addTearDown(left.dispose);

        git.writeFile('d.txt', 'd\n');
        git.git(['add', 'd.txt']);
        final right = Diff.indexToWorkdir(repo: repo);
        addTearDown(right.dispose);

        left.merge(right);

        // After merge the combined diff contains at least the a.txt change.
        expect(left.numDeltas, greaterThan(0));
      });
    });

    group('findSimilar', () {
      test('detects renames when a file is moved', () {
        git.git(['mv', 'a.txt', 'a_renamed.txt']);

        final oldCommit = Commit.lookup(repo, secondCommit);
        addTearDown(oldCommit.dispose);
        final oldTree = oldCommit.tree();
        addTearDown(oldTree.dispose);

        final diff = Diff.treeToIndex(repo: repo, oldTree: oldTree);
        addTearDown(diff.dispose);

        diff.findSimilar(
          const DiffFindOptions(flags: {DiffFindOption.findRenames}),
        );

        final statuses = diff.deltas.map((d) => d.status).toSet();
        expect(statuses, contains(DeltaStatus.renamed));
      });
    });

    group('patchId', () {
      test('returns a stable Oid for a diff', () {
        final oldCommit = Commit.lookup(repo, firstCommit);
        addTearDown(oldCommit.dispose);
        final newCommit = Commit.lookup(repo, secondCommit);
        addTearDown(newCommit.dispose);
        final oldTree = oldCommit.tree();
        addTearDown(oldTree.dispose);
        final newTree = newCommit.tree();
        addTearDown(newTree.dispose);

        final diff = Diff.treeToTree(
          repo: repo,
          oldTree: oldTree,
          newTree: newTree,
        );
        addTearDown(diff.dispose);

        expect(diff.patchId, isA<Oid>());
      });
    });

    group('toText', () {
      test('formats a patch containing diff hunks', () {
        final oldCommit = Commit.lookup(repo, firstCommit);
        addTearDown(oldCommit.dispose);
        final newCommit = Commit.lookup(repo, secondCommit);
        addTearDown(newCommit.dispose);
        final oldTree = oldCommit.tree();
        addTearDown(oldTree.dispose);
        final newTree = newCommit.tree();
        addTearDown(newTree.dispose);

        final diff = Diff.treeToTree(
          repo: repo,
          oldTree: oldTree,
          newTree: newTree,
        );
        addTearDown(diff.dispose);

        expect(diff.toText(), contains('diff --git'));
        expect(diff.toText(), contains('b.txt'));
      });
    });

    group('stats', () {
      test('reports insertion, deletion, and file counts', () {
        final oldCommit = Commit.lookup(repo, firstCommit);
        addTearDown(oldCommit.dispose);
        final newCommit = Commit.lookup(repo, secondCommit);
        addTearDown(newCommit.dispose);
        final oldTree = oldCommit.tree();
        addTearDown(oldTree.dispose);
        final newTree = newCommit.tree();
        addTearDown(newTree.dispose);

        final diff = Diff.treeToTree(
          repo: repo,
          oldTree: oldTree,
          newTree: newTree,
        );
        addTearDown(diff.dispose);

        final stats = diff.stats;
        addTearDown(stats.dispose);

        expect(stats.filesChanged, 2);
        expect(stats.insertions, greaterThan(0));
        expect(stats.deletions, greaterThanOrEqualTo(0));
      });
    });

    group('DiffStats.toText', () {
      test('formats stats as a readable summary string', () {
        final oldCommit = Commit.lookup(repo, firstCommit);
        addTearDown(oldCommit.dispose);
        final newCommit = Commit.lookup(repo, secondCommit);
        addTearDown(newCommit.dispose);
        final oldTree = oldCommit.tree();
        addTearDown(oldTree.dispose);
        final newTree = newCommit.tree();
        addTearDown(newTree.dispose);

        final diff = Diff.treeToTree(
          repo: repo,
          oldTree: oldTree,
          newTree: newTree,
        );
        addTearDown(diff.dispose);

        final stats = diff.stats;
        addTearDown(stats.dispose);

        final text = stats.toText();
        expect(text, isNotEmpty);
      });
    });

    group('foreach', () {
      test('visits one delta for every changed path', () {
        final oldCommit = Commit.lookup(repo, firstCommit);
        addTearDown(oldCommit.dispose);
        final newCommit = Commit.lookup(repo, secondCommit);
        addTearDown(newCommit.dispose);
        final oldTree = oldCommit.tree();
        addTearDown(oldTree.dispose);
        final newTree = newCommit.tree();
        addTearDown(newTree.dispose);

        final diff = Diff.treeToTree(
          repo: repo,
          oldTree: oldTree,
          newTree: newTree,
        );
        addTearDown(diff.dispose);

        final visited = <String>[];
        diff.foreach(
          onFile: (delta, _) {
            visited.add(delta.newFile.path);
            return 0;
          },
        );

        expect(visited, containsAll(['a.txt', 'b.txt']));
      });
    });

    group('statusChar', () {
      test('maps status values to git --name-status letters', () {
        expect(Diff.statusChar(DeltaStatus.added), 'A');
        expect(Diff.statusChar(DeltaStatus.modified), 'M');
        expect(Diff.statusChar(DeltaStatus.deleted), 'D');
      });
    });

    group('fromBuffer', () {
      test('parses a git-formatted patch back into a diff', () {
        final oldCommit = Commit.lookup(repo, firstCommit);
        addTearDown(oldCommit.dispose);
        final newCommit = Commit.lookup(repo, secondCommit);
        addTearDown(newCommit.dispose);
        final oldTree = oldCommit.tree();
        addTearDown(oldTree.dispose);
        final newTree = newCommit.tree();
        addTearDown(newTree.dispose);

        final diff = Diff.treeToTree(
          repo: repo,
          oldTree: oldTree,
          newTree: newTree,
        );
        addTearDown(diff.dispose);

        final parsed = Diff.fromBuffer(
          Uint8List.fromList(diff.toText().codeUnits),
        );
        addTearDown(parsed.dispose);

        expect(parsed.numDeltas, 2);
      });
    });

    group('printLines', () {
      test('streams one line per emitted diff line', () {
        final oldCommit = Commit.lookup(repo, firstCommit);
        addTearDown(oldCommit.dispose);
        final newCommit = Commit.lookup(repo, secondCommit);
        addTearDown(newCommit.dispose);
        final oldTree = oldCommit.tree();
        addTearDown(oldTree.dispose);
        final newTree = newCommit.tree();
        addTearDown(newTree.dispose);

        final diff = Diff.treeToTree(
          repo: repo,
          oldTree: oldTree,
          newTree: newTree,
        );
        addTearDown(diff.dispose);

        var lines = 0;
        diff.printLines((d, h, l) {
          lines++;
          return 0;
        });

        expect(lines, greaterThan(0));
      });
    });

    group('compareBuffers', () {
      test('diffs two in-memory buffers and fires onLine for each change', () {
        var addedLines = 0;
        Diff.compareBuffers(
          oldBuffer: Uint8List.fromList('a\n'.codeUnits),
          newBuffer: Uint8List.fromList('b\n'.codeUnits),
          oldAsPath: 'f.txt',
          newAsPath: 'f.txt',
          onLine: (d, h, l) {
            if (l.origin == '+'.codeUnitAt(0)) addedLines++;
            return 0;
          },
        );
        expect(addedLines, greaterThan(0));
      });
    });
  });

  group('DiffOptions', () {
    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    group('==', () {
      test('two identical DiffOptions instances compare equal', () {
        const a = DiffOptions(contextLines: 5, idAbbrev: 10);
        const b = DiffOptions(contextLines: 5, idAbbrev: 10);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('DiffOptions with different fields are not equal', () {
        const a = DiffOptions(contextLines: 5);
        const b = DiffOptions(contextLines: 6);

        expect(a, isNot(equals(b)));
      });
    });
  });

  group('DiffFindOptions', () {
    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    group('==', () {
      test('two identical DiffFindOptions instances compare equal', () {
        const a = DiffFindOptions(renameThreshold: 70);
        const b = DiffFindOptions(renameThreshold: 70);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('DiffFindOptions with different fields are not equal', () {
        const a = DiffFindOptions(renameThreshold: 60);
        const b = DiffFindOptions(renameThreshold: 80);

        expect(a, isNot(equals(b)));
      });
    });
  });
}
