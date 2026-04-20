@Tags(['ffi'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('PackBuilder', () {
    late GitFixture git;
    late Repository repo;
    late Oid headId;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      headId = git.commit('initial', files: {'a.txt': 'hello\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('insertCommit / writeToBuffer', () {
      test('produces a non-empty pack and records the object count', () {
        final pb = PackBuilder.forRepository(repo);
        addTearDown(pb.dispose);

        pb.insertCommit(headId);
        final bytes = pb.writeToBuffer();

        expect(bytes, isNotEmpty);
        expect(pb.objectCount, greaterThan(0));
      });
    });

    group('insert', () {
      test('inserts a single blob object by oid', () {
        final blob = Blob.fromBuffer(
          repo,
          Uint8List.fromList('blob content\n'.codeUnits),
        );
        addTearDown(blob.dispose);

        final pb = PackBuilder.forRepository(repo);
        addTearDown(pb.dispose);

        pb.insert(blob.id);
        final bytes = pb.writeToBuffer();

        expect(bytes, isNotEmpty);
        expect(pb.objectCount, greaterThan(0));
      });
    });

    group('insertTree', () {
      test('inserts the root tree and all referenced objects', () {
        final commit = Commit.lookup(repo, headId);
        addTearDown(commit.dispose);
        final tree = commit.tree();
        addTearDown(tree.dispose);

        final pb = PackBuilder.forRepository(repo);
        addTearDown(pb.dispose);

        pb.insertTree(tree.id);
        final bytes = pb.writeToBuffer();

        expect(bytes, isNotEmpty);
        expect(pb.objectCount, greaterThan(0));
      });
    });

    group('insertWalk', () {
      test('inserts every commit in the walk and all referenced objects', () {
        final walk = Revwalk(repo);
        addTearDown(walk.dispose);
        walk.pushHead();

        final pb = PackBuilder.forRepository(repo);
        addTearDown(pb.dispose);

        pb.insertWalk(walk);
        final bytes = pb.writeToBuffer();

        expect(bytes, isNotEmpty);
        expect(pb.objectCount, greaterThan(0));
      });
    });

    group('insertRecursive', () {
      test('recursively inserts a commit and all its reachable objects', () {
        final pb = PackBuilder.forRepository(repo);
        addTearDown(pb.dispose);

        pb.insertRecursive(headId);
        final bytes = pb.writeToBuffer();

        expect(bytes, isNotEmpty);
        expect(pb.objectCount, greaterThan(0));
      });
    });

    group('foreach', () {
      test('streams packed object bytes through the callback', () {
        final pb = PackBuilder.forRepository(repo);
        addTearDown(pb.dispose);

        pb.insertCommit(headId);

        final chunks = <int>[];
        pb.foreach((buf) {
          chunks.addAll(buf);
          return 0;
        });

        expect(chunks, isNotEmpty);
      });
    });

    group('setProgressCallback', () {
      test('fires during the write with the configured callback', () {
        final pb = PackBuilder.forRepository(repo);
        addTearDown(pb.dispose);

        final stages = <int>{};
        final dispose = pb.setProgressCallback((stage, current, total) {
          stages.add(stage);
          return 0;
        });
        addTearDown(() => dispose?.call());

        pb.insertCommit(headId);
        pb.writeToBuffer();

        expect(stages, isNotEmpty);
      });
    });

    group('write', () {
      test('writes a pack/index pair to the given directory', () {
        final pb = PackBuilder.forRepository(repo);
        addTearDown(pb.dispose);

        final outDir = '${git.path}/packs';
        Directory(outDir).createSync();
        pb.insertCommit(headId);
        pb.write(path: outDir);

        final files = Directory(outDir)
            .listSync()
            .whereType<File>()
            .map((f) => f.path.split('/').last)
            .toList();
        expect(files.any((f) => f.endsWith('.pack')), isTrue);
        expect(files.any((f) => f.endsWith('.idx')), isTrue);
      });
    });
  });
}
