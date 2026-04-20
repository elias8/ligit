@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('RepositoryGraph', () {
    late GitFixture git;
    late Repository repo;
    late Oid firstId;
    late Oid secondId;
    late Oid thirdId;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('c0', files: {'a.txt': 'c0\n'});
      git.commit('c1', files: {'a.txt': 'c1\n'});
      git.commit('c2', files: {'a.txt': 'c2\n'});

      firstId = git.oid('HEAD~2');
      secondId = git.oid('HEAD~');
      thirdId = git.oid('HEAD');

      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('aheadBehind', () {
      test('counts commits on each side of a linear range', () {
        expect(repo.aheadBehind(thirdId, firstId), (ahead: 2, behind: 0));
        expect(repo.aheadBehind(firstId, thirdId), (ahead: 0, behind: 2));
      });
    });

    group('descendantOf', () {
      test('is true for a strict descendant and false otherwise', () {
        expect(repo.descendantOf(commit: thirdId, ancestor: firstId), isTrue);
        expect(repo.descendantOf(commit: firstId, ancestor: thirdId), isFalse);
        expect(repo.descendantOf(commit: thirdId, ancestor: thirdId), isFalse);
      });
    });

    group('reachableFromAny', () {
      test('returns true when any descendant reaches the commit', () {
        expect(repo.reachableFromAny(firstId, [thirdId]), isTrue);
        expect(repo.reachableFromAny(thirdId, [secondId]), isFalse);
      });
    });
  });
}
