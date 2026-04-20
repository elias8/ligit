part of 'api.dart';

/// Basic type (loose or packed) of any Git object.
typedef ObjectType = ObjectT;

/// Convenience queries on [ObjectType] values.
extension ObjectTypeExtension on ObjectType {
  /// The Git canonical lowercase type name (`commit`, `tree`, `blob`,
  /// `tag`, etc.) as written in loose object headers.
  String get gitName => objectTypeToString(this);

  /// Whether this type can be stored as a loose object on disk.
  bool get isLoose => objectTypeIsLoose(this);
}

/// A generic Git object: commit, tree, blob, or tag.
///
/// [GitObject] is used when the concrete object type is not known up
/// front (for example after a revspec lookup). Use [type] to identify
/// the kind and [peel] to walk down to a more specific object along
/// Git's object graph.
///
/// Two [GitObject] instances that refer to the same underlying OID
/// compare equal, regardless of which lookup produced them.
/// Instances own native memory and must be [dispose]d.
///
/// ```dart
/// final obj = GitObject.lookup(repo, someOid);
/// print(obj.type);                        // ObjectType.commit (say)
/// final tree = obj.peel(ObjectType.tree); // commit -> root tree
/// obj.dispose();
/// tree.dispose();
/// ```
@immutable
final class GitObject {
  static final _finalizer = Finalizer<int>(objectFree);

  final int _handle;

  /// The OID this object is stored under.
  final Oid id;

  /// Looks up the object at [id] in [repo].
  ///
  /// Pass a concrete [type] to reject mismatched objects; the default
  /// [ObjectType.any] lets libgit2 infer the type from the object
  /// database.
  ///
  /// Throws [NotFoundException] when no object with that id exists.
  /// Throws [Libgit2Exception] when the stored type does not match.
  factory GitObject.lookup(
    Repository repo,
    Oid id, {
    ObjectType type = ObjectType.any,
  }) {
    final handle = objectLookup(repo._handle, id.bytes, type);
    return GitObject._(handle, Oid._(objectId(handle)));
  }

  /// Looks up the object at [path] inside the tree rooted at
  /// [treeish].
  ///
  /// [treeish] can be any object that peels to a tree: a tree, a
  /// commit, or a tag that resolves to either.
  ///
  /// Throws [NotFoundException] when [path] does not exist.
  factory GitObject.lookupByPath(
    GitObject treeish,
    String path,
    ObjectType type,
  ) {
    final handle = objectLookupByPath(treeish._handle, path, type);
    return GitObject._(handle, Oid._(objectId(handle)));
  }

  /// Looks up an object by the first [prefixLength] hex characters of
  /// [oid].
  ///
  /// [prefixLength] must be at least [Oid.minPrefixLength] and long
  /// enough to resolve a single object.
  ///
  /// Throws [AmbiguousException] when multiple objects share the
  /// prefix. Throws [NotFoundException] when no object matches.
  factory GitObject.lookupPrefix(
    Repository repo,
    Oid oid,
    int prefixLength, {
    ObjectType type = ObjectType.any,
  }) {
    final handle = objectLookupPrefix(
      repo._handle,
      oid.bytes,
      prefixLength,
      type,
    );
    return GitObject._(handle, Oid._(objectId(handle)));
  }

  GitObject._(this._handle, this.id) {
    _finalizer.attach(this, _handle, detach: this);
  }

  @override
  int get hashCode => id.hashCode;

  /// The shortest unambiguous hex OID prefix for this object.
  ///
  /// Starts at `core.abbrev` (default 7) and grows as needed until
  /// the prefix uniquely identifies the object within its repository.
  String get shortId => objectShortId(_handle);

  /// The type of this object (commit, tree, blob, or tag).
  ObjectType get type => objectType(_handle);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is GitObject && id == other.id);

  /// Releases the native object handle.
  void dispose() {
    _finalizer.detach(this);
    objectFree(_handle);
  }

  /// Returns an in-memory copy of this object.
  ///
  /// The copy owns native memory independent of the original and
  /// must be [dispose]d on its own.
  GitObject dup() {
    final handle = objectDup(_handle);
    return GitObject._(handle, id);
  }

  /// Peels this object repeatedly until an object of [targetType] is
  /// reached.
  ///
  /// Pass [ObjectType.any] to peel a tag down to the first non-tag
  /// object it points at, or a commit down to its root tree. Any
  /// other starting type with [ObjectType.any] is rejected.
  ///
  /// Throws [InvalidValueException] when the object graph does not
  /// allow the requested peel (for example peeling a blob to a tree).
  GitObject peel(ObjectType targetType) {
    final handle = objectPeel(_handle, targetType);
    return GitObject._(handle, Oid._(objectId(handle)));
  }

  @override
  String toString() => 'GitObject($type, ${id.shortSha()})';

  /// Whether [content] is a valid serialization of an object of
  /// [type].
  ///
  /// Blobs always validate. Trees, commits, and tags are parsed and
  /// structurally checked.
  static bool isValidRawContent(Uint8List content, ObjectType type) =>
      objectRawContentIsValid(content, type);

  /// Parses [name] into an [ObjectType]. Returns [ObjectType.invalid]
  /// when [name] does not match any known type.
  static ObjectType typeFromString(String name) => objectStringToType(name);
}
