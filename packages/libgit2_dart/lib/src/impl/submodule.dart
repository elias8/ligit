part of 'api.dart';

Set<SubmoduleStatus> _decodeStatus(int bits) => {
  for (final v in SubmoduleStatus.values)
    if ((bits & v.value) != 0) v,
};

bool _listEq<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _setEq<T>(Set<T> a, Set<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  return a.containsAll(b);
}

/// A nested repository tracked inside a superproject.
///
/// Submodule metadata is assembled from `.gitmodules`, `.git/config`,
/// the index, and the HEAD tree. Load an existing submodule with
/// [Submodule.lookup] or stage a new one with [Submodule.addSetup].
/// Must be [dispose]d when done.
///
/// ```dart
/// final sm = Submodule.lookup(repo, 'vendor/lib');
/// try {
///   print('${sm.name} -> ${sm.url}');
///   if (sm.headId != sm.workdirId) {
///     sm.update();
///   }
/// } finally {
///   sm.dispose();
/// }
/// ```
@immutable
final class Submodule {
  static final _finalizer = Finalizer<int>(submoduleFree);

  final int _handle;

  /// Sets up a new submodule at [path] pointing at [url].
  ///
  /// Performs `git submodule add` up to (but excluding) the clone
  /// and checkout of the submodule contents. Call [addFinalize]
  /// after the clone completes to stage `.gitmodules` and the
  /// submodule gitlink. [useGitlink] places the submodule's `.git`
  /// directory under the superproject's `.git/modules/` tree and
  /// writes a gitlink at the submodule path.
  factory Submodule.addSetup({
    required Repository repo,
    required String url,
    required String path,
    bool useGitlink = true,
  }) => Submodule._(
    submoduleAddSetup(repo._handle, url, path, useGitlink: useGitlink),
  );

  /// Creates an in-memory copy of [source].
  factory Submodule.copy(Submodule source) =>
      Submodule._(submoduleDup(source._handle));

  /// Looks up the submodule registered under [name] in [repo].
  ///
  /// [name] is usually the same as the submodule's path, though
  /// the two are not required to match.
  ///
  /// Throws [NotFoundException] when no submodule is tracked under
  /// [name]. Throws [ExistsException] when a sub-repository exists
  /// at the path but is not registered as a submodule.
  factory Submodule.lookup(Repository repo, String name) =>
      Submodule._(submoduleLookup(repo._handle, name));

  Submodule._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Branch configured for this submodule, or null when none is
  /// set.
  String? get branch => submoduleBranch(_handle);

  /// Fetch-recurse rule currently in effect.
  SubmoduleRecurse get fetchRecurse =>
      SubmoduleRecurse.fromValue(submoduleFetchRecurseSubmodules(_handle));

  /// [Oid] of this submodule in the superproject's HEAD tree, or
  /// null when the submodule is not in HEAD.
  Oid? get headId {
    final bytes = submoduleHeadId(_handle);
    return bytes == null ? null : Oid._(bytes);
  }

  /// Ignore rule currently in effect.
  SubmoduleIgnore get ignore =>
      SubmoduleIgnore.fromValue(submoduleIgnore(_handle));

  /// [Oid] of this submodule in the superproject's index, or null
  /// when the submodule is not in the index.
  Oid? get indexId {
    final bytes = submoduleIndexId(_handle);
    return bytes == null ? null : Oid._(bytes);
  }

  /// Flags indicating which sources (HEAD tree, index,
  /// configuration, working directory) record information about
  /// this submodule.
  Set<SubmoduleStatus> get location =>
      _decodeStatus(submoduleLocation(_handle));

  /// Name of this submodule.
  String get name => submoduleName(_handle);

  /// Superproject that contains this submodule.
  ///
  /// The returned [Repository] shares its handle with the open
  /// superproject and must not be [Repository.dispose]d
  /// independently.
  Repository get owner {
    final h = submoduleOwner(_handle);
    return Repository._(h, repositoryPath(h));
  }

  /// Path at which this submodule lives inside the superproject.
  ///
  /// Almost always the same as [name], but the two are not required
  /// to match.
  String get path => submodulePath(_handle);

  /// Update rule currently in effect.
  SubmoduleUpdate get updateStrategy =>
      SubmoduleUpdate.fromValue(submoduleUpdateStrategy(_handle));

  /// URL configured for this submodule.
  String get url => submoduleUrl(_handle);

  /// [Oid] of the checked-out submodule working directory, or null
  /// when no checkout exists.
  Oid? get workdirId {
    final bytes = submoduleWdId(_handle);
    return bytes == null ? null : Oid._(bytes);
  }

  /// Finalizes a newly-added submodule.
  ///
  /// Call after [Submodule.addSetup] and the subsequent clone to
  /// stage `.gitmodules` and the submodule gitlink in the
  /// superproject index.
  void addFinalize() => submoduleAddFinalize(_handle);

  /// Adds the current submodule HEAD commit to the superproject
  /// index.
  void addToIndex({bool writeIndex = true}) =>
      submoduleAddToIndex(_handle, writeIndex: writeIndex);

  /// Clones the submodule set up by [Submodule.addSetup] but not
  /// yet cloned.
  ///
  /// Callers must [Repository.dispose] the returned sub-repository.
  Repository cloneSubRepo({SubmoduleUpdateOptions? options}) {
    final h = submoduleClone(_handle, options: options?._record);
    return Repository._(h, repositoryPath(h));
  }

  /// Releases the submodule.
  void dispose() {
    _finalizer.detach(this);
    submoduleFree(_handle);
  }

  /// Copies this submodule's info into `.git/config`.
  ///
  /// Equivalent to `git submodule init`. Existing entries are
  /// preserved unless [overwrite] is true.
  void init({bool overwrite = false}) =>
      submoduleInit(_handle, overwrite: overwrite);

  /// Opens the submodule's sub-repository.
  ///
  /// Requires the submodule to be checked out in the working
  /// directory. The returned [Repository] is a fresh handle and
  /// must be [Repository.dispose]d independently of the
  /// superproject.
  Repository open() {
    final h = submoduleOpen(_handle);
    return Repository._(h, repositoryPath(h));
  }

  /// Re-reads submodule info from config, index, and HEAD.
  void reload({bool force = false}) => submoduleReload(_handle, force: force);

  /// Initializes the sub-repository in preparation for a clone.
  ///
  /// [useGitlink] places the `.git` directory under the
  /// superproject's `.git/modules/` tree and writes a gitlink at
  /// the submodule path; when false, a full `.git` directory lives
  /// at the submodule path itself. Callers must
  /// [Repository.dispose] the returned repository.
  Repository repoInit({bool useGitlink = true}) {
    final handle = submoduleRepoInit(_handle, useGitlink: useGitlink);
    return Repository._(handle, repositoryPath(handle));
  }

  /// Copies the submodule's URL into the checked-out submodule
  /// config.
  void sync() => submoduleSync(_handle);

  /// Clones a missing submodule and checks it out to the commit
  /// recorded in the superproject index.
  ///
  /// Pass `init: true` to register the submodule in `.git/config`
  /// first, matching `git submodule update --init`. [options] tunes
  /// the fetch and checkout; the defaults perform a fresh fetch and
  /// a safe checkout.
  void update({bool init = false, SubmoduleUpdateOptions? options}) {
    submoduleUpdate(_handle, init: init, options: options?._record);
  }
}

/// Options passed to [Submodule.update] and [Submodule.cloneSubRepo].
///
/// Bundles checkout tuning and, optionally, fetch tuning, together
/// with [allowFetch] — the flag that permits fetching missing
/// target commits from the submodule's default remote.
@immutable
final class SubmoduleUpdateOptions {
  /// Checkout strategy applied to the submodule working tree.
  ///
  /// An empty set disables checkout, equivalent to
  /// [CheckoutStrategy.none].
  final Set<CheckoutStrategy> checkoutStrategy;

  /// Restricts checkout to these paths. Empty means every path.
  final List<String> checkoutPaths;

  /// Fetch tuning for the fetch that may run against the
  /// submodule's default remote. Null keeps the defaults.
  final FetchOptions? fetch;

  /// Whether the update may fetch from the submodule's default
  /// remote when the target commit is absent. Defaults to true.
  final bool allowFetch;

  const SubmoduleUpdateOptions({
    this.checkoutStrategy = const {CheckoutStrategy.safe},
    this.checkoutPaths = const [],
    this.fetch,
    this.allowFetch = true,
  });

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(checkoutStrategy),
    Object.hashAll(checkoutPaths),
    fetch,
    allowFetch,
  );

  SubmoduleUpdateOptionsRecord get _record {
    var bits = 0;
    for (final s in checkoutStrategy) {
      bits |= s.value;
    }
    return (
      checkoutStrategy: bits,
      checkoutPaths: checkoutPaths,
      fetch: fetch?._record,
      allowFetch: allowFetch,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubmoduleUpdateOptions &&
          _setEq(checkoutStrategy, other.checkoutStrategy) &&
          _listEq(checkoutPaths, other.checkoutPaths) &&
          fetch == other.fetch &&
          allowFetch == other.allowFetch);
}

/// Submodule operations on [Repository].
extension RepositorySubmodule on Repository {
  /// Resolves [url] relative to this repository into an absolute
  /// URL.
  String resolveSubmoduleUrl(String url) => submoduleResolveUrl(_handle, url);

  /// Persists [branch] as the configured branch for the submodule
  /// named [name].
  void setSubmoduleBranch(String name, String branch) =>
      submoduleSetBranch(_handle, name, branch);

  /// Persists the fetch-recurse rule for the submodule named
  /// [name].
  void setSubmoduleFetchRecurse(String name, SubmoduleRecurse rule) =>
      submoduleSetFetchRecurseSubmodules(_handle, name, rule.value);

  /// Persists the ignore rule for the submodule named [name].
  void setSubmoduleIgnore(String name, SubmoduleIgnore rule) =>
      submoduleSetIgnore(_handle, name, rule.value);

  /// Persists the update rule for the submodule named [name].
  void setSubmoduleUpdate(String name, SubmoduleUpdate rule) =>
      submoduleSetUpdate(_handle, name, rule.value);

  /// Persists [url] as the configured URL for the submodule named
  /// [name].
  void setSubmoduleUrl(String name, String url) =>
      submoduleSetUrl(_handle, name, url);

  /// Computes the [SubmoduleStatus] flags for the submodule named
  /// [name].
  ///
  /// [ignore] overrides the submodule's configured ignore rule for
  /// this computation.
  Set<SubmoduleStatus> statusOfSubmodule(
    String name, {
    SubmoduleIgnore ignore = SubmoduleIgnore.none,
  }) => _decodeStatus(submoduleStatus(_handle, name, ignore.value));

  /// Names of every submodule tracked by this repository.
  List<String> submoduleNames() => submoduleForeach(_handle);
}
