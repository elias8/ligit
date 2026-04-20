@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('OdbBackend', () {
    late GitFixture git;
    late GitFixture alt;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      alt = GitFixture.init();
      git.commit('initial', files: {'a.txt': 'hello\n'});
      alt.commit('initial', files: {'a.txt': 'hello\n'});
    });

    tearDown(() {
      git.dispose();
      alt.dispose();
    });

    group('loose / addAlternate', () {
      test('resolves an object served only by the alternate backend', () {
        final altOdb = Odb.fromObjectsDir('${alt.path}/.git/objects');
        addTearDown(altOdb.dispose);
        final altId = altOdb.write(
          Uint8List.fromList('shared\n'.codeUnits),
          ObjectType.blob,
        );

        final odb = Odb.fromObjectsDir('${git.path}/.git/objects');
        addTearDown(odb.dispose);
        expect(odb.contains(altId), isFalse);

        odb.addAlternate(OdbBackend.loose('${alt.path}/.git/objects'));

        expect(odb.contains(altId), isTrue);
      });
    });

    group('pack / addBackend', () {
      test('wraps an existing pack directory and increments backendCount', () {
        git.git(['repack', '-a', '-d']);

        final odb = Odb.inMemory();
        addTearDown(odb.dispose);

        expect(odb.backendCount, 0);
        odb.addBackend(OdbBackend.pack('${git.path}/.git/objects'));
        expect(odb.backendCount, 1);
      });

      test('serves commits from the packed repo', () {
        git.git(['repack', '-a', '-d']);

        final headId = git.oid('HEAD');
        final fresh = Odb.inMemory();
        addTearDown(fresh.dispose);
        fresh.addBackend(OdbBackend.pack('${git.path}/.git/objects'));

        expect(fresh.contains(headId), isTrue);
      });
    });
  });
}
