@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Note', () {
    late GitFixture git;
    late Repository repo;
    late Oid headId;
    late Signature sig;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      headId = git.commit('initial', files: {'a.txt': 'hello\n'});
      sig = Signature(
        name: 'Ada',
        email: 'ada@example.com',
        when: DateTime.utc(2021),
      );
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('read', () {
      test('reads the message and signatures of an attached note', () {
        repo.createNote(
          annotatedId: headId,
          message: 'hello notes',
          author: sig,
          committer: sig,
        );

        final note = Note.read(repo, headId);
        addTearDown(note.dispose);
        expect(note.message, 'hello notes');
        expect(note.author.name, 'Ada');
        expect(note.committer.email, 'ada@example.com');
      });

      test('throws NotFoundException when no note exists', () {
        expect(
          () => Note.read(repo, headId),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('readFromCommit', () {
      test('reads a note from a dangling notes commit', () {
        final r = repo.createNoteCommit(
          annotatedId: headId,
          message: 'dangling note',
          author: sig,
          committer: sig,
        );

        final notesCommit = Commit.lookup(repo, r.notesCommit);
        addTearDown(notesCommit.dispose);

        final note = Note.readFromCommit(repo, notesCommit, headId);
        addTearDown(note.dispose);

        expect(note.message, 'dangling note');
      });
    });

    group('remove', () {
      test('removes a previously added note', () {
        repo.createNote(
          annotatedId: headId,
          message: 'bye',
          author: sig,
          committer: sig,
        );
        repo.removeNote(annotatedId: headId, author: sig, committer: sig);

        expect(
          () => Note.read(repo, headId),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('notes', () {
      test('iterates every attached note', () {
        repo.createNote(
          annotatedId: headId,
          message: 'iter',
          author: sig,
          committer: sig,
        );

        final entries = repo.notes();
        expect(entries, hasLength(1));
        expect(entries.first.annotatedObject, headId);
      });
    });

    group('forEachNote', () {
      test('yields every annotated object through the callback', () {
        repo.createNote(
          annotatedId: headId,
          message: 'iter',
          author: sig,
          committer: sig,
        );

        final annotated = <Oid>[];
        repo.forEachNote((noteBlob, annotatedObject) {
          annotated.add(annotatedObject);
          return 0;
        });

        expect(annotated, [headId]);
      });
    });

    group('defaultNotesRef', () {
      test('returns the standard notes reference name', () {
        expect(repo.defaultNotesRef(), 'refs/notes/commits');
      });
    });

    group('createNoteCommit', () {
      test('starts a new notes tree when parent is null', () {
        final r = repo.createNoteCommit(
          annotatedId: headId,
          message: 'first commit note',
          author: sig,
          committer: sig,
        );

        expect(r.notesCommit.isZero, isFalse);
        expect(r.notesBlob.isZero, isFalse);
      });

      test('layers a new note on top of an existing notes commit', () {
        final second = git.commit('second', files: {'b.txt': 'b\n'});

        final r1 = repo.createNoteCommit(
          annotatedId: headId,
          message: 'note on first',
          author: sig,
          committer: sig,
        );

        final parent = Commit.lookup(repo, r1.notesCommit);
        addTearDown(parent.dispose);

        final r2 = repo.createNoteCommit(
          annotatedId: second,
          message: 'note on second',
          author: sig,
          committer: sig,
          parent: parent,
        );

        expect(r2.notesCommit, isNot(equals(r1.notesCommit)));
      });

      test('overwrites an existing note when allowOverwrite is true', () {
        repo.createNoteCommit(
          annotatedId: headId,
          message: 'original',
          author: sig,
          committer: sig,
        );

        final r1 = repo.createNoteCommit(
          annotatedId: headId,
          message: 'original',
          author: sig,
          committer: sig,
        );

        final parent = Commit.lookup(repo, r1.notesCommit);
        addTearDown(parent.dispose);

        expect(
          () => repo.createNoteCommit(
            annotatedId: headId,
            message: 'overwritten',
            author: sig,
            committer: sig,
            parent: parent,
            allowOverwrite: true,
          ),
          returnsNormally,
        );
      });
    });
  });
}
