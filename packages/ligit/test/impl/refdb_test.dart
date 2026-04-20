@Tags(['ffi'])
library;

import 'dart:io';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('RefDb', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('initial', files: {'a.txt': 'hello\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('fromRepository', () {
      test('opens a handle for the active refdb', () {
        final db = RefDb.fromRepository(repo);
        addTearDown(db.dispose);
      });
    });

    group('empty', () {
      test('constructs a distinct handle from the repository refdb', () {
        final db = RefDb.empty(repo);
        addTearDown(db.dispose);

        final fromRepo = RefDb.fromRepository(repo);
        addTearDown(fromRepo.dispose);

        // Both handles are valid but are not the same object.
        expect(db, isNot(same(fromRepo)));
      });
    });

    group('compress', () {
      test('packs loose refs on the default backend', () {
        final db = RefDb.open(repo);
        addTearDown(db.dispose);

        db.compress();
        expect(File('${git.path}/.git/packed-refs').existsSync(), isTrue);
      });
    });
  });
}
