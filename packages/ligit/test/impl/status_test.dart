@Tags(['ffi'])
library;

import 'dart:io';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('RepositoryStatus', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit(
        'initial',
        files: {'a.txt': 'clean\n', '.gitignore': '*.log\n'},
      );
      // Dirty the worktree.
      File('${git.path}/a.txt').writeAsStringSync('modified\n');
      File('${git.path}/new.txt').writeAsStringSync('new\n');
      File('${git.path}/ignored.log').writeAsStringSync('noise\n');
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('status', () {
      test('reports modified, new, and ignored files', () {
        final entries = repo.status();
        final byPath = {for (final e in entries) e.path: e};

        expect(byPath['a.txt']!.flags, contains(StatusFlag.wtModified));
        expect(byPath['new.txt']!.flags, contains(StatusFlag.wtNew));
        expect(byPath['ignored.log']!.isIgnored, isTrue);
      });
    });

    group('fileStatus', () {
      test('returns the flag set for a single path', () {
        expect(repo.fileStatus('a.txt'), contains(StatusFlag.wtModified));
      });

      test('throws NotFoundException when the path is absent', () {
        expect(
          () => repo.fileStatus('missing.txt'),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('forEachStatus', () {
      test('visits each changed path and reports modifications', () {
        final seen = <String, Set<StatusFlag>>{};
        repo.forEachStatus((entry) {
          seen[entry.path] = entry.flags;
          return 0;
        });

        expect(seen['a.txt'], contains(StatusFlag.wtModified));
        expect(seen['new.txt'], contains(StatusFlag.wtNew));
      });
    });

    group('shouldIgnore', () {
      test('honors .gitignore rules', () {
        expect(repo.shouldIgnore('whatever.log'), isTrue);
        expect(repo.shouldIgnore('new.txt'), isFalse);
      });
    });

    group('StatusEntry.isCurrent', () {
      test('is true for an unmodified committed file', () {
        // Re-open on a clean repo with no working-tree changes.
        final cleanGit = GitFixture.init();
        addTearDown(cleanGit.dispose);
        cleanGit.commit('init', files: {'z.txt': 'stable\n'});
        final cleanRepo = Repository.open(cleanGit.path);
        addTearDown(cleanRepo.dispose);

        final entries = cleanRepo.status(
          options: {StatusOption.includeUnmodified},
        );
        final entry = entries.firstWhere((e) => e.path == 'z.txt');

        expect(entry.isCurrent, isTrue);
      });

      test('is false for a modified file', () {
        final entries = repo.status();
        final modified = entries.firstWhere((e) => e.path == 'a.txt');

        expect(modified.isCurrent, isFalse);
      });
    });

    group('StatusEntry.isConflicted', () {
      test('is true after a conflicting merge', () {
        // Build a two-branch conflict on a.txt.
        final conflictGit = GitFixture.init();
        addTearDown(conflictGit.dispose);
        conflictGit.commit('base', files: {'a.txt': 'base\n'});
        conflictGit.git(['checkout', '-b', 'branch']);
        conflictGit.commit('branch', files: {'a.txt': 'branch\n'});
        conflictGit.git(['checkout', 'main']);
        conflictGit.commit('main', files: {'a.txt': 'main\n'});
        // Force a conflicting merge (ignore exit code — it will be non-zero).
        Process.runSync('git', ['-C', conflictGit.path, 'merge', 'branch']);

        final conflictRepo = Repository.open(conflictGit.path);
        addTearDown(conflictRepo.dispose);

        final entries = conflictRepo.status();
        final conflicted = entries.firstWhere((e) => e.path == 'a.txt');

        expect(conflicted.isConflicted, isTrue);
      });
    });

    group('StatusEntry ==', () {
      test('two entries with the same path and flags are equal', () {
        final a = repo.status().firstWhere((e) => e.path == 'a.txt');
        final b = repo.status().firstWhere((e) => e.path == 'a.txt');

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('entries with different paths are not equal', () {
        final entries = repo.status();
        final a = entries.firstWhere((e) => e.path == 'a.txt');
        final b = entries.firstWhere((e) => e.path == 'new.txt');

        expect(a, isNot(equals(b)));
      });
    });
  });
}
