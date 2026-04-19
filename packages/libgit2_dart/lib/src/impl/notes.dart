part of 'api.dart';

/// A note attached to a Git object.
///
/// Notes carry commit-style metadata — author, committer, and
/// message — stored under a notes reference (typically
/// `refs/notes/commits`). Read one with [Note.read], walk them with
/// [RepositoryNotes.notes], and write them with
/// [RepositoryNotes.createNote]. Must be [dispose]d.
@immutable
final class Note {
  static final _finalizer = Finalizer<int>(noteFree);

  final int _handle;

  /// Reads the note attached to [annotatedId] in [repo].
  ///
  /// [notesRef] defaults to the repository's default notes ref (see
  /// [RepositoryNotes.defaultNotesRef]).
  ///
  /// Throws [NotFoundException] when no note exists.
  factory Note.read(Repository repo, Oid annotatedId, {String? notesRef}) {
    return Note._(
      noteRead(repo._handle, annotatedId._bytes, notesRef: notesRef),
    );
  }

  /// Reads the note attached to [annotatedId] from the notes commit
  /// [notesCommit].
  ///
  /// Use together with [RepositoryNotes.createNoteCommit] when notes
  /// live on a dangling commit that has not been written to a ref.
  factory Note.readFromCommit(
    Repository repo,
    Commit notesCommit,
    Oid annotatedId,
  ) {
    return Note._(
      noteCommitRead(repo._handle, notesCommit._handle, annotatedId._bytes),
    );
  }

  Note._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Author of this note.
  Signature get author {
    final r = signatureRead(noteAuthor(_handle));
    return Signature._(
      name: r.name,
      email: r.email,
      when: DateTime.fromMillisecondsSinceEpoch(r.time * 1000, isUtc: true),
      offset: r.offset,
    );
  }

  /// Committer of this note.
  Signature get committer {
    final r = signatureRead(noteCommitter(_handle));
    return Signature._(
      name: r.name,
      email: r.email,
      when: DateTime.fromMillisecondsSinceEpoch(r.time * 1000, isUtc: true),
      offset: r.offset,
    );
  }

  /// Message body of this note.
  String get message => noteMessage(_handle);

  /// [Oid] of the blob that stores this note.
  Oid get id => Oid._(noteId(_handle));

  /// Releases the note.
  void dispose() {
    _finalizer.detach(this);
    noteFree(_handle);
  }
}

/// Notes management on [Repository].
extension RepositoryNotes on Repository {
  /// Returns the default notes reference for this repository.
  ///
  /// Usually `refs/notes/commits`, but can be overridden through
  /// configuration.
  String defaultNotesRef() => noteDefaultRef(_handle);

  /// Attaches a note with [message] to [annotatedId] and returns the
  /// [Oid] of the new note blob.
  ///
  /// [author] and [committer] are the signatures recorded on the
  /// notes commit. [notesRef] defaults to [defaultNotesRef]. Set
  /// [force] to overwrite an existing note for the same object.
  Oid createNote({
    required Oid annotatedId,
    required String message,
    required Signature author,
    required Signature committer,
    String? notesRef,
    bool force = false,
  }) {
    final authorHandle = signatureNew(
      author.name,
      author.email,
      author._record.time,
      author._record.offset,
    );
    try {
      final committerHandle = signatureNew(
        committer.name,
        committer.email,
        committer._record.time,
        committer._record.offset,
      );
      try {
        return Oid._(
          noteCreate(
            _handle,
            authorHandle,
            committerHandle,
            annotatedId._bytes,
            message,
            notesRef: notesRef,
            force: force,
          ),
        );
      } finally {
        signatureFree(committerHandle);
      }
    } finally {
      signatureFree(authorHandle);
    }
  }

  /// Creates a dangling notes commit attaching [message] to
  /// [annotatedId] and returns the new commit and blob [Oid]s.
  ///
  /// The resulting commit is not attached to any reference. Pass
  /// its [Oid] to [Note.readFromCommit] to read notes stored on it.
  /// When [parent] is null, a new notes tree is started; otherwise
  /// the new commit layers on top of the existing notes tree in
  /// [parent]. Set [allowOverwrite] to replace an existing note for
  /// the same [annotatedId].
  ({Oid notesCommit, Oid notesBlob}) createNoteCommit({
    required Oid annotatedId,
    required String message,
    required Signature author,
    required Signature committer,
    Commit? parent,
    bool allowOverwrite = false,
  }) {
    final authorHandle = signatureNew(
      author.name,
      author.email,
      author._record.time,
      author._record.offset,
    );
    try {
      final committerHandle = signatureNew(
        committer.name,
        committer.email,
        committer._record.time,
        committer._record.offset,
      );
      try {
        final r = noteCommitCreate(
          _handle,
          parent?._handle,
          authorHandle,
          committerHandle,
          annotatedId._bytes,
          message,
          allowOverwrite: allowOverwrite,
        );
        return (
          notesCommit: Oid._(r.notesCommitId),
          notesBlob: Oid._(r.notesBlobId),
        );
      } finally {
        signatureFree(committerHandle);
      }
    } finally {
      signatureFree(authorHandle);
    }
  }

  /// Removes the note attached to [annotatedId].
  ///
  /// [author] and [committer] are recorded on the notes commit that
  /// drops the note. [notesRef] defaults to [defaultNotesRef].
  void removeNote({
    required Oid annotatedId,
    required Signature author,
    required Signature committer,
    String? notesRef,
  }) {
    final a = signatureNew(
      author.name,
      author.email,
      author._record.time,
      author._record.offset,
    );
    try {
      final c = signatureNew(
        committer.name,
        committer.email,
        committer._record.time,
        committer._record.offset,
      );
      try {
        noteRemove(_handle, a, c, annotatedId._bytes, notesRef: notesRef);
      } finally {
        signatureFree(c);
      }
    } finally {
      signatureFree(a);
    }
  }

  /// Invokes [callback] for every note under [notesRef].
  ///
  /// [callback] receives the note's blob id and the id of the
  /// object the note annotates. Returning a non-zero value stops
  /// iteration and is surfaced as the return value. [notesRef]
  /// defaults to [defaultNotesRef].
  int forEachNote(
    int Function(Oid noteBlob, Oid annotatedObject) callback, {
    String? notesRef,
  }) {
    return noteForeach(
      _handle,
      (blob, annotated) => callback(Oid._(blob), Oid._(annotated)),
      notesRef: notesRef,
    );
  }

  /// Lists every note in [notesRef] as `(noteBlob, annotatedObject)`
  /// records.
  ///
  /// [notesRef] defaults to [defaultNotesRef].
  List<({Oid noteBlob, Oid annotatedObject})> notes({String? notesRef}) {
    final iter = noteIteratorNew(_handle, notesRef: notesRef);
    try {
      final result = <({Oid noteBlob, Oid annotatedObject})>[];
      while (true) {
        final entry = noteNext(iter);
        if (entry == null) break;
        result.add((
          noteBlob: Oid._(entry.blobId),
          annotatedObject: Oid._(entry.annotatedId),
        ));
      }
      return result;
    } finally {
      noteIteratorFree(iter);
    }
  }
}
