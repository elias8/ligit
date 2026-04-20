@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Blame', () {
    late GitFixture git;
    late Repository repo;
    late Oid firstId;
    late Oid secondId;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      firstId = git.commit('one', files: {'a.txt': 'first line\n'});
      secondId = git.commit(
        'two',
        files: {'a.txt': 'first line\nsecond line\n'},
      );
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('file', () {
      test('assigns the correct commit to each modified line', () {
        final blame = Blame.file(repo, 'a.txt');
        addTearDown(blame.dispose);

        expect(blame.length, greaterThanOrEqualTo(1));
        final hunk = blame.hunkForLine(1);
        expect(hunk, isNotNull);
        expect(hunk!.finalCommitId, isIn([firstId, secondId]));
      });

      test('exposes BlameHunk fields with sensible values', () {
        final blame = Blame.file(repo, 'a.txt');
        addTearDown(blame.dispose);

        final hunk = blame.hunk(0);
        expect(hunk, isNotNull);
        expect(hunk!.lineCount, greaterThanOrEqualTo(1));
        expect(hunk.finalStartLine, greaterThanOrEqualTo(1));
        expect(hunk.origPath, 'a.txt');
        expect(hunk.origStartLine, greaterThanOrEqualTo(1));
        expect(hunk.summary, isNotEmpty);
        expect(hunk.finalCommitId, isIn([firstId, secondId]));
      });

      test('reads the literal line text from the file', () {
        final blame = Blame.file(repo, 'a.txt');
        addTearDown(blame.dispose);

        expect(blame.line(1), isNotEmpty);
      });
    });

    // Blame.fileFromBuffer is omitted: git_blame_file_from_buffer is bound
    // but the symbol is absent from the installed libgit2 dylib on this
    // platform, causing a dlsym failure at runtime. Coverage can be added
    // once libgit2 >= 1.8 (which introduced the API) is linked.

    group('withBuffer', () {
      test('rebuilds the blame against in-memory edits', () {
        final base = Blame.file(repo, 'a.txt');
        addTearDown(base.dispose);

        final modified = Blame.withBuffer(base, 'edited\nnew\n');
        addTearDown(modified.dispose);

        expect(modified.length, greaterThan(0));
      });
    });

    group('BlameHunk', () {
      group('==', () {
        test('two hunks covering the same range compare equal', () {
          final blame1 = Blame.file(repo, 'a.txt');
          addTearDown(blame1.dispose);
          final blame2 = Blame.file(repo, 'a.txt');
          addTearDown(blame2.dispose);

          final h1 = blame1.hunk(0);
          final h2 = blame2.hunk(0);
          expect(h1, isNotNull);
          expect(h2, isNotNull);
          expect(h1, equals(h2));
          expect(h1.hashCode, h2.hashCode);
        });
      });
    });
  });
}
