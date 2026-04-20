@Tags(['ffi'])
library;

import 'dart:io';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('DescribeResult', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('initial', files: {'a.txt': 'hello\n'});
      git.git(['tag', '-a', 'v1.0', '-m', 'release']);
      git.commit('second', files: {'a.txt': 'second\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('workdir', () {
      test('formats tag-distance-hash for a clean worktree', () {
        final desc = DescribeResult.workdir(repo);
        addTearDown(desc.dispose);

        expect(desc.format(), matches(RegExp(r'^v1\.0-1-g[0-9a-f]+$')));
      });

      test('appends dirtySuffix when the worktree is modified', () {
        File('${git.path}/a.txt').writeAsStringSync('dirty\n');

        final desc = DescribeResult.workdir(repo);
        addTearDown(desc.dispose);

        expect(desc.format(dirtySuffix: '-dirty'), endsWith('-dirty'));
      });

      test('alwaysUseLongFormat keeps tag-N-hash even at exact tag', () {
        // Describe the tagged commit itself; without long format it
        // would render as just "v1.0".
        final taggedObj = repo.revParseSingle('v1.0^{}');
        addTearDown(taggedObj.dispose);

        final desc = DescribeResult.commit(taggedObj);
        addTearDown(desc.dispose);

        expect(
          desc.format(alwaysUseLongFormat: true),
          matches(RegExp(r'^v1\.0-0-g[0-9a-f]+$')),
        );
      });
    });

    group('commit', () {
      test('describes HEAD against nearby tags', () {
        final obj = repo.revParseSingle('HEAD');
        addTearDown(obj.dispose);

        final desc = DescribeResult.commit(obj);
        addTearDown(desc.dispose);

        expect(desc.format(), startsWith('v1.0'));
      });

      test('falls back to commit OID when no tag matches and fallback set', () {
        final obj = repo.revParseSingle('HEAD~');
        addTearDown(obj.dispose);

        final desc = DescribeResult.commit(
          obj,
          strategy: DescribeStrategy.tags,
          pattern: 'no-such-tag-*',
          showCommitOidAsFallback: true,
        );
        addTearDown(desc.dispose);

        expect(desc.format(), matches(RegExp(r'^[0-9a-f]{7,}$')));
      });

      test('onlyFollowFirstParent limits ancestor traversal', () {
        final obj = repo.revParseSingle('HEAD');
        addTearDown(obj.dispose);

        final desc = DescribeResult.commit(obj, onlyFollowFirstParent: true);
        addTearDown(desc.dispose);

        expect(desc.format(), startsWith('v1.0'));
      });
    });
  });
}
