part of 'api.dart';

/// Possible states for a gitattribute.
typedef AttrKind = AttrValue;

/// A resolved gitattribute.
///
/// An attribute may be set (`attr`), unset (`-attr`), unspecified
/// (not mentioned, or `!attr`), or assigned a string value
/// (`attr=value`). [kind] distinguishes those four cases;
/// [stringValue] carries the value only when [kind] is
/// [AttrKind.string].
@immutable
final class AttrResult {
  /// Classification of this attribute lookup.
  final AttrKind kind;

  /// The string value, or `null` when [kind] is not
  /// [AttrKind.string].
  final String? stringValue;

  const AttrResult._({required this.kind, required this.stringValue});

  /// Whether the attribute was explicitly set (`attr`).
  bool get isSet => kind == AttrKind.true$;

  /// Whether the attribute was explicitly unset (`-attr`).
  bool get isUnset => kind == AttrKind.false$;

  /// Whether no rule applied to the attribute.
  bool get isUnspecified => kind == AttrKind.unspecified;

  /// Whether the attribute holds a string value (`attr=value`).
  bool get hasValue => kind == AttrKind.string;

  @override
  int get hashCode => Object.hash(kind, stringValue);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttrResult &&
          kind == other.kind &&
          stringValue == other.stringValue);

  @override
  String toString() {
    return switch (kind) {
      AttrKind.true$ => 'AttrResult(set)',
      AttrKind.false$ => 'AttrResult(unset)',
      AttrKind.unspecified => 'AttrResult(unspecified)',
      AttrKind.string => 'AttrResult($stringValue)',
    };
  }
}

/// Controls where gitattributes are looked up.
///
/// Selects between the working directory, the index, and the commit
/// at HEAD (or a specific commit), and optionally skips the
/// system-wide `gitattributes` file. Starts from one of the three
/// base modes and stacks extra modifiers with [noSystem],
/// [includeHead] and [includeCommit].
@immutable
final class AttrLookup {
  /// Bitwise combination of the underlying libgit2 flag constants.
  final int flags;

  const AttrLookup._(this.flags);

  /// Reads attributes from the working directory first, then the
  /// index. This is the default.
  static const workdirThenIndex = AttrLookup._(attrCheckFileThenIndex);

  /// Reads attributes from the index first, then the working
  /// directory.
  static const indexThenWorkdir = AttrLookup._(attrCheckIndexThenFile);

  /// Reads attributes only from the index, skipping the working
  /// directory.
  static const indexOnly = AttrLookup._(attrCheckIndexOnly);

  /// Returns a new lookup that does not load the system-wide
  /// `gitattributes` file.
  AttrLookup noSystem() => AttrLookup._(flags | attrCheckNoSystem);

  /// Returns a new lookup that also loads `.gitattributes` from the
  /// root of HEAD.
  AttrLookup includeHead() => AttrLookup._(flags | attrCheckIncludeHead);

  /// Returns a new lookup that loads `.gitattributes` from a
  /// specific commit.
  ///
  /// Pass the commit's [Oid] as `commitId` to
  /// [RepositoryAttr.attribute], [RepositoryAttr.attributes] or
  /// [RepositoryAttr.forEachAttribute].
  AttrLookup includeCommit() => AttrLookup._(flags | attrCheckIncludeCommit);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AttrLookup && flags == other.flags);

  @override
  int get hashCode => flags.hashCode;
}

/// Gitattributes lookup on [Repository].
extension RepositoryAttr on Repository {
  /// Looks up the value of one gitattribute for [path].
  ///
  /// [path] is interpreted relative to the repository root. The file
  /// does not have to exist; a non-existent path is treated as a
  /// plain file. Pass [commitId] together with
  /// [AttrLookup.includeCommit] to consult a specific commit's
  /// `.gitattributes`.
  AttrResult attribute(
    String path,
    String name, {
    AttrLookup lookup = AttrLookup.workdirThenIndex,
    Oid? commitId,
  }) {
    final raw = (lookup.flags & attrCheckIncludeCommit) != 0 || commitId != null
        ? attrGetExt(
            _handle,
            path,
            name,
            flags: lookup.flags,
            commitId: commitId?._bytes,
          )
        : attrGet(_handle, path, name, flags: lookup.flags);
    return AttrResult._(kind: raw.kind, stringValue: raw.value);
  }

  /// Looks up several gitattributes for [path] in one pass.
  ///
  /// Returns a map keyed by the requested [names]. More efficient
  /// than calling [attribute] repeatedly. Pass [commitId] to resolve
  /// against a specific commit's `.gitattributes`.
  Map<String, AttrResult> attributes(
    String path,
    List<String> names, {
    AttrLookup lookup = AttrLookup.workdirThenIndex,
    Oid? commitId,
  }) {
    final raws =
        (lookup.flags & attrCheckIncludeCommit) != 0 || commitId != null
        ? attrGetManyExt(
            _handle,
            path,
            names,
            flags: lookup.flags,
            commitId: commitId?._bytes,
          )
        : attrGetMany(_handle, path, names, flags: lookup.flags);
    return {
      for (var i = 0; i < names.length; i++)
        names[i]: AttrResult._(kind: raws[i].kind, stringValue: raws[i].value),
    };
  }

  /// Invokes [callback] for every gitattribute applying to [path].
  ///
  /// The callback receives the attribute name and its string value
  /// (`null` when unspecified or unset). Returning a non-zero value
  /// stops iteration and is surfaced as this call's return. [path]
  /// does not have to exist; a non-existent path is treated as a
  /// plain file.
  int forEachAttribute(
    String path,
    int Function(String name, String? value) callback, {
    AttrLookup lookup = AttrLookup.workdirThenIndex,
    Oid? commitId,
  }) {
    return (lookup.flags & attrCheckIncludeCommit) != 0 || commitId != null
        ? attrForeachExt(
            _handle,
            path,
            callback,
            flags: lookup.flags,
            commitId: commitId?._bytes,
          )
        : attrForeach(_handle, path, callback, flags: lookup.flags);
  }

  /// Flushes the in-memory gitattributes cache.
  ///
  /// Call this if you have reason to believe that attributes files
  /// on disk no longer match the cached contents; they will be
  /// reloaded the next time an attribute is read.
  void flushAttrCache() => attrCacheFlush(_handle);

  /// Defines a new attribute macro.
  ///
  /// Macros are automatically loaded from the top-level
  /// `.gitattributes` file of the repository (plus the built-in
  /// `binary` macro). For example, the built-in `binary` macro can
  /// be reproduced with `addAttrMacro('binary', '-diff -crlf')`.
  void addAttrMacro(String name, String values) {
    attrAddMacro(_handle, name, values);
  }
}
