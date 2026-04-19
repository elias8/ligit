part of 'api.dart';

Signature _signatureFromRecord(
  ({String name, String email, int time, int offset}) r,
) {
  return Signature._(
    name: r.name,
    email: r.email,
    when: DateTime.fromMillisecondsSinceEpoch(r.time * 1000, isUtc: true),
    offset: r.offset,
  );
}

/// A commit: a snapshot of the repository tree with author and
/// committer metadata, a message, and zero or more parents.
///
/// [Commit] is OID-keyed: two [Commit]s for the same id compare equal
/// regardless of which lookup produced them. Instances own native
/// memory and must be [dispose]d.
///
/// ```dart
/// final commit = Commit.lookup(repo, headOid);
/// print(commit.summary);
/// print(commit.author);
/// final tree = commit.tree();
/// tree.dispose();
/// commit.dispose();
/// ```
@immutable
final class Commit {
  static final _finalizer = Finalizer<int>(commitFree);

  final int _handle;

  /// The OID this commit is stored under.
  final Oid id;

  /// Looks up the commit at [id] in [repo].
  ///
  /// If [id] names an annotated tag, libgit2 peels it back to the
  /// referenced commit automatically.
  ///
  /// Throws [NotFoundException] when no commit (or peelable tag)
  /// with that id exists.
  factory Commit.lookup(Repository repo, Oid id) {
    final handle = commitLookup(repo._handle, id.bytes);
    return Commit._(handle, Oid._(commitId(handle)));
  }

  /// Looks up the commit identified by the first [prefixLength] hex
  /// characters of [oid].
  ///
  /// Throws [AmbiguousException] when multiple objects share the
  /// prefix. Throws [NotFoundException] when no commit matches.
  factory Commit.lookupPrefix(Repository repo, Oid oid, int prefixLength) {
    final handle = commitLookupPrefix(repo._handle, oid.bytes, prefixLength);
    return Commit._(handle, Oid._(commitId(handle)));
  }

  Commit._(this._handle, this.id) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// The author signature.
  Signature get author {
    final r = commitAuthor(_handle);
    return _signatureFromRecord(r);
  }

  /// Everything in [message] after the summary paragraph, with
  /// leading and trailing whitespace trimmed. Returns `null` when
  /// the message has no body.
  String? get body => commitBody(_handle);

  /// The committer signature.
  Signature get committer {
    final r = commitCommitter(_handle);
    return _signatureFromRecord(r);
  }

  @override
  int get hashCode => id.hashCode;

  /// The full message of the commit, with any leading newlines
  /// trimmed.
  String get message => commitMessage(_handle);

  /// The encoding header from the commit, or `null` when the header
  /// is absent and UTF-8 is assumed.
  String? get messageEncoding => commitMessageEncoding(_handle);

  /// The message exactly as stored in the commit object, including
  /// any leading whitespace.
  String get messageRaw => commitMessageRaw(_handle);

  /// The number of parent commits.
  int get parentCount => commitParentCount(_handle);

  /// The raw header text of the commit object (everything before the
  /// blank line that precedes the message).
  String get rawHeader => commitRawHeader(_handle);

  /// The summary line: the first paragraph of [message] with
  /// whitespace squashed. Returns `null` when the message is empty.
  String? get summary => commitSummary(_handle);

  /// The committer time in UTC, second precision.
  DateTime get time => DateTime.fromMillisecondsSinceEpoch(
    commitTime(_handle) * 1000,
    isUtc: true,
  );

  /// The committer's recorded timezone offset in minutes east of
  /// UTC.
  int get timeOffset => commitTimeOffset(_handle);

  /// The OID of the tree this commit snapshots.
  Oid get treeId => Oid._(commitTreeId(_handle));

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Commit && id == other.id);

  /// Releases the native commit handle.
  void dispose() {
    _finalizer.detach(this);
    commitFree(_handle);
  }

  /// Returns an in-memory copy of this commit.
  ///
  /// The copy owns native memory independent of the original and
  /// must be [dispose]d on its own.
  Commit dup() {
    final handle = commitDup(_handle);
    return Commit._(handle, id);
  }

  /// Reads an arbitrary [field] from the commit header, or `null`
  /// when the field is absent.
  ///
  /// Standard fields include `tree`, `parent`, `author`, `committer`,
  /// and `encoding`.
  String? headerField(String field) => commitHeaderField(_handle, field);

  /// Loads the [n]th generation ancestor of this commit following
  /// only first parents. `n = 0` returns a fresh copy of this same
  /// commit.
  ///
  /// Throws [NotFoundException] when the ancestor chain is shorter
  /// than [n] generations.
  Commit nthGenAncestor(int n) {
    final handle = commitNthGenAncestor(_handle, n);
    return Commit._(handle, Oid._(commitId(handle)));
  }

  /// Loads the parent commit at [n] (zero based).
  ///
  /// Throws [RangeError] when [n] is outside `0..parentCount-1`.
  Commit parent(int n) {
    final handle = commitParent(_handle, n);
    return Commit._(handle, Oid._(commitId(handle)));
  }

  /// The OID of the parent at [n] without loading the parent commit.
  ///
  /// Throws [RangeError] when [n] is outside `0..parentCount-1`.
  Oid parentIdAt(int n) => Oid._(commitParentId(_handle, n));

  @override
  String toString() => 'Commit(${id.shortSha()})';

  /// Loads the tree this commit snapshots.
  Tree tree() {
    final handle = commitTree(_handle);
    return Tree._(handle, treeId);
  }

  /// Writes a new commit that replaces [base] with only the non-null
  /// fields changed; the rest are inherited.
  ///
  /// When [updateRef] is non-null, the named reference is updated to
  /// point at the new commit. The amended commit has the same
  /// parents as [base].
  ///
  /// Returns the OID of the amended commit.
  static Oid amend({
    required Commit base,
    String? updateRef,
    Signature? author,
    Signature? committer,
    String? messageEncoding,
    String? message,
    Tree? tree,
  }) {
    final bytes = commitAmend(
      commitHandle: base._handle,
      updateRef: updateRef,
      author: author?._record,
      committer: committer?._record,
      messageEncoding: messageEncoding,
      message: message,
      treeHandle: tree?._handle,
    );
    return Oid._(bytes);
  }

  /// Serializes a proposed commit as textual content suitable for
  /// detached signing.
  ///
  /// The returned string matches what [Commit.create] would persist
  /// given the same inputs. Sign it out-of-band (GPG, SSH, etc.) and
  /// feed the signature back through [Commit.createWithSignature] to
  /// store the final object.
  static String createBuffer({
    required Repository repo,
    required Signature author,
    required Signature committer,
    String? messageEncoding,
    required String message,
    required Tree tree,
    List<Commit> parents = const [],
  }) {
    return commitCreateBuffer(
      repoHandle: repo._handle,
      author: author._record,
      committer: committer._record,
      messageEncoding: messageEncoding,
      message: message,
      treeHandle: tree._handle,
      parentHandles: [for (final p in parents) p._handle],
    );
  }

  /// Writes the commit [content] (typically produced by
  /// [Commit.createBuffer]) together with [signature] into the object
  /// database, returning the resulting OID.
  ///
  /// [signatureField] names the header that carries the signature;
  /// pass `null` to accept libgit2's default (`gpgsig`).
  static Oid createWithSignature({
    required Repository repo,
    required String content,
    required String signature,
    String? signatureField,
  }) {
    final bytes = commitCreateWithSignature(
      repoHandle: repo._handle,
      content: content,
      signature: signature,
      signatureField: signatureField,
    );
    return Oid._(bytes);
  }

  /// Commits the staged changes in [repo], mirroring `git commit -m`.
  ///
  /// Uses libgit2's defaults for empty-commit handling, signatures,
  /// and encoding. For finer control use [Commit.create].
  ///
  /// Throws [Libgit2Exception] when there is nothing staged to commit.
  static Oid createFromStage(Repository repo, String message) {
    return Oid._(commitCreateFromStage(repo._handle, message));
  }

  /// Extracts the signature attached to the commit at [commitId] in
  /// [repo], returning the raw signature and the signed content.
  ///
  /// [field] selects which header holds the signature; `null` uses
  /// libgit2's default (`gpgsig`).
  ///
  /// Throws [NotFoundException] when the commit carries no such
  /// signature.
  static ({String signature, String signedData}) extractSignature(
    Repository repo,
    Oid commitId, {
    String? field,
  }) {
    return commitExtractSignature(repo._handle, commitId._bytes, field: field);
  }

  /// Writes a new commit to the object database.
  ///
  /// When [updateRef] is non-null, the named reference is updated to
  /// point at the new commit. Pass `'HEAD'` to update the current
  /// branch. [parents] lists the commits this one descends from; an
  /// empty list produces a root commit.
  ///
  /// [message] is stored verbatim. Use [Message.prettify] first if
  /// you want whitespace collapsed and comments removed.
  ///
  /// Returns the OID of the written commit. Chain with
  /// [Commit.lookup] to load the resulting [Commit].
  static Oid create({
    required Repository repo,
    String? updateRef,
    required Signature author,
    required Signature committer,
    String? messageEncoding,
    required String message,
    required Tree tree,
    List<Commit> parents = const [],
  }) {
    final bytes = commitCreate(
      repoHandle: repo._handle,
      updateRef: updateRef,
      author: author._record,
      committer: committer._record,
      messageEncoding: messageEncoding,
      message: message,
      treeHandle: tree._handle,
      parentHandles: [for (final p in parents) p._handle],
    );
    return Oid._(bytes);
  }
}
