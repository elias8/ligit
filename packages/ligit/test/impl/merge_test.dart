@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Merge', () {
    late GitFixture git;
    late Repository repo;
    late Oid baseCommit;
    late Oid mainTip;
    late Oid featureTip;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();

      git.commit('base', files: {'base.txt': 'base\n'});
      baseCommit = git.oid('HEAD');

      git.git(['checkout', '-b', 'feature']);
      git.commit('feature commit', files: {'feature.txt': 'feature\n'});
      featureTip = git.oid('HEAD');

      git.git(['checkout', 'main']);
      git.commit('main commit', files: {'main.txt': 'main\n'});
      mainTip = git.oid('HEAD');

      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('conflictMarkerSize', () {
      test('equals 7', () {
        expect(Merge.conflictMarkerSize, 7);
      });
    });

    group('base', () {
      test('returns the common ancestor of two branches', () {
        expect(Merge.base(repo, mainTip, featureTip), equals(baseCommit));
      });
    });

    group('bases', () {
      test('lists every merge base of two commits', () {
        expect(Merge.bases(repo, mainTip, featureTip), [baseCommit]);
      });
    });

    group('baseMany', () {
      test('finds the best common ancestor among three commits', () {
        final result = Merge.baseMany(repo, [mainTip, featureTip, baseCommit]);

        expect(result, equals(baseCommit));
      });
    });

    group('baseOctopus', () {
      test('finds a base for an octopus merge of three commits', () {
        final result = Merge.baseOctopus(repo, [
          mainTip,
          featureTip,
          baseCommit,
        ]);

        expect(result, isNotNull);
      });
    });

    group('analysis', () {
      test('reports normal merge for divergent branches', () {
        final head = AnnotatedCommit.lookup(repo, featureTip);
        addTearDown(head.dispose);

        final r = Merge.analysis(repo, [head]);

        expect(r.analysis, contains(MergeAnalysis.normal));
      });
    });

    group('analysisForRef', () {
      test('reports normal merge when analyzing against an explicit ref', () {
        final ourRef = Reference.lookup(repo, 'refs/heads/main');
        addTearDown(ourRef.dispose);
        final theirs = AnnotatedCommit.lookup(repo, featureTip);
        addTearDown(theirs.dispose);

        final r = Merge.analysisForRef(repo, ourRef, [theirs]);

        expect(r.analysis, contains(MergeAnalysis.normal));
      });
    });

    group('commits', () {
      test('produces an index with both branches files when clean', () {
        final ours = Commit.lookup(repo, mainTip);
        addTearDown(ours.dispose);
        final theirs = Commit.lookup(repo, featureTip);
        addTearDown(theirs.dispose);

        final index = Merge.commits(repo: repo, ours: ours, theirs: theirs);
        addTearDown(index.dispose);

        expect(index.hasConflicts, isFalse);
        expect(index.getByPath('main.txt'), isNotNull);
        expect(index.getByPath('feature.txt'), isNotNull);
      });
    });

    group('trees', () {
      test('produces a conflict-free index for a three-way tree merge', () {
        final baseC = Commit.lookup(repo, baseCommit);
        addTearDown(baseC.dispose);
        final oursC = Commit.lookup(repo, mainTip);
        addTearDown(oursC.dispose);
        final theirsC = Commit.lookup(repo, featureTip);
        addTearDown(theirsC.dispose);

        final baseTree = baseC.tree();
        addTearDown(baseTree.dispose);
        final oursTree = oursC.tree();
        addTearDown(oursTree.dispose);
        final theirsTree = theirsC.tree();
        addTearDown(theirsTree.dispose);

        final index = Merge.trees(
          repo: repo,
          ancestor: baseTree,
          ours: oursTree,
          theirs: theirsTree,
        );
        addTearDown(index.dispose);

        expect(index.hasConflicts, isFalse);
      });
    });

    group('file', () {
      test(
        'merges three buffers cleanly when changes are on different lines',
        () {
          final ancestor = MergeFileInput(
            contents: Uint8List.fromList('a\nb\nc\n'.codeUnits),
            path: 'f.txt',
          );
          final ours = MergeFileInput(
            contents: Uint8List.fromList('A\nb\nc\n'.codeUnits),
            path: 'f.txt',
          );
          final theirs = MergeFileInput(
            contents: Uint8List.fromList('a\nb\nC\n'.codeUnits),
            path: 'f.txt',
          );

          final result = Merge.file(
            ancestor: ancestor,
            ours: ours,
            theirs: theirs,
          );

          expect(result.automergeable, isTrue);
          expect(String.fromCharCodes(result.contents), 'A\nb\nC\n');
        },
      );

      test('reports a conflict when both sides modify the same line', () {
        final ancestor = MergeFileInput(
          contents: Uint8List.fromList('a\n'.codeUnits),
          path: 'f.txt',
        );
        final ours = MergeFileInput(
          contents: Uint8List.fromList('A\n'.codeUnits),
          path: 'f.txt',
        );
        final theirs = MergeFileInput(
          contents: Uint8List.fromList('B\n'.codeUnits),
          path: 'f.txt',
        );

        final result = Merge.file(
          ancestor: ancestor,
          ours: ours,
          theirs: theirs,
        );

        expect(result.automergeable, isFalse);
        expect(String.fromCharCodes(result.contents), contains('<<<<<<<'));
      });
    });

    group('fileFromIndex', () {
      test('merges three index entries and returns a clean result', () {
        final oursCommit = Commit.lookup(repo, mainTip);
        addTearDown(oursCommit.dispose);
        final theirsCommit = Commit.lookup(repo, featureTip);
        addTearDown(theirsCommit.dispose);

        final index = Merge.commits(
          repo: repo,
          ours: oursCommit,
          theirs: theirsCommit,
        );
        addTearDown(index.dispose);

        // base.txt is unchanged on both branches so merging is trivially clean.
        final baseEntry = index.getByPath('base.txt')!;
        final ancestor = IndexEntry(
          path: 'base.txt',
          id: baseEntry.id,
          fileSize: baseEntry.fileSize,
        );

        final result = Merge.fileFromIndex(
          repo: repo,
          ancestor: ancestor,
          ours: ancestor,
          theirs: ancestor,
        );

        expect(result.automergeable, isTrue);
      });
    });

    group('intoHead', () {
      test(
        'merges feature branch into HEAD and leaves merged files staged',
        () {
          final theirs = AnnotatedCommit.lookup(repo, featureTip);
          addTearDown(theirs.dispose);

          Merge.intoHead(repo: repo, theirHeads: [theirs]);

          final resultIndex = Index.fromRepository(repo);
          addTearDown(resultIndex.dispose);

          expect(resultIndex.getByPath('feature.txt'), isNotNull);
          expect(resultIndex.getByPath('main.txt'), isNotNull);
          expect(resultIndex.hasConflicts, isFalse);
        },
      );
    });
  });
}
