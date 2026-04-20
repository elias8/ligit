@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Odb', () {
    late GitFixture git;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('initial', files: {'a.txt': 'hello\n'});
    });

    tearDown(() {
      git.dispose();
    });

    group('write / read', () {
      test('round-trips a blob and reports the same id back', () {
        final odb = Odb.fromObjectsDir('${git.path}/.git/objects');
        addTearDown(odb.dispose);

        final data = Uint8List.fromList('hi\n'.codeUnits);
        final id = odb.write(data, ObjectType.blob);

        expect(odb.contains(id), isTrue);

        final obj = odb.read(id);
        addTearDown(obj.dispose);

        expect(obj.id, id);
        expect(obj.type, ObjectType.blob);
        expect(obj.data, data);
      });
    });

    group('header', () {
      test('returns the object size and type without reading bytes', () {
        final odb = Odb.fromObjectsDir('${git.path}/.git/objects');
        addTearDown(odb.dispose);

        final id = odb.write(
          Uint8List.fromList('hello\n'.codeUnits),
          ObjectType.blob,
        );

        final h = odb.header(id);
        expect(h.type, ObjectType.blob);
        expect(h.size, 6);
      });
    });

    group('hash', () {
      test('computes the same id as a write but without writing', () {
        final odb = Odb.fromObjectsDir('${git.path}/.git/objects');
        addTearDown(odb.dispose);

        final data = Uint8List.fromList('reproducible\n'.codeUnits);
        final hashed = Odb.hash(data, ObjectType.blob);
        final written = odb.write(data, ObjectType.blob);

        expect(hashed, written);
      });
    });

    group('write / read streams', () {
      test('round-trips bytes through open stream and read stream', () {
        final odb = Odb.fromObjectsDir('${git.path}/.git/objects');
        addTearDown(odb.dispose);

        final payload = Uint8List.fromList('streamed\n'.codeUnits);
        final writer = odb.openWriteStream(payload.length, ObjectType.blob);
        writer.write(payload);
        final id = writer.finalize();
        writer.dispose();

        final reader = odb.openReadStream(id);
        addTearDown(reader.dispose);
        expect(reader.type, ObjectType.blob);
        expect(reader.size, payload.length);

        final collected = <int>[];
        while (collected.length < reader.size) {
          final chunk = reader.read(reader.size - collected.length);
          if (chunk.isEmpty) break;
          collected.addAll(chunk);
        }
        expect(collected, payload);
      });
    });

    group('expandIds', () {
      test('resolves short ids against stored objects', () {
        final odb = Odb.fromObjectsDir('${git.path}/.git/objects');
        addTearDown(odb.dispose);

        final oid = odb.write(
          Uint8List.fromList('expand\n'.codeUnits),
          ObjectType.blob,
        );

        final shortBytes = Uint8List(20);
        for (var i = 0; i < 3; i++) {
          shortBytes[i] = oid.bytes[i];
        }
        final resolved = odb.expandIds([
          (id: shortBytes, length: 6, type: ObjectType.any),
        ]);
        expect(resolved.single.id, oid);
      });
    });

    group('foreach', () {
      test('visits at least one stored OID', () {
        final odb = Odb.fromObjectsDir('${git.path}/.git/objects');
        addTearDown(odb.dispose);

        final visited = <Oid>[];
        odb.foreach((oid) {
          visited.add(oid);
          return 0;
        });

        expect(visited, isNotEmpty);
      });
    });

    group('setCommitGraph', () {
      test('clears any installed commit-graph without error', () {
        final odb = Odb.fromObjectsDir('${git.path}/.git/objects');
        addTearDown(odb.dispose);

        expect(() => odb.setCommitGraph(0), returnsNormally);
      });
    });

    group('writeMultiPackIndex', () {
      test('writes a multi-pack-index for a packed repository', () {
        git.git(['repack', '-a', '-d']);

        final repo = Repository.open(git.path);
        addTearDown(repo.dispose);
        final odb = repo.odb();
        addTearDown(odb.dispose);

        expect(odb.writeMultiPackIndex, returnsNormally);
      });
    });
  });
}
