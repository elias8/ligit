part of 'api.dart';

/// Git's staging area: the contents of the next commit.
///
/// An [Index] can be loaded from a [Repository], opened as a
/// standalone file via [Index.open], or created empty in memory with
/// [Index.inMemory]. Mutations happen in memory only until [write]
/// persists them to disk.
///
/// Owns a native resource; call [dispose] when finished. Equality is
/// identity-based because the underlying state is mutable.
///
/// ```dart
/// final index = Index.fromRepository(repo);
/// try {
///   index.addByPath('README.md');
///   index.write();
///   final treeId = index.writeTree();
/// } finally {
///   index.dispose();
/// }
/// ```
@immutable
final class Index {
  /// Bitmask covering the name-length portion of [IndexEntry.flags].
  static const entryNameMask = indexEntryNameMask;

  /// Bitmask covering the stage portion of [IndexEntry.flags].
  static const entryStageMask = indexEntryStageMask;

  /// Bit-shift used to extract the stage value from
  /// [IndexEntry.flags].
  static const entryStageShift = indexEntryStageShift;

  /// On-disk flag marking an entry that uses extended fields.
  static const entryExtended = indexEntryExtended;

  /// On-disk flag marking an entry as valid (assume-unchanged).
  static const entryValid = indexEntryValid;

  /// In-memory-only flag marking an intent-to-add placeholder.
  static const entryIntentToAdd = indexEntryIntentToAdd;

  /// In-memory-only flag marking an entry skipped from the worktree.
  static const entrySkipWorktree = indexEntrySkipWorktree;

  /// In-memory-only bit recording that the entry is up to date with
  /// the working directory.
  static const entryUpToDate = indexEntryUpToDate;

  static final _finalizer = Finalizer<int>(indexFree);

  final int _handle;

  /// Creates an empty in-memory index detached from any repository.
  ///
  /// The resulting index cannot be read from or written to the
  /// filesystem; it is suitable only for in-memory operations. Any
  /// method that requires an object database or working directory (for example
  /// [addByPath]) will fail.
  factory Index.inMemory() => Index._(indexNew());

  /// Opens the bare index file at [indexPath] without attaching it
  /// to any repository.
  ///
  /// Since there is no backing object database or working directory, methods
  /// that rely on one (for example [addByPath]) will fail until the
  /// index is associated with a repository.
  factory Index.open(String indexPath) => Index._(indexOpen(indexPath));

  /// Returns the index of [repo].
  ///
  /// Each call yields a fresh [Index] instance sharing the same
  /// underlying index file; the repository's active index is not
  /// replaced.
  factory Index.fromRepository(Repository repo) =>
      Index._(indexFromRepository(repo._handle));

  Index._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Full path to the index file on disk, or null for in-memory
  /// indexes.
  String? get path => indexPath(_handle);

  /// Capability flags currently set on this index.
  Set<IndexCapability> get capabilities {
    final bits = indexCaps(_handle);
    return {
      for (final cap in IndexCapability.values)
        if (cap != IndexCapability.fromOwner && (bits & cap.value) != 0) cap,
    };
  }

  /// Sets the index capability flags.
  ///
  /// Passing a set containing [IndexCapability.fromOwner] inherits
  /// capabilities from the owning repository's `core.ignorecase`,
  /// `core.filemode`, and `core.symlinks` configuration.
  set capabilities(Set<IndexCapability> caps) {
    if (caps.contains(IndexCapability.fromOwner)) {
      indexSetCaps(_handle, IndexCapability.fromOwner.value);
      return;
    }
    var bits = 0;
    for (final c in caps) {
      bits |= c.value;
    }
    indexSetCaps(_handle, bits);
  }

  /// On-disk index format version.
  ///
  /// Valid values are 2, 3, or 4. A version-3 index may be written
  /// as version 2 if the extension data is unnecessary.
  int get version => indexVersion(_handle);

  /// Sets the on-disk index format version.
  ///
  /// Valid values are 2, 3, or 4. If 2 is given, [write] may write
  /// a version-3 index instead when extended flags are required.
  set version(int value) => indexSetVersion(_handle, value);

  /// Number of entries currently in the index.
  int get entryCount => indexEntryCount(_handle);

  /// SHA-1 checksum of the index file.
  ///
  /// Returns the zero [Oid] when the index has never been written
  /// to disk.
  Oid get checksum => Oid._(indexChecksum(_handle));

  /// Whether the index contains entries representing file conflicts.
  bool get hasConflicts => indexHasConflicts(_handle);

  /// Returns the [Repository] this index is associated with, or null
  /// for standalone indexes.
  ///
  /// The returned [Repository] shares ownership with the index and
  /// must not be [Repository.dispose]d independently.
  Repository? owner() {
    final h = indexOwner(_handle);
    if (h == 0) return null;
    return Repository._(h, repositoryPath(h));
  }

  /// Updates the index contents by reading from disk.
  ///
  /// When [force] is true, in-memory changes are discarded and the
  /// on-disk data is always reloaded. When false, the reload only
  /// happens if the file has changed since the last load; purely
  /// in-memory data is left untouched.
  void read({bool force = false}) => indexRead(_handle, force: force);

  /// Writes the index back to disk using an atomic file lock.
  void write() => indexWrite(_handle);

  /// Replaces the current index contents with the entries of [tree].
  void readTree(Tree tree) => indexReadTree(_handle, tree._handle);

  /// Writes the index as a tree into the owning repository's object
  /// database.
  ///
  /// Recursively materializes every subtree and returns the [Oid]
  /// of the resulting root tree — suitable for creating a commit.
  /// The index must be attached to a repository and must not be
  /// unmerged.
  ///
  /// Throws [ConflictException] when the index contains unmerged
  /// entries.
  Oid writeTree() => Oid._(indexWriteTree(_handle));

  /// Writes the index as a tree into [repo].
  ///
  /// Behaves like [writeTree] but lets the caller choose the
  /// destination repository.
  Oid writeTreeTo(Repository repo) =>
      Oid._(indexWriteTreeTo(_handle, repo._handle));

  /// Clears the contents of this index in memory.
  ///
  /// Changes must be persisted with [write] to take effect on disk.
  void clear() => indexClear(_handle);

  /// Returns the entry at [position], or null when out of range.
  IndexEntry? getByIndex(int position) {
    final record = indexGetByIndex(_handle, position);
    if (record == null) return null;
    return IndexEntry._(record);
  }

  /// Returns the entry at [path] with the given [stage], or null
  /// when no such entry exists.
  ///
  /// Pass [IndexStage.any] to match regardless of stage.
  IndexEntry? getByPath(String path, {IndexStage stage = IndexStage.normal}) {
    final record = indexGetByPath(_handle, path, stage.value);
    if (record == null) return null;
    return IndexEntry._(record);
  }

  /// Adds or updates [entry] in the index.
  ///
  /// If a previous entry exists with the same path and stage, it is
  /// replaced; otherwise [entry] is inserted.
  void add(IndexEntry entry) => indexAdd(_handle, entry._record);

  /// Adds or updates an index entry from the file at [path].
  ///
  /// [path] is relative to the repository's working folder and must
  /// be readable. Gitignore rules are bypassed; evaluate them via
  /// the status APIs beforehand if needed. If the file is currently
  /// the result of a merge conflict, the conflict data is moved to
  /// the resolve-undo (REUC) section.
  ///
  /// Fails on bare indexes.
  void addByPath(String path) => indexAddByPath(_handle, path);

  /// Adds or updates an index entry from an in-memory [buffer].
  ///
  /// Creates a blob in the repository that owns this index and adds
  /// an entry at [entry]'s path pointing at it. If a previous entry
  /// exists at the same path it is replaced. Gitignore rules are
  /// bypassed; any existing conflict at the path is moved to the
  /// resolve-undo (REUC) section.
  void addFromBuffer(IndexEntry entry, Uint8List buffer) =>
      indexAddFromBuffer(_handle, entry._record, buffer);

  /// Adds or updates every index entry matching [pathSpecs].
  ///
  /// [pathSpecs] is a list of file names or shell glob patterns
  /// matched against the working directory; glob expansion can be
  /// disabled with [IndexAddOption.disablePathspecMatch]. Ignored
  /// files are skipped unless [IndexAddOption.force] is set; pass
  /// [IndexAddOption.checkPathspec] to emulate `git add -A`'s
  /// error when a pathspec exactly matches an ignored file.
  ///
  /// [onMatch] is invoked immediately before every match is written:
  /// return `0` to add/update the entry, a positive value to skip
  /// it, or a negative value to abort the scan. A Dart exception
  /// thrown from [onMatch] also aborts. Fails on bare indexes.
  void addAll(
    List<String> pathSpecs, {
    Set<IndexAddOption> flags = const {},
    int Function(String path, String matchedPathspec)? onMatch,
  }) {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    indexAddAll(_handle, pathSpecs, flags: bits, onMatch: onMatch);
  }

  /// Removes the entry at [path] and [stage] from the index.
  void remove(String path, {IndexStage stage = IndexStage.normal}) =>
      indexRemove(_handle, path, stage.value);

  /// Removes every entry under [directory] at [stage].
  void removeDirectory(
    String directory, {
    IndexStage stage = IndexStage.normal,
  }) => indexRemoveDirectory(_handle, directory, stage.value);

  /// Removes the index entry corresponding to the working-directory
  /// file [path].
  ///
  /// If the file is currently the result of a merge conflict, the
  /// conflict data is moved to the resolve-undo (REUC) section.
  void removeByPath(String path) => indexRemoveByPath(_handle, path);

  /// Removes every index entry matching [pathSpecs].
  ///
  /// [onMatch] is invoked immediately before each match is removed:
  /// return `0` to remove it, a positive value to skip it, or a
  /// negative value to abort the scan. A Dart exception thrown from
  /// [onMatch] also aborts.
  void removeAll(
    List<String> pathSpecs, {
    int Function(String path, String matchedPathspec)? onMatch,
  }) => indexRemoveAll(_handle, pathSpecs, onMatch: onMatch);

  /// Updates every index entry matching [pathSpecs] to match the
  /// working directory.
  ///
  /// Entries whose file no longer exists on disk are removed;
  /// changed files are re-hashed and their blob is added to the
  /// object database as needed. Fails on bare indexes. [onMatch]
  /// behaves as in [removeAll].
  void updateAll(
    List<String> pathSpecs, {
    int Function(String path, String matchedPathspec)? onMatch,
  }) => indexUpdateAll(_handle, pathSpecs, onMatch: onMatch);

  /// Finds the first position of any entry pointing at [path], or
  /// null when no entry matches.
  int? find(String path) => indexFind(_handle, path);

  /// Finds the first position of any entry matching [prefix], or
  /// null when no entry matches.
  ///
  /// Suffix [prefix] with `/` to find the first entry inside a
  /// directory.
  int? findPrefix(String prefix) => indexFindPrefix(_handle, prefix);

  /// Records a merge conflict for the three sides of a file.
  ///
  /// Any side may be null to indicate the file was absent in that
  /// tree — for example, pass a null [ancestor] when a file was
  /// added on both branches. Any existing staged entries at the
  /// conflict's path are removed.
  void addConflict({
    IndexEntry? ancestor,
    IndexEntry? ours,
    IndexEntry? theirs,
  }) {
    indexConflictAdd(
      _handle,
      ancestor: ancestor?._record,
      ours: ours?._record,
      theirs: theirs?._record,
    );
  }

  /// Returns the three conflict sides at [path], or null when
  /// [path] is not in conflict.
  IndexConflict? getConflict(String path) {
    final record = indexConflictGet(_handle, path);
    if (record == null) return null;
    return IndexConflict._(record);
  }

  /// Removes the conflict entries at [path].
  void removeConflict(String path) => indexConflictRemove(_handle, path);

  /// Removes every conflict (entries with stage > 0) from the index.
  void cleanupConflicts() => indexConflictCleanup(_handle);

  /// Lazily yields every entry in the index in path order.
  ///
  /// Iteration is backed by a snapshot taken at call time;
  /// mutations to the index during iteration do not affect what the
  /// iterator sees.
  Iterable<IndexEntry> entries() sync* {
    final iter = indexIteratorNew(_handle);
    try {
      while (true) {
        final record = indexIteratorNext(iter);
        if (record == null) return;
        yield IndexEntry._(record);
      }
    } finally {
      indexIteratorFree(iter);
    }
  }

  /// Lazily yields every conflict recorded in the index.
  ///
  /// The index must not be modified while the iterator is live.
  Iterable<IndexConflict> conflicts() sync* {
    final iter = indexConflictIteratorNew(_handle);
    try {
      while (true) {
        final record = indexConflictIteratorNext(iter);
        if (record == null) return;
        yield IndexConflict._(record);
      }
    } finally {
      indexConflictIteratorFree(iter);
    }
  }

  /// Releases the resources held by this index.
  void dispose() {
    _finalizer.detach(this);
    indexFree(_handle);
  }
}

/// A single file entry in an [Index].
///
/// A pure value type: fields are copied out of the native index at
/// read time, so later mutations to the index do not affect an
/// existing [IndexEntry] instance. Construct new entries with the
/// default constructor when inserting via [Index.add] or
/// [Index.addFromBuffer]. Field semantics follow core Git's
/// `Documentation/technical/index-format.txt`; [ctimeSeconds],
/// [mtimeSeconds], and [fileSize] are truncated to 32 bits — enough
/// for change detection but not an authoritative source.
@immutable
final class IndexEntry {
  /// Creation time in seconds since the Unix epoch.
  final int ctimeSeconds;

  /// Nanosecond component of the creation time.
  final int ctimeNanoseconds;

  /// Modification time in seconds since the Unix epoch.
  final int mtimeSeconds;

  /// Nanosecond component of the modification time.
  final int mtimeNanoseconds;

  /// Device identifier on which the file resides.
  final int dev;

  /// File serial number on the backing filesystem.
  final int ino;

  /// POSIX file mode bits recorded for the entry.
  final int mode;

  /// Owning user id.
  final int uid;

  /// Owning group id.
  final int gid;

  /// File size in bytes, truncated to 32 bits.
  final int fileSize;

  /// [Oid] of the blob stored at this entry.
  final Oid id;

  /// On-disk flag bits: name length, stage, and the extended and
  /// valid markers. Decode with [Index.entryNameMask],
  /// [Index.entryStageMask], [Index.entryExtended], and
  /// [Index.entryValid].
  final int flags;

  /// Extended flag bits, including the in-memory-only intent-to-add,
  /// skip-worktree, and up-to-date markers.
  final int flagsExtended;

  /// Path relative to the repository root.
  final String path;

  /// Creates an index entry value.
  ///
  /// Timestamp, device, inode, uid, and gid fields default to zero,
  /// which is appropriate for in-memory construction. [id] defaults
  /// to the zero [Oid] and [mode] defaults to the regular-file mode
  /// `0o100644`.
  factory IndexEntry({
    required String path,
    int mode = 0x81a4,
    int fileSize = 0,
    Oid? id,
    int flags = 0,
    int flagsExtended = 0,
    int ctimeSeconds = 0,
    int ctimeNanoseconds = 0,
    int mtimeSeconds = 0,
    int mtimeNanoseconds = 0,
    int dev = 0,
    int ino = 0,
    int uid = 0,
    int gid = 0,
  }) => IndexEntry._from(
    path: path,
    mode: mode,
    fileSize: fileSize,
    id: id ?? Oid.zero(),
    flags: flags,
    flagsExtended: flagsExtended,
    ctimeSeconds: ctimeSeconds,
    ctimeNanoseconds: ctimeNanoseconds,
    mtimeSeconds: mtimeSeconds,
    mtimeNanoseconds: mtimeNanoseconds,
    dev: dev,
    ino: ino,
    uid: uid,
    gid: gid,
  );

  const IndexEntry._from({
    required this.path,
    required this.mode,
    required this.fileSize,
    required this.id,
    required this.flags,
    required this.flagsExtended,
    required this.ctimeSeconds,
    required this.ctimeNanoseconds,
    required this.mtimeSeconds,
    required this.mtimeNanoseconds,
    required this.dev,
    required this.ino,
    required this.uid,
    required this.gid,
  });

  factory IndexEntry._(IndexEntryRecord r) => IndexEntry._from(
    path: r.path,
    mode: r.mode,
    fileSize: r.fileSize,
    id: Oid._(r.id),
    flags: r.flags,
    flagsExtended: r.flagsExtended,
    ctimeSeconds: r.ctimeSeconds,
    ctimeNanoseconds: r.ctimeNanoseconds,
    mtimeSeconds: r.mtimeSeconds,
    mtimeNanoseconds: r.mtimeNanoseconds,
    dev: r.dev,
    ino: r.ino,
    uid: r.uid,
    gid: r.gid,
  );

  /// Stage value for this entry: `0` for a normal entry, or 1–3 for
  /// the ancestor, ours, and theirs sides of a conflict.
  int get stage => indexEntryStage(flags);

  /// Whether this entry represents a side of a conflict (stage > 0).
  bool get isConflict => indexEntryIsConflict(flags);

  IndexEntryRecord get _record => (
    ctimeSeconds: ctimeSeconds,
    ctimeNanoseconds: ctimeNanoseconds,
    mtimeSeconds: mtimeSeconds,
    mtimeNanoseconds: mtimeNanoseconds,
    dev: dev,
    ino: ino,
    mode: mode,
    uid: uid,
    gid: gid,
    fileSize: fileSize,
    id: id.bytes,
    flags: flags,
    flagsExtended: flagsExtended,
    path: path,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IndexEntry &&
          path == other.path &&
          mode == other.mode &&
          fileSize == other.fileSize &&
          id == other.id &&
          flags == other.flags &&
          flagsExtended == other.flagsExtended &&
          ctimeSeconds == other.ctimeSeconds &&
          ctimeNanoseconds == other.ctimeNanoseconds &&
          mtimeSeconds == other.mtimeSeconds &&
          mtimeNanoseconds == other.mtimeNanoseconds &&
          dev == other.dev &&
          ino == other.ino &&
          uid == other.uid &&
          gid == other.gid);

  @override
  int get hashCode => Object.hash(
    path,
    mode,
    fileSize,
    id,
    flags,
    flagsExtended,
    ctimeSeconds,
    ctimeNanoseconds,
    mtimeSeconds,
    mtimeNanoseconds,
    dev,
    ino,
    uid,
    gid,
  );

  @override
  String toString() => 'IndexEntry($path, stage=$stage, id=$id)';
}

/// The three sides of a single file conflict recorded in an [Index].
///
/// Any side may be null when the file was absent in that tree — for
/// example, a file added only on one branch.
@immutable
final class IndexConflict {
  /// Entry from the merge ancestor, or null when the file was not
  /// present there.
  final IndexEntry? ancestor;

  /// Entry from our side of the merge, or null when the file was
  /// deleted on our side.
  final IndexEntry? ours;

  /// Entry from their side of the merge, or null when the file was
  /// deleted on their side.
  final IndexEntry? theirs;

  const IndexConflict._raw({this.ancestor, this.ours, this.theirs});

  factory IndexConflict._(IndexConflictRecord r) => IndexConflict._raw(
    ancestor: r.ancestor == null ? null : IndexEntry._(r.ancestor!),
    ours: r.ours == null ? null : IndexEntry._(r.ours!),
    theirs: r.theirs == null ? null : IndexEntry._(r.theirs!),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IndexConflict &&
          ancestor == other.ancestor &&
          ours == other.ours &&
          theirs == other.theirs);

  @override
  int get hashCode => Object.hash(ancestor, ours, theirs);
}
