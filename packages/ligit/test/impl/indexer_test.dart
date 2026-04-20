@Tags(['ffi'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Indexer', () {
    late GitFixture git;
    late String outDir;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('initial', files: {'a.txt': 'hello\n'});
      git.git(['repack', '-a', '-d']);
      outDir = createTempDir();
    });

    tearDown(() {
      git.dispose();
      deleteTempDir(outDir);
    });

    Uint8List readPackFile() {
      final packDir = Directory('${git.path}/.git/objects/pack');
      final file = packDir.listSync().whereType<File>().firstWhere(
        (f) => f.path.endsWith('.pack'),
      );
      return file.readAsBytesSync();
    }

    group('append / commit', () {
      test('indexes a pack stream and produces a 40-hex pack name', () {
        final packBytes = readPackFile();
        final indexer = Indexer(outDir);
        addTearDown(indexer.dispose);

        indexer.append(Uint8List.fromList(packBytes));
        indexer.commit();

        expect(indexer.name, matches(RegExp(r'^[0-9a-f]{40}$')));
      });

      test('append returns an IndexerProgress with non-negative fields', () {
        final packBytes = readPackFile();
        final indexer = Indexer(outDir);
        addTearDown(indexer.dispose);

        final p = indexer.append(Uint8List.fromList(packBytes));

        expect(p.totalObjects, greaterThanOrEqualTo(0));
        expect(p.indexedObjects, greaterThanOrEqualTo(0));
        expect(p.receivedObjects, greaterThanOrEqualTo(0));
        expect(p.totalDeltas, greaterThanOrEqualTo(0));
        expect(p.indexedDeltas, greaterThanOrEqualTo(0));
        expect(p.receivedBytes, greaterThanOrEqualTo(0));
      });

      test('commit returns an IndexerProgress after finalizing', () {
        final packBytes = readPackFile();
        final indexer = Indexer(outDir);
        addTearDown(indexer.dispose);

        indexer.append(Uint8List.fromList(packBytes));
        final p = indexer.commit();

        // indexedObjects <= totalObjects (both may be zero for tiny packs)
        expect(p.indexedObjects, lessThanOrEqualTo(p.totalObjects + 1));
        expect(p.indexedDeltas, lessThanOrEqualTo(p.totalDeltas + 1));
      });

      test('writes a .pack file in the output directory', () {
        final packBytes = readPackFile();
        final indexer = Indexer(outDir);
        addTearDown(indexer.dispose);

        indexer.append(Uint8List.fromList(packBytes));
        indexer.commit();

        final outPackFiles = Directory(outDir)
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.pack'))
            .toList();
        expect(outPackFiles, hasLength(1));
      });
    });

    group('IndexerProgress', () {
      group('==', () {
        test('two snapshots from identical packs compare equal', () {
          final packBytes = readPackFile();

          final dir1 = createTempDir();
          addTearDown(() => deleteTempDir(dir1));
          final dir2 = createTempDir();
          addTearDown(() => deleteTempDir(dir2));

          final i1 = Indexer(dir1);
          addTearDown(i1.dispose);
          final i2 = Indexer(dir2);
          addTearDown(i2.dispose);

          final p1 = i1.append(Uint8List.fromList(packBytes));
          final p2 = i2.append(Uint8List.fromList(packBytes));

          expect(p1, equals(p2));
          expect(p1.hashCode, p2.hashCode);
        });

        test(
          'snapshots from packs with different object counts are not equal',
          () {
            // Second repo with two commits so its pack has more objects.
            final git2 = GitFixture.init();
            addTearDown(git2.dispose);
            git2.commit('c1', files: {'a.txt': 'hello\n'});
            git2.commit('c2', files: {'b.txt': 'world\n'});
            git2.git(['repack', '-a', '-d']);

            final packDir2 = Directory('${git2.path}/.git/objects/pack');
            final bigPack = packDir2
                .listSync()
                .whereType<File>()
                .firstWhere((f) => f.path.endsWith('.pack'))
                .readAsBytesSync();

            final dir1 = createTempDir();
            addTearDown(() => deleteTempDir(dir1));
            final dir2 = createTempDir();
            addTearDown(() => deleteTempDir(dir2));

            final i1 = Indexer(dir1);
            addTearDown(i1.dispose);
            final i2 = Indexer(dir2);
            addTearDown(i2.dispose);

            final p1 = i1.append(Uint8List.fromList(readPackFile()));
            i1.commit();
            final p2 = i2.append(Uint8List.fromList(bigPack));
            i2.commit();

            // Different packs produce different names (one object vs. many).
            expect(i1.name, isNot(equals(i2.name)));
            // The progress snapshots of differently-sized packs are not equal.
            expect(p1, isNot(equals(p2)));
          },
        );
      });
    });
  });
}
