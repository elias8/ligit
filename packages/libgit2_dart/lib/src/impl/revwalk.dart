part of 'api.dart';

/// Flags describing the sort order of a [Revwalk] traversal.
typedef SortMode = Sort;

/// A commit-graph walker.
///
/// Allocate one with [Revwalk.new], mark roots with [push], [pushHead],
/// [pushGlob], [pushRef] or [pushRange], mark uninteresting commits
/// with [hide], [hideHead], [hideGlob] or [hideRef], and then drain
/// the walker with [next] or [toIterable].
///
/// The walker is stateful and relatively expensive to allocate;
/// reuse it across walks with [reset] when possible.
///
/// ```dart
/// final walk = Revwalk(repo)
///   ..sorting({SortMode.topological})
///   ..pushHead();
/// try {
///   for (final id in walk.toIterable()) {
///     print(id);
///   }
/// } finally {
///   walk.dispose();
/// }
/// ```
@immutable
final class Revwalk {
  static final _finalizer = Finalizer<int>(revwalkFree);

  final int _handle;

  /// Allocates a new walker over [repo].
  ///
  /// The returned walker starts empty; push at least one root before
  /// calling [next].
  factory Revwalk(Repository repo) => Revwalk._(revwalkNew(repo._handle));

  Revwalk._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Releases the native walker handle.
  void dispose() {
    _finalizer.detach(this);
    revwalkFree(_handle);
  }

  /// Marks the commit [id] and its ancestors as uninteresting so
  /// they are skipped during traversal.
  void hide(Oid id) => revwalkHide(_handle, id._bytes);

  /// Hides every reference whose name matches [pattern], plus each
  /// match's ancestors.
  ///
  /// See [pushGlob] for the glob rules.
  void hideGlob(String pattern) => revwalkHideGlob(_handle, pattern);

  /// Hides the commit `HEAD` currently points at.
  void hideHead() => revwalkHideHead(_handle);

  /// Hides the commit the reference named [refname] points at.
  void hideRef(String refname) => revwalkHideRef(_handle, refname);

  /// Pops the next commit id, or `null` when the walk is over.
  ///
  /// When iteration ends the walker is automatically reset.
  Oid? next() {
    final bytes = revwalkNext(_handle);
    return bytes == null ? null : Oid._(bytes);
  }

  /// Marks the commit [id] as a root from which to start walking.
  void push(Oid id) => revwalkPush(_handle, id._bytes);

  /// Pushes every reference whose name matches [pattern].
  ///
  /// A leading `refs/` is implied when missing, as is a trailing
  /// `/*` when [pattern] contains none of `?`, `*`, or `[`.
  void pushGlob(String pattern) => revwalkPushGlob(_handle, pattern);

  /// Pushes the commit `HEAD` currently points at.
  void pushHead() => revwalkPushHead(_handle);

  /// Parses an `A..B` style [range], pushing `B` and hiding `A`.
  void pushRange(String range) => revwalkPushRange(_handle, range);

  /// Pushes the commit the reference named [refname] points at.
  void pushRef(String refname) => revwalkPushRef(_handle, refname);

  /// Clears every pushed and hidden commit, returning the walker to
  /// its freshly-allocated state.
  void reset() => revwalkReset(_handle);

  /// Simplifies traversal by following only each commit's first
  /// parent.
  void simplifyFirstParent() => revwalkSimplifyFirstParent(_handle);

  /// Sets the sort order the walker uses for traversal.
  ///
  /// [modes] is a set of [SortMode] flags combined together.
  /// Changing the sort order resets the walker.
  void sorting(Set<SortMode> modes) {
    var bits = 0;
    for (final m in modes) {
      bits |= m.value;
    }
    revwalkSorting(_handle, bits);
  }

  /// Installs a hide [callback] that decides, per commit, whether
  /// the walker should skip that commit and its ancestors.
  ///
  /// Returning a non-zero value from [callback] hides the commit.
  /// Pass `null` to remove any previously installed callback.
  ///
  /// Returns a disposer that releases the native callback; invoke
  /// it after the walk finishes (but before [dispose]). `null` is
  /// returned when [callback] is `null`.
  void Function()? addHideCallback(int Function(Oid commitId)? callback) {
    if (callback == null) return revwalkAddHideCb(_handle, null);
    return revwalkAddHideCb(_handle, (bytes) => callback(Oid._(bytes)));
  }

  /// Lazily yields the remaining commit ids until the walk is over.
  ///
  /// The returned iterable is single-shot: iterating it drains the
  /// walker. Re-push roots to walk again.
  Iterable<Oid> toIterable() sync* {
    while (true) {
      final id = next();
      if (id == null) return;
      yield id;
    }
  }
}
