@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Revwalk', () {
    late GitFixture git;
    late Repository repo;
    late Oid firstId;
    late Oid secondId;
    late Oid thirdId;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      firstId = git.commit('c0', files: {'a.txt': 'content 0\n'});
      secondId = git.commit('c1', files: {'a.txt': 'content 1\n'});
      thirdId = git.commit('c2', files: {'a.txt': 'content 2\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('push / next', () {
      test('yields every ancestor of HEAD in reverse-chronological order', () {
        final walk = Revwalk(repo);
        addTearDown(walk.dispose);
        walk.pushHead();

        expect(walk.toIterable().toList(), [thirdId, secondId, firstId]);
      });
    });

    group('hide', () {
      test('skips a commit and its ancestors', () {
        final walk = Revwalk(repo);
        addTearDown(walk.dispose);
        walk.pushHead();
        walk.hide(secondId);

        expect(walk.toIterable().toList(), [thirdId]);
      });
    });

    group('hideGlob', () {
      test('hides commits reachable from refs matching a glob pattern', () {
        // Create a second branch pointing at firstId so that hiding
        // "refs/heads/old*" hides firstId and its ancestors.
        git.git(['branch', 'old-branch', firstId.sha]);

        final walk = Revwalk(repo);
        addTearDown(walk.dispose);
        walk.pushHead();
        walk.hideGlob('refs/heads/old*');

        final ids = walk.toIterable().toList();
        expect(ids, contains(thirdId));
        expect(ids, contains(secondId));
        expect(ids, isNot(contains(firstId)));
      });
    });

    group('pushGlob', () {
      test('pushes commits reachable from refs matching a glob pattern', () {
        // Tag both the first and third commits, then push using a tag glob.
        git.git(['tag', 'v1.0', firstId.sha]);
        git.git(['tag', 'v2.0', thirdId.sha]);

        final walk = Revwalk(repo);
        addTearDown(walk.dispose);
        walk.pushGlob('refs/tags/v*');

        final ids = walk.toIterable().toSet();
        expect(ids, containsAll([firstId, secondId, thirdId]));
      });
    });

    group('simplifyFirstParent', () {
      test('only visits first-parent ancestors', () {
        // Branch off at secondId, merge back to produce a merge commit.
        git.git(['checkout', '-b', 'side', secondId.sha]);
        final sideId = git.commit('side', files: {'side.txt': 'side\n'});
        git.git(['checkout', 'main']);
        git.git(['merge', '--no-ff', '-m', 'merge side', 'side']);

        final mergeId = git.oid('HEAD');

        final walk = Revwalk(repo);
        addTearDown(walk.dispose);
        walk.pushHead();
        walk.simplifyFirstParent();

        final ids = walk.toIterable().toList();
        // Should include merge commit and its first-parent chain.
        expect(ids, contains(mergeId));
        expect(ids, contains(thirdId));
        // The side branch commit is not on the first-parent chain.
        expect(ids, isNot(contains(sideId)));
      });
    });

    group('pushRange', () {
      test('pushes the right endpoint and hides the left', () {
        final walk = Revwalk(repo);
        addTearDown(walk.dispose);
        walk.pushRange('HEAD~2..HEAD');

        expect(walk.toIterable().toList(), [thirdId, secondId]);
      });
    });

    group('sorting', () {
      test('reverse order yields oldest first', () {
        final walk = Revwalk(repo);
        addTearDown(walk.dispose);
        walk.sorting({SortMode.topological, SortMode.reverse});
        walk.pushHead();

        expect(walk.toIterable().toList(), [firstId, secondId, thirdId]);
      });
    });

    group('reset', () {
      test('clears pushed commits so the next walk is empty', () {
        final walk = Revwalk(repo);
        addTearDown(walk.dispose);
        walk.pushHead();
        walk.reset();

        expect(walk.next(), isNull);
      });
    });

    group('addHideCallback', () {
      test('skips commits for which the callback returns non-zero', () {
        final walk = Revwalk(repo);
        addTearDown(walk.dispose);
        walk.pushHead();
        final dispose = walk.addHideCallback((id) => id == secondId ? 1 : 0);
        addTearDown(() => dispose?.call());

        expect(walk.toIterable().toList(), [thirdId]);
      });
    });

    group('pushRef / hideRef', () {
      test('walks commits reachable from a ref while hiding another', () {
        final walk = Revwalk(repo);
        addTearDown(walk.dispose);
        walk.pushRef('refs/heads/main');
        walk.hide(firstId);

        expect(walk.toIterable().toList(), [thirdId, secondId]);
      });
    });
  });
}
