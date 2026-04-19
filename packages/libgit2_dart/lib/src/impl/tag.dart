part of 'api.dart';

/// An annotated tag: a named, immutable reference to another Git
/// object with its own metadata (tagger, message, target type).
///
/// [Tag] is OID-keyed: two [Tag]s for the same id compare equal.
/// Instances own native memory and must be [dispose]d. Lightweight
/// tags (plain references under `refs/tags/`) are not stored as tag
/// objects; only annotated tags are.
///
/// ```dart
/// final tag = Tag.lookup(repo, tagOid);
/// print(tag.name);
/// print(tag.message);
/// final target = tag.target();
/// target.dispose();
/// tag.dispose();
/// ```
@immutable
final class Tag {
  static final _finalizer = Finalizer<int>(tagFree);

  final int _handle;

  /// The OID this tag is stored under.
  final Oid id;

  /// Looks up the tag at [id] in [repo].
  ///
  /// Throws [NotFoundException] when no tag with that id exists.
  factory Tag.lookup(Repository repo, Oid id) {
    final handle = tagLookup(repo._handle, id.bytes);
    return Tag._(handle, Oid._(tagId(handle)));
  }

  /// Looks up the tag identified by the first [prefixLength] hex
  /// characters of [oid].
  ///
  /// Throws [AmbiguousException] when multiple tags share the
  /// prefix. Throws [NotFoundException] when no tag matches.
  factory Tag.lookupPrefix(Repository repo, Oid oid, int prefixLength) {
    final handle = tagLookupPrefix(repo._handle, oid.bytes, prefixLength);
    return Tag._(handle, Oid._(tagId(handle)));
  }

  Tag._(this._handle, this.id) {
    _finalizer.attach(this, _handle, detach: this);
  }

  @override
  int get hashCode => id.hashCode;

  /// The full tag message, or `null` when unspecified.
  String? get message => tagMessage(_handle);

  /// The tag's own name, for example `v1.0.0`.
  String get name => tagName(_handle);

  /// The signature of the person who created this tag, or `null`
  /// when the tag has no tagger record.
  Signature? get tagger {
    final r = tagTagger(_handle);
    if (r == null) return null;
    return _signatureFromRecord(r);
  }

  /// The OID of the object this tag points at.
  Oid get targetId => Oid._(tagTargetId(_handle));

  /// The type of object this tag points at.
  ObjectType get targetType => tagTargetType(_handle);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Tag && id == other.id);

  /// Releases the native tag handle.
  void dispose() {
    _finalizer.detach(this);
    tagFree(_handle);
  }

  /// Returns an in-memory copy of this tag.
  ///
  /// The copy owns native memory independent of the original and
  /// must be [dispose]d on its own.
  Tag dup() {
    final handle = tagDup(_handle);
    return Tag._(handle, id);
  }

  /// Peels the tag chain down to the first non-tag object.
  ///
  /// When [target] already returns a non-tag object, [peel] returns
  /// a fresh copy of that same object.
  GitObject peel() {
    final handle = tagPeel(_handle);
    return GitObject._(handle, Oid._(objectId(handle)));
  }

  /// Loads the object this tag points at.
  GitObject target() {
    final handle = tagTarget(_handle);
    return GitObject._(handle, Oid._(objectId(handle)));
  }

  @override
  String toString() => 'Tag($name, ${id.shortSha()})';

  /// Whether [name] is a valid annotated tag name (passes the same
  /// reference-name checks used at creation time).
  static bool nameIsValid(String name) => tagNameIsValid(name);
}

/// Tag operations on [Repository].
extension RepositoryTag on Repository {
  /// Creates a lightweight tag: a plain `refs/tags/[name]` reference
  /// pointing directly at [target] with no annotated object.
  ///
  /// Returns the OID of [target] (not a new tag object).
  Oid createLightweightTag({
    required String name,
    required GitObject target,
    bool force = false,
  }) {
    final bytes = tagCreateLightweight(
      repoHandle: _handle,
      tagName: name,
      targetHandle: target._handle,
      force: force,
    );
    return Oid._(bytes);
  }

  /// Writes a new annotated tag to the object database and creates
  /// the matching `refs/tags/[name]` reference.
  ///
  /// [name] must avoid the characters `~`, `^`, `:`, `\`, `?`, `[`,
  /// `*`, and the sequences `..` and `@{`. Set [force] to overwrite
  /// an existing tag with the same name.
  ///
  /// Throws [ExistsException] when a tag with [name] already exists
  /// and [force] is false. Throws [InvalidValueException] when
  /// [name] is malformed.
  Oid createTag({
    required String name,
    required GitObject target,
    required Signature tagger,
    required String message,
    bool force = false,
  }) {
    final bytes = tagCreate(
      repoHandle: _handle,
      tagName: name,
      targetHandle: target._handle,
      tagger: tagger._record,
      message: message,
      force: force,
    );
    return Oid._(bytes);
  }

  /// Writes a new annotated tag object to the object database without
  /// creating a reference under `refs/tags/`.
  Oid createTagAnnotation({
    required String name,
    required GitObject target,
    required Signature tagger,
    required String message,
  }) {
    final bytes = tagAnnotationCreate(
      repoHandle: _handle,
      tagName: name,
      targetHandle: target._handle,
      tagger: tagger._record,
      message: message,
    );
    return Oid._(bytes);
  }

  /// Parses raw tag object bytes and writes them to the object
  /// database, also creating `refs/tags/<tag>` from the parsed tag
  /// name.
  ///
  /// Set [force] to overwrite an existing tag with the same name.
  Oid createTagFromBuffer(String buffer, {bool force = false}) {
    final bytes = tagCreateFromBuffer(_handle, buffer, force: force);
    return Oid._(bytes);
  }

  /// Deletes the `refs/tags/[name]` reference.
  ///
  /// Throws [Libgit2Exception] when [name] does not resolve to a
  /// tag.
  void deleteTag(String name) => tagDelete(_handle, name);

  /// Invokes [callback] for every tag reference.
  ///
  /// [callback] receives the full ref name and the id the tag
  /// resolves to. Returning a non-zero value stops iteration and is
  /// surfaced as this call's return.
  int forEachTag(int Function(String name, Oid targetId) callback) {
    return tagForeach(_handle, (name, id) => callback(name, Oid._(id)));
  }

  /// Returns tag names under `refs/tags/`.
  ///
  /// When [match] is non-null, only tags matching the fnmatch
  /// pattern are returned; otherwise every tag is listed.
  List<String> tagNames({String? match}) {
    return match == null ? tagList(_handle) : tagListMatch(_handle, match);
  }
}
