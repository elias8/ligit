part of 'api.dart';

/// Valid modes for index and tree entries.
typedef FileMode = Filemode;

/// Traversal order for [Tree.walk].
enum TreeWalkOrder {
  /// Visit each node before its children.
  pre(treeWalkPre),

  /// Visit each node after its children.
  post(treeWalkPost);

  final int value;
  const TreeWalkOrder(this.value);
}

/// A single operation applied via [Tree.createUpdated].
@immutable
final class TreeUpdate {
  /// Upsert the entry at [path] with [oid] and [fileMode].
  const TreeUpdate.upsert({
    required this.oid,
    required this.fileMode,
    required this.path,
  }) : action = 0;

  /// Remove the entry at [path].
  TreeUpdate.remove(this.path)
    : action = 1,
      oid = _zeroOid,
      fileMode = Filemode.unreadable;

  /// Upsert (0) or remove (1).
  final int action;

  /// Target OID for an upsert.
  final Oid oid;

  /// File mode for an upsert.
  final Filemode fileMode;

  /// Path relative to the tree root.
  final String path;

  static final _zeroOid = Oid._(Uint8List(20));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TreeUpdate &&
          action == other.action &&
          oid == other.oid &&
          fileMode == other.fileMode &&
          path == other.path);

  @override
  int get hashCode => Object.hash(action, oid, fileMode, path);
}

/// A directory listing in the object database: an ordered set of
/// named entries that each point at another object (blob, tree, or
/// commit for submodules).
///
/// [Tree] exposes lookups by name, index, id, and path. Instances are
/// OID-keyed: two [Tree]s for the same id compare equal regardless of
/// origin.
///
/// Instances own native memory and must be [dispose]d.
///
/// ```dart
/// final tree = Tree.lookup(repo, treeOid);
/// print(tree.entryCount);
/// final readme = tree.entryByName('README.md');
/// if (readme != null) {
///   print(readme.id);
///   readme.dispose();
/// }
/// tree.dispose();
/// ```
@immutable
final class Tree {
  static final _finalizer = Finalizer<int>(treeFree);

  final int _handle;

  /// The OID this tree is stored under.
  final Oid id;

  /// Looks up the tree at [id] in [repo].
  ///
  /// Throws [NotFoundException] when no tree with that id exists.
  factory Tree.lookup(Repository repo, Oid id) {
    final handle = treeLookup(repo._handle, id.bytes);
    return Tree._(handle, Oid._(treeId(handle)));
  }

  /// Looks up the tree identified by the first [prefixLength] hex
  /// characters of [oid].
  ///
  /// Throws [AmbiguousException] when multiple trees share the
  /// prefix. Throws [NotFoundException] when no tree matches.
  factory Tree.lookupPrefix(Repository repo, Oid oid, int prefixLength) {
    final handle = treeLookupPrefix(repo._handle, oid.bytes, prefixLength);
    return Tree._(handle, Oid._(treeId(handle)));
  }

  Tree._(this._handle, this.id) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Number of direct entries in this tree.
  ///
  /// Subtree contents are not counted.
  int get entryCount => treeEntryCount(_handle);

  /// Returns the direct entry with filename [name], or `null` when
  /// no such entry exists.
  ///
  /// The returned [TreeEntry] owns native memory independent of this
  /// tree and must be [TreeEntry.dispose]d.
  TreeEntry? entryByName(String name) {
    final borrowed = treeEntryByName(_handle, name);
    if (borrowed == 0) return null;
    return TreeEntry._fromBorrowed(borrowed);
  }

  /// Returns the entry at [index] (zero based), or `null` when
  /// [index] is out of range.
  TreeEntry? entryByIndex(int index) {
    final borrowed = treeEntryByIndex(_handle, index);
    if (borrowed == 0) return null;
    return TreeEntry._fromBorrowed(borrowed);
  }

  /// Returns the first direct entry whose target OID is [id], or
  /// `null` when no entry matches.
  ///
  /// Scans every entry, so this is linear in [entryCount].
  TreeEntry? entryById(Oid id) {
    final borrowed = treeEntryById(_handle, id.bytes);
    if (borrowed == 0) return null;
    return TreeEntry._fromBorrowed(borrowed);
  }

  /// Returns the entry at [path] relative to this tree, following
  /// nested subtrees as needed, or `null` when [path] does not
  /// resolve.
  ///
  /// The returned entry owns native memory independent of this tree
  /// and must be [TreeEntry.dispose]d.
  TreeEntry? entryByPath(String path) {
    final owned = treeEntryByPath(_handle, path);
    if (owned == 0) return null;
    return TreeEntry._fromOwned(owned);
  }

  /// Loads the object this [entry] points at using [repo] as the
  /// lookup source.
  ///
  /// Equivalent to [GitObject.lookup] with the entry's id and type,
  /// routed through libgit2's entry helper.
  GitObject objectAt(TreeEntry entry, Repository repo) {
    final handle = treeEntryToObject(repo._handle, entry._handle);
    return GitObject._(handle, Oid._(objectId(handle)));
  }

  /// Returns an in-memory copy of this tree.
  ///
  /// The copy owns native memory independent of the original and
  /// must be [dispose]d on its own.
  Tree dup() {
    final handle = treeDup(_handle);
    return Tree._(handle, id);
  }

  /// Walks every entry in this tree, invoking [callback] with the
  /// entry's relative root path and the [TreeEntry] itself.
  ///
  /// Returning a negative value from [callback] aborts the walk;
  /// returning a positive value skips the current subtree.
  int walk(
    int Function(String root, TreeEntry entry) callback, {
    TreeWalkOrder order = TreeWalkOrder.pre,
  }) {
    return treeWalk(_handle, order.value, (root, entryHandle) {
      return callback(root, TreeEntry._fromBorrowed(entryHandle));
    });
  }

  /// Returns the OID of the new tree produced by applying [updates]
  /// to this baseline.
  static Oid createUpdated(
    Repository repo,
    Tree baseline,
    List<TreeUpdate> updates,
  ) {
    final records = [
      for (final u in updates)
        (
          action: u.action,
          oid: u.oid._bytes,
          filemode: u.fileMode.value,
          path: u.path,
        ),
    ];
    return Oid._(treeCreateUpdated(repo._handle, baseline._handle, records));
  }

  /// Releases the native tree handle.
  void dispose() {
    _finalizer.detach(this);
    treeFree(_handle);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Tree && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Tree(${id.shortSha()})';
}

/// Incremental builder for a new tree.
///
/// Create one with [TreeBuilder.new] (optionally seeded from a
/// source tree), add or remove entries through [insert] and
/// [remove], then persist the result with [write] to obtain the
/// resulting tree's [Oid].
@immutable
final class TreeBuilder {
  static final _finalizer = Finalizer<int>(treebuilderFree);

  final int _handle;

  /// Creates a new treebuilder for [repo], optionally seeded with
  /// the entries of [source].
  factory TreeBuilder(Repository repo, {Tree? source}) => TreeBuilder._(
    treebuilderNew(repo._handle, sourceHandle: source?._handle ?? 0),
  );

  TreeBuilder._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Number of entries currently staged on the builder.
  int get length => treebuilderEntryCount(_handle);

  /// Removes every entry.
  void clear() => treebuilderClear(_handle);

  /// Inserts or updates the entry with [filename], [oid], and
  /// [fileMode].
  void insert(String filename, Oid oid, FileMode fileMode) =>
      treebuilderInsert(_handle, filename, oid._bytes, fileMode.value);

  /// Removes the entry registered under [filename].
  void remove(String filename) => treebuilderRemove(_handle, filename);

  /// Returns the staged entry at [filename], or `null` when no entry
  /// is registered under that name.
  ///
  /// The returned [TreeEntry] is independently owned; disposing it
  /// does not affect the builder.
  TreeEntry? get(String filename) {
    final borrowed = treebuilderGet(_handle, filename);
    if (borrowed == 0) return null;
    return TreeEntry._fromBorrowed(borrowed);
  }

  /// Selectively drops entries; [filter] returns a non-zero value to
  /// remove the entry it received.
  void filter(int Function(TreeEntry entry) filter) {
    treebuilderFilter(
      _handle,
      (entryHandle) => filter(TreeEntry._fromBorrowed(entryHandle)),
    );
  }

  /// Writes the builder contents as a tree object and returns its
  /// OID.
  Oid write() => Oid._(treebuilderWrite(_handle));

  /// Releases the native builder handle.
  void dispose() {
    _finalizer.detach(this);
    treebuilderFree(_handle);
  }
}

/// A single named entry inside a [Tree].
///
/// Fields ([name], [id], [type], [fileMode], [fileModeRaw]) are
/// populated at construction and equality is structural over them.
///
/// Every [TreeEntry] owns native memory independently of its parent
/// tree and must be [dispose]d.
@immutable
final class TreeEntry {
  static final _finalizer = Finalizer<int>(treeEntryFree);

  final int _handle;

  /// Filename of this entry within its parent tree.
  final String name;

  /// OID of the object this entry points at.
  final Oid id;

  /// Type of the referenced object.
  final ObjectType type;

  /// Normalized UNIX file mode (e.g. [FileMode.blob],
  /// [FileMode.tree], [FileMode.blobExecutable]).
  final FileMode fileMode;

  /// Raw unnormalized UNIX file mode bits as libgit2 read them from
  /// the tree. Useful for recreating bit-exact tree objects.
  final int fileModeRaw;

  TreeEntry._(
    this._handle,
    this.name,
    this.id,
    this.type,
    this.fileMode,
    this.fileModeRaw,
  ) {
    _finalizer.attach(this, _handle, detach: this);
  }

  factory TreeEntry._fromBorrowed(int borrowedHandle) {
    final owned = treeEntryDup(borrowedHandle);
    return TreeEntry._fromOwned(owned);
  }

  factory TreeEntry._fromOwned(int ownedHandle) {
    return TreeEntry._(
      ownedHandle,
      treeEntryName(ownedHandle),
      Oid._(treeEntryId(ownedHandle)),
      treeEntryType(ownedHandle),
      treeEntryFileMode(ownedHandle),
      treeEntryFileModeRaw(ownedHandle),
    );
  }

  /// Compares this entry to [other] using libgit2's tree ordering.
  ///
  /// Returns a negative value when this sorts before [other], zero
  /// when they are equal, and a positive value when this sorts
  /// after.
  int compareTo(TreeEntry other) => treeEntryCmp(_handle, other._handle);

  /// Releases the native entry handle.
  void dispose() {
    _finalizer.detach(this);
    treeEntryFree(_handle);
  }

  @override
  bool operator ==(Object other) {
    return other is TreeEntry &&
        name == other.name &&
        id == other.id &&
        type == other.type &&
        fileModeRaw == other.fileModeRaw;
  }

  @override
  int get hashCode => Object.hash(name, id, type, fileModeRaw);

  @override
  String toString() => 'TreeEntry($name, $type, ${id.shortSha()})';
}
