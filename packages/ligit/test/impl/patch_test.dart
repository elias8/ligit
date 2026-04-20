@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Patch', () {
    late GitFixture git;
    late Repository repo;
    late Oid firstId;
    late Oid secondId;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      firstId = git.commit('first', files: {'a.txt': 'a1\na2\n'});
      secondId = git.commit('second', files: {'a.txt': 'a1\na2+\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('fromDiff', () {
      test('extracts a text patch for a modified delta', () {
        final firstC = Commit.lookup(repo, firstId);
        addTearDown(firstC.dispose);
        final secondC = Commit.lookup(repo, secondId);
        addTearDown(secondC.dispose);
        final oldTree = firstC.tree();
        addTearDown(oldTree.dispose);
        final newTree = secondC.tree();
        addTearDown(newTree.dispose);
        final diff = Diff.treeToTree(
          repo: repo,
          oldTree: oldTree,
          newTree: newTree,
        );
        addTearDown(diff.dispose);

        final patch = Patch.fromDiff(diff, 0);
        addTearDown(patch.dispose);

        expect(patch.numHunks, greaterThan(0));
        expect(patch.toText(), contains('@@'));
      });
    });

    group('fromBuffers', () {
      test('diffs two buffers and reports line stats', () {
        final patch = Patch.fromBuffers(
          oldBuffer: Uint8List.fromList('a\nb\nc\n'.codeUnits),
          newBuffer: Uint8List.fromList('a\nB\nc\n'.codeUnits),
          oldAsPath: 'f.txt',
          newAsPath: 'f.txt',
        );
        addTearDown(patch.dispose);

        final stats = patch.lineStats;
        expect(stats.additions, 1);
        expect(stats.deletions, 1);
      });
    });

    group('getHunk / getLineInHunk', () {
      test('walks hunks and the lines inside them', () {
        final patch = Patch.fromBuffers(
          oldBuffer: Uint8List.fromList('a\nb\n'.codeUnits),
          newBuffer: Uint8List.fromList('a\nB\n'.codeUnits),
          oldAsPath: 'f.txt',
          newAsPath: 'f.txt',
        );
        addTearDown(patch.dispose);

        final hunk = patch.getHunk(0);
        expect(hunk.lines, greaterThan(0));
        expect(hunk.hunk.header, contains('@@'));

        final line = patch.getLineInHunk(0, 0);
        expect(line.content, isNotEmpty);
      });
    });

    group('delta', () {
      test('returns the delta attached to the patch', () {
        final patch = Patch.fromBuffers(
          oldBuffer: Uint8List.fromList('a\n'.codeUnits),
          newBuffer: Uint8List.fromList('b\n'.codeUnits),
          oldAsPath: 'f.txt',
          newAsPath: 'f.txt',
        );
        addTearDown(patch.dispose);

        final delta = patch.delta;
        expect(delta, isNotNull);
        expect(delta!.newFile.path, 'f.txt');
      });
    });

    group('printLines', () {
      test('streams every emitted diff line through the callback', () {
        final patch = Patch.fromBuffers(
          oldBuffer: Uint8List.fromList('a\n'.codeUnits),
          newBuffer: Uint8List.fromList('b\n'.codeUnits),
          oldAsPath: 'f.txt',
          newAsPath: 'f.txt',
        );
        addTearDown(patch.dispose);

        var addedLines = 0;
        patch.printLines((delta, hunk, line) {
          if (line.origin == '+'.codeUnitAt(0)) addedLines += 1;
          return 0;
        });

        expect(addedLines, greaterThan(0));
      });
    });

    group('size', () {
      test('drops headers from the reported byte size on request', () {
        final patch = Patch.fromBuffers(
          oldBuffer: Uint8List.fromList('a\n'.codeUnits),
          newBuffer: Uint8List.fromList('b\n'.codeUnits),
          oldAsPath: 'f.txt',
          newAsPath: 'f.txt',
        );
        addTearDown(patch.dispose);

        final withAll = patch.size();
        final bodyOnly = patch.size(
          includeHunkHeaders: false,
          includeFileHeaders: false,
        );

        expect(bodyOnly, lessThan(withAll));
      });
    });
  });
}
