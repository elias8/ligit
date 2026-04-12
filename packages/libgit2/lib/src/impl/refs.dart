part of 'api.dart';

/// Basic type of any Git reference.
typedef ReferenceType = ReferenceT;

/// A named pointer into the object database such as `HEAD`, a branch,
/// a tag, or a remote-tracking ref.
///
/// A [Reference] is either direct (it resolves to an [Oid]) or
/// symbolic (it resolves to another reference name). Two [Reference]
/// instances in the same repository with the same full name compare
/// equal, regardless of where the handle came from.
///
/// Instances own native memory and must be [dispose]d when no longer
/// needed.
///
/// ```dart
/// final ref = Reference.lookup(repo, 'refs/heads/main');
/// try {
///   print(ref.name);       // refs/heads/main
///   print(ref.target);     // Oid of the tip commit
///   print(ref.shorthand);  // main
/// } finally {
///   ref.dispose();
/// }
/// ```
@immutable
final class Reference {
  static final _finalizer = Finalizer<int>(referenceFree);

  /// No particular normalization.
  static const formatNormal = 0;

  /// Allow one-level refnames (names that do not contain multiple
  /// `/`-separated components, such as `HEAD` or `FETCH_HEAD`).
  static const formatAllowOneLevel = 1;

  /// Interpret the name as a reference pattern for a refspec, allowing
  /// a single `*` in place of one full pathname component (for
  /// example `foo/*/bar` but not `foo/bar*`).
  static const formatRefspecPattern = 2;

  /// Interpret the name as part of a refspec in shorthand form, so
  /// the one-level naming rules are not enforced and `master` is a
  /// valid name.
  static const formatRefspecShorthand = 4;

  final int _handle;

  final String _repoPath;

  /// The full reference name, e.g. `refs/heads/main`.
  final String name;

  /// Creates a new direct reference [name] pointing at [target].
  ///
  /// A direct reference refers directly to a specific object id. The
  /// reference is written to disk immediately.
  ///
  /// [name] must follow one of two patterns: top-level names may
  /// contain only capital letters and underscores and must begin and
  /// end with a letter (e.g. `HEAD`, `ORIG_HEAD`); names prefixed
  /// with `refs/` can be almost anything but must avoid the
  /// characters `~`, `^`, `:`, `\`, `?`, `[`, `*`, and the sequences
  /// `..` and `@{`.
  ///
  /// If [force] is `true`, an existing reference with the same name
  /// is overwritten. [logMessage] is written to the reflog when
  /// [name] is `HEAD`, a branch, or a remote-tracking branch; it is
  /// ignored otherwise.
  ///
  /// Throws [ExistsException] when [name] already exists and [force]
  /// is `false`, or [InvalidValueException] when [name] is malformed.
  factory Reference.create({
    required Repository repo,
    required String name,
    required Oid target,
    bool force = false,
    String? logMessage,
  }) {
    final handle = referenceCreate(
      repoHandle: repo._handle,
      name: name,
      oidBytes: target.bytes,
      force: force,
      logMessage: logMessage,
    );
    return Reference._(handle, repo.path, referenceName(handle));
  }

  /// Looks up a reference by DWIM-ing its short name.
  ///
  /// Applies the git precedence rules to [shorthand] to determine
  /// which reference is meant (the same rules used by `git log main`,
  /// `git log v1.0`, and so on).
  ///
  /// Throws [NotFoundException] when [shorthand] cannot be resolved.
  factory Reference.dwim(Repository repo, String shorthand) {
    final handle = referenceDwim(repo._handle, shorthand);
    return Reference._(handle, repo.path, referenceName(handle));
  }

  /// Looks up a reference by its full [name] in [repo].
  ///
  /// [name] must be a fully qualified reference name such as `HEAD`,
  /// `refs/heads/main`, or `refs/tags/v1.0`, and is validated against
  /// the reference-name grammar described on [Reference.create].
  ///
  /// Throws [NotFoundException] when no reference matches, or
  /// [InvalidValueException] when [name] is malformed.
  factory Reference.lookup(Repository repo, String name) {
    final handle = referenceLookup(repo._handle, name);
    return Reference._(handle, repo.path, referenceName(handle));
  }

  /// Creates a new symbolic reference [name] pointing at the
  /// reference named [target].
  ///
  /// A symbolic reference is a name that refers to another reference
  /// name. If the target moves, the symbolic name moves with it. As a
  /// simple example, `HEAD` might refer to `refs/heads/master` while
  /// on the `master` branch.
  ///
  /// See [Reference.create] for the rules [name] must satisfy and the
  /// meaning of [force] and [logMessage].
  ///
  /// Throws [ExistsException] when [name] already exists and [force]
  /// is `false`, or [InvalidValueException] when [name] is malformed.
  factory Reference.symbolicCreate({
    required Repository repo,
    required String name,
    required String target,
    bool force = false,
    String? logMessage,
  }) {
    final handle = referenceSymbolicCreate(
      repoHandle: repo._handle,
      name: name,
      target: target,
      force: force,
      logMessage: logMessage,
    );
    return Reference._(handle, repo.path, referenceName(handle));
  }

  Reference._(this._handle, this._repoPath, this.name) {
    _finalizer.attach(this, _handle, detach: this);
  }

  Reference._borrowed(this._handle, this._repoPath)
    : name = referenceName(_handle);

  @override
  int get hashCode => Object.hash(_repoPath, name);

  /// Whether a reflog exists for this reference.
  bool get hasReflog => referenceHasLog(_owner, name);

  /// Whether this reference is a local branch, i.e. lives under
  /// `refs/heads/`.
  bool get isBranch => referenceIsBranch(_handle);

  /// Whether this reference points at an object id directly.
  bool get isDirect => type == ReferenceType.direct;

  /// Whether this reference is a note, i.e. lives under `refs/notes/`.
  bool get isNote => referenceIsNote(_handle);

  /// Whether this reference is a remote-tracking branch, i.e. lives
  /// under `refs/remotes/`.
  bool get isRemote => referenceIsRemote(_handle);

  /// Whether this reference points at another reference name.
  bool get isSymbolic => type == ReferenceType.symbolic;

  /// Whether this reference is a tag, i.e. lives under `refs/tags/`.
  bool get isTag => referenceIsTag(_handle);

  /// The short, human-readable form of [name].
  ///
  /// Transforms the reference name into a human-readable version —
  /// for example `main` rather than `refs/heads/main`. Falls back to
  /// the full name when no shorter form is appropriate.
  String get shorthand => referenceShorthand(_handle);

  /// The target reference name for a symbolic reference, or `null`
  /// when this is a direct reference.
  String? get symbolicTarget => referenceSymbolicTarget(_handle);

  /// The target [Oid] for a direct reference, or `null` when this is
  /// symbolic.
  ///
  /// To resolve the target of a symbolic reference, first call
  /// [resolve] (or use [RepositoryReference.resolveReferenceName] to
  /// skip allocating an intermediate [Reference]).
  Oid? get target {
    final bytes = referenceTarget(_handle);
    return bytes == null ? null : Oid._(bytes);
  }

  /// The peeled target [Oid] of this reference.
  ///
  /// Only applies to direct references that point at a tag object:
  /// the result is the object obtained by peeling that tag. Returns
  /// `null` otherwise.
  Oid? get targetPeel {
    final bytes = referenceTargetPeel(_handle);
    return bytes == null ? null : Oid._(bytes);
  }

  /// The type of the reference, either [ReferenceType.direct] or
  /// [ReferenceType.symbolic].
  ReferenceType get type => referenceType(_handle);

  int get _owner => referenceOwner(_handle);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reference &&
          _repoPath == other._repoPath &&
          name == other.name);

  /// Compares this reference with [other].
  ///
  /// Returns `0` when the two refer to the same reference, otherwise
  /// a stable but meaningless ordering.
  int compareTo(Reference other) => referenceCmp(_handle, other._handle);

  /// Deletes this reference from the repository.
  ///
  /// The reference is removed from disk immediately. This instance
  /// must still be [dispose]d.
  void delete() => referenceDelete(_handle);

  /// Releases the native reference handle.
  void dispose() {
    _finalizer.detach(this);
    referenceFree(_handle);
  }

  /// Returns an independent copy of this reference.
  ///
  /// The returned [Reference] is backed by a fresh native handle and
  /// must be [dispose]d independently of this one.
  Reference dup() {
    final handle = referenceDup(_handle);
    return Reference._(handle, _repoPath, name);
  }

  /// Recursively peels this reference until an object of [targetType]
  /// is found.
  ///
  /// Passing [ObjectType.any] peels a tag chain until a non-tag
  /// object is reached. Callers must [GitObject.dispose] the returned
  /// object.
  ///
  /// Throws [AmbiguousException] when the reference cannot be peeled
  /// unambiguously, or [NotFoundException] when no object of
  /// [targetType] can be reached.
  GitObject peel(ObjectType targetType) {
    final handle = referencePeel(_handle, targetType);
    return GitObject._(handle, Oid._(objectId(handle)));
  }

  /// Renames this reference to [newName].
  ///
  /// Works for both direct and symbolic references. If [force] is
  /// `true`, an existing reference with the same name is overwritten.
  /// [newName] is validated against the reference-name grammar (see
  /// [Reference.create]). The reflog is renamed when one exists.
  ///
  /// Returns a fresh [Reference] for the renamed reference; this
  /// instance still refers to the pre-rename state and must still be
  /// [dispose]d.
  ///
  /// Throws [InvalidValueException] when [newName] is malformed, or
  /// [ExistsException] when a reference named [newName] already
  /// exists and [force] is `false`.
  Reference rename(String newName, {bool force = false, String? logMessage}) {
    final handle = referenceRename(
      _handle,
      newName,
      force: force,
      logMessage: logMessage,
    );
    return Reference._(handle, _repoPath, referenceName(handle));
  }

  /// Resolves this symbolic reference to a direct reference.
  ///
  /// Iteratively peels the reference until it resolves to a direct
  /// reference. When this reference is already direct, a copy is
  /// returned. The caller must [dispose] the returned [Reference].
  Reference resolve() {
    final handle = referenceResolve(_handle);
    return Reference._(handle, _repoPath, referenceName(handle));
  }

  /// Rewrites this symbolic reference to point at [target] and
  /// returns a fresh handle to the updated reference.
  ///
  /// This reference must be symbolic. The new reference is written to
  /// disk, overwriting the existing one. [target] is validated
  /// against the reference-name grammar (see [Reference.create]).
  /// [logMessage] is written to the reflog when [name] is `HEAD`, a
  /// branch, or a remote-tracking branch.
  ///
  /// Throws [InvalidValueException] when [target] is malformed.
  Reference setSymbolicTarget(String target, {String? logMessage}) {
    final handle = referenceSymbolicSetTarget(
      _handle,
      target,
      logMessage: logMessage,
    );
    return Reference._(handle, _repoPath, referenceName(handle));
  }

  /// Rewrites this direct reference to point at [target] and returns
  /// a fresh handle to the updated reference.
  ///
  /// This reference must be direct; use [setSymbolicTarget] for
  /// symbolic references. The new reference is written to disk,
  /// overwriting the existing one. [logMessage] is written to the
  /// reflog when [name] is `HEAD`, a branch, or a remote-tracking
  /// branch.
  Reference setTarget(Oid target, {String? logMessage}) {
    final handle = referenceSetTarget(
      _handle,
      target.bytes,
      logMessage: logMessage,
    );
    return Reference._(handle, _repoPath, referenceName(handle));
  }

  @override
  String toString() => 'Reference($name)';

  /// Whether [name] is a well-formed reference name.
  ///
  /// See [Reference.create] for the full grammar.
  static bool nameIsValid(String name) => referenceNameIsValid(name);

  /// Normalizes a reference [name] and returns the result.
  ///
  /// Removes any leading `/` characters and collapses runs of
  /// adjacent slashes between name components into a single slash.
  /// The resulting name is checked against the reference-name grammar
  /// (see [Reference.create]).
  ///
  /// [flags] is a bitmask of [Reference.formatNormal],
  /// [Reference.formatAllowOneLevel], [Reference.formatRefspecPattern]
  /// and [Reference.formatRefspecShorthand].
  ///
  /// Throws [InvalidValueException] when [name] cannot be normalized.
  static String normalizeName(String name, {int flags = formatNormal}) {
    return referenceNormalizeName(name, flags);
  }
}

/// Reference operations on [Repository].
extension RepositoryReference on Repository {
  /// Removes the reference named [name] from the repository.
  ///
  /// Deletes the reference without loading its old value. Faster than
  /// [Reference.lookup] followed by [Reference.delete] when the
  /// caller does not need a handle.
  void deleteReference(String name) => referenceRemove(_handle, name);

  /// Ensures a reflog exists for the reference named [name].
  ///
  /// Guarantees that subsequent updates to [name] will append to its
  /// reflog.
  void ensureReflog(String name) => referenceEnsureLog(_handle, name);

  /// Invokes [callback] for every reference in the repository.
  ///
  /// The [Reference] handed to [callback] is borrowed from the
  /// underlying iteration and is released automatically when the
  /// callback returns; callers must not [Reference.dispose] it.
  /// Returning a non-zero value from [callback] stops iteration and
  /// is surfaced as this method's return value.
  int forEachReference(int Function(Reference ref) callback) {
    return referenceForeach(_handle, (handle) {
      return callback(Reference._borrowed(handle, path));
    });
  }

  /// Invokes [callback] for every reference name in the repository.
  ///
  /// When [glob] is non-null, only names matching the fnmatch-style
  /// pattern are visited. A `*` matches any sequence of letters, `?`
  /// matches any single letter, and square brackets define character
  /// ranges (e.g. `[0-9]`). Returning a non-zero value from
  /// [callback] stops iteration and is surfaced as this method's
  /// return value.
  int forEachReferenceName(int Function(String name) callback, {String? glob}) {
    if (glob == null) {
      return referenceForeachName(_handle, callback);
    }
    return referenceForeachGlob(_handle, glob, callback);
  }

  /// Whether a reflog exists for the reference named [name].
  bool hasReflog(String name) => referenceHasLog(_handle, name);

  /// Returns the full names of every reference in the repository.
  List<String> referenceNames() => referenceList(_handle);

  /// Returns a fresh [Reference] for every reference in the
  /// repository.
  ///
  /// When [glob] is non-null, only references whose name matches the
  /// fnmatch-style pattern are returned (see [forEachReferenceName]
  /// for the glob rules). Callers must [Reference.dispose] every
  /// returned instance.
  List<Reference> references({String? glob}) {
    final iterHandle = glob == null
        ? referenceIteratorNew(_handle)
        : referenceIteratorGlobNew(_handle, glob);
    try {
      final result = <Reference>[];
      while (true) {
        final refHandle = referenceNext(iterHandle);
        if (refHandle == 0) break;
        result.add(Reference._(refHandle, path, referenceName(refHandle)));
      }
      return result;
    } finally {
      referenceIteratorFree(iterHandle);
    }
  }

  /// Resolves [name] directly to its target [Oid] without allocating
  /// an intermediate [Reference].
  ///
  /// Throws [NotFoundException] when [name] does not exist, or
  /// [InvalidValueException] when [name] is malformed.
  Oid resolveReferenceName(String name) {
    return Oid._(referenceNameToId(_handle, name));
  }
}
