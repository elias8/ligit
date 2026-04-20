@Tags(['ffi'])
library;

import 'dart:io';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Pathspec', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit(
        'seed',
        files: {'a.txt': 'a\n', 'b.txt': 'b\n', 'c.md': 'c\n'},
      );
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('matchesPath', () {
      test('matches glob patterns against literal paths', () {
        final spec = Pathspec(const ['*.dart', 'lib/**']);
        addTearDown(spec.dispose);

        expect(spec.matchesPath('foo.dart'), isTrue);
        expect(spec.matchesPath('lib/sub/x.txt'), isTrue);
        expect(spec.matchesPath('other.txt'), isFalse);
      });
    });

    group('matchWorkdir', () {
      test('returns matched filenames in the working directory', () {
        final spec = Pathspec(const ['*.txt']);
        addTearDown(spec.dispose);

        final matches = spec.matchWorkdir(repo);
        addTearDown(matches.dispose);

        final names = [
          for (var i = 0; i < matches.length; i++) matches.entry(i),
        ];
        expect(names, containsAll(['a.txt', 'b.txt']));
      });

      test('reports unmatched patterns when findFailures is set', () {
        final spec = Pathspec(const ['*.txt', 'nothing/*']);
        addTearDown(spec.dispose);

        final matches = spec.matchWorkdir(
          repo,
          flags: {PathspecFlag.findFailures},
        );
        addTearDown(matches.dispose);

        expect(matches.failedLength, 1);
        expect(matches.failedEntry(0), 'nothing/*');
      });
    });

    group('matchTree', () {
      test('lists files from HEAD that match the pathspec', () {
        final head = repo.revParseSingle('HEAD^{tree}');
        addTearDown(head.dispose);
        final tree = Tree.lookup(repo, head.id);
        addTearDown(tree.dispose);

        final spec = Pathspec(const ['*.txt']);
        addTearDown(spec.dispose);

        final matches = spec.matchTree(tree);
        addTearDown(matches.dispose);

        expect(matches.length, 2);
      });
    });

    group('matchIndex', () {
      test('lists index entries matching the pathspec', () {
        final index = repo.index();
        addTearDown(index.dispose);

        final spec = Pathspec(const ['*.txt']);
        addTearDown(spec.dispose);

        final matches = spec.matchIndex(index);
        addTearDown(matches.dispose);

        expect(matches.length, 2);
      });
    });

    group('matchDiff', () {
      test('returns the diff delta entries, not filenames', () {
        File('${git.path}/a.txt').writeAsStringSync('edited\n');

        final head = repo.revParseSingle('HEAD^{tree}');
        addTearDown(head.dispose);
        final oldTree = Tree.lookup(repo, head.id);
        addTearDown(oldTree.dispose);

        final diff = Diff.treeToWorkdir(repo: repo, oldTree: oldTree);
        addTearDown(diff.dispose);

        final spec = Pathspec(const ['*.txt']);
        addTearDown(spec.dispose);

        final matches = spec.matchDiff(diff);
        addTearDown(matches.dispose);

        expect(matches.length, greaterThan(0));
        expect(matches.entry(0), isNull);
        expect(matches.diffEntry(0), isNotNull);
      });
    });
  });
}
