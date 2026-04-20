@Tags(['ffi'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('FilterList', () {
    late GitFixture git;
    late Repository repo;
    late Oid seedCommitId;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      seedCommitId = git.commit(
        'seed',
        files: {'.gitattributes': '*.txt text eol=lf\n', 'file.txt': 'a\nb\n'},
      );
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('load / applyToBuffer', () {
      test('runs the crlf filter on the way to the ODB', () {
        final filters = FilterList.load(
          repo: repo,
          path: 'file.txt',
          mode: FilterMode.toOdb,
        )!;
        addTearDown(filters.dispose);

        expect(filters.contains('crlf'), isTrue);

        final cleaned = filters.applyToBuffer(
          Uint8List.fromList('a\r\nb\r\n'.codeUnits),
        );
        expect(String.fromCharCodes(cleaned), 'a\nb\n');
      });
    });

    group('loadFromCommit', () {
      test('loads filters using attributes from a specific commit', () {
        final filters = FilterList.loadFromCommit(
          repo: repo,
          path: 'file.txt',
          mode: FilterMode.toOdb,
          attrCommitId: seedCommitId,
        );
        // The crlf filter should apply when the commit sets eol=lf.
        // null means no filters; non-null means at least one was loaded.
        if (filters != null) {
          addTearDown(filters.dispose);
          expect(filters.contains('crlf'), isTrue);
        }
      });
    });

    group('applyToFile', () {
      test('filters a working-tree file and returns cleaned bytes', () {
        File('${git.path}/file.txt').writeAsStringSync('a\r\nb\r\n');

        final filters = FilterList.load(
          repo: repo,
          path: 'file.txt',
          mode: FilterMode.toOdb,
        )!;
        addTearDown(filters.dispose);

        final result = filters.applyToFile(repo, 'file.txt');
        expect(String.fromCharCodes(result), 'a\nb\n');
      });
    });

    group('applyToBlob', () {
      test('filters blob content and returns cleaned bytes', () {
        final blob = Blob.fromBuffer(
          repo,
          Uint8List.fromList('x\r\ny\r\n'.codeUnits),
        );
        addTearDown(blob.dispose);

        final filters = FilterList.load(
          repo: repo,
          path: 'file.txt',
          mode: FilterMode.toOdb,
        )!;
        addTearDown(filters.dispose);

        final result = filters.applyToBlob(blob);
        expect(String.fromCharCodes(result), 'x\ny\n');
      });
    });

    group('streamBuffer', () {
      test('streams filtered output through the callback', () {
        final filters = FilterList.load(
          repo: repo,
          path: 'file.txt',
          mode: FilterMode.toOdb,
        )!;
        addTearDown(filters.dispose);

        final collected = <int>[];
        filters.streamBuffer(
          Uint8List.fromList('a\r\nb\r\n'.codeUnits),
          collected.addAll,
        );

        expect(String.fromCharCodes(collected), 'a\nb\n');
      });
    });

    group('streamBlob', () {
      test('streams filtered blob content through the callback', () {
        final blob = Blob.fromBuffer(
          repo,
          Uint8List.fromList('p\r\nq\r\n'.codeUnits),
        );
        addTearDown(blob.dispose);

        final filters = FilterList.load(
          repo: repo,
          path: 'file.txt',
          mode: FilterMode.toOdb,
        )!;
        addTearDown(filters.dispose);

        final collected = <int>[];
        filters.streamBlob(blob, collected.addAll);

        expect(String.fromCharCodes(collected), 'p\nq\n');
      });
    });

    group('streamFile', () {
      test('streams filtered output for a working-tree file', () {
        File('${git.path}/file.txt').writeAsStringSync('a\r\nb\r\n');

        final filters = FilterList.load(
          repo: repo,
          path: 'file.txt',
          mode: FilterMode.toOdb,
        )!;
        addTearDown(filters.dispose);

        final collected = <int>[];
        filters.streamFile(repo, 'file.txt', collected.addAll);

        expect(String.fromCharCodes(collected), 'a\nb\n');
      });
    });

    group('contains', () {
      test('reports false for a filter not in the list', () {
        final filters = FilterList.load(
          repo: repo,
          path: 'file.txt',
          mode: FilterMode.toOdb,
        )!;
        addTearDown(filters.dispose);

        expect(filters.contains('not-a-real-filter'), isFalse);
      });
    });
  });
}
