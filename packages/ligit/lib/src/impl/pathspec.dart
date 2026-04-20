part of 'api.dart';

/// The result of matching a [Pathspec] against a working directory,
/// index, tree, or diff.
///
/// Depending on how the list was produced, entries are either
/// matched filenames (read with [entry]) or diff deltas (read with
/// [diffEntry]). When [PathspecFlag.findFailures] is passed, the
/// original pathspec strings that matched nothing are available via
/// [failedEntry].
///
/// Must be [dispose]d when done.
@immutable
final class PathspecMatchList {
  static final _finalizer = Finalizer<int>(pathspecMatchListFree);

  final int _handle;

  PathspecMatchList._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Number of matched entries.
  int get length => pathspecMatchListEntryCount(_handle);

  /// Number of pathspec strings in the original input that had no
  /// matches.
  ///
  /// Always `0` unless the list was produced with
  /// [PathspecFlag.findFailures].
  int get failedLength => pathspecMatchListFailedEntryCount(_handle);

  /// Returns the matching filename at [index], or `null` when this
  /// match list was produced by [Pathspec.matchDiff].
  String? entry(int index) => pathspecMatchListEntry(_handle, index);

  /// Returns the original pathspec pattern at [index] that matched
  /// nothing, or `null` when [index] is out of range.
  String? failedEntry(int index) =>
      pathspecMatchListFailedEntry(_handle, index);

  /// Returns the diff delta at [index], or `null` when this match
  /// list was not produced by [Pathspec.matchDiff].
  DiffDelta? diffEntry(int index) {
    final raw = pathspecMatchListDiffEntry(_handle, index);
    return raw == null ? null : DiffDelta._(raw);
  }

  /// Releases the native match-list handle.
  void dispose() {
    _finalizer.detach(this);
    pathspecMatchListFree(_handle);
  }
}

/// A compiled pathspec.
///
/// A [Pathspec] accepts multiple patterns and can be matched against
/// a single path ([matchesPath]), the working directory of a
/// repository ([matchWorkdir]), the entries of an index
/// ([matchIndex]), the files in a tree ([matchTree]), or the deltas
/// of a diff ([matchDiff]).
///
/// Must be [dispose]d when done.
///
/// ```dart
/// final spec = Pathspec(['*.dart', 'lib/**']);
/// try {
///   if (spec.matchesPath('lib/foo.dart')) {
///     final matches = spec.matchWorkdir(repo);
///     for (var i = 0; i < matches.length; i++) {
///       print(matches.entry(i));
///     }
///     matches.dispose();
///   }
/// } finally {
///   spec.dispose();
/// }
/// ```
@immutable
final class Pathspec {
  static final _finalizer = Finalizer<int>(pathspecFree);

  final int _handle;

  /// Compiles [patterns] into a reusable pathspec.
  factory Pathspec(List<String> patterns) => Pathspec._(pathspecNew(patterns));

  Pathspec._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Whether this pathspec matches the literal [path].
  ///
  /// Unlike the other matching methods, this does not fall back on
  /// the platform's native case-sensitivity. Pass
  /// [PathspecFlag.ignoreCase] or [PathspecFlag.useCase] in [flags]
  /// to pick an explicit mode; otherwise the match is case
  /// sensitive.
  bool matchesPath(String path, {Set<PathspecFlag> flags = const {}}) {
    return pathspecMatchesPath(_handle, path, flags: _bits(flags));
  }

  /// Matches this pathspec against the files in the working
  /// directory of [repo].
  ///
  /// Ignored files are skipped unless they are already tracked in
  /// the index.
  ///
  /// Throws [NotFoundException] when no paths matched and [flags]
  /// contains [PathspecFlag.noMatchError]. Throws
  /// [BareRepoException] on a bare repository.
  PathspecMatchList matchWorkdir(
    Repository repo, {
    Set<PathspecFlag> flags = const {},
  }) {
    return PathspecMatchList._(
      pathspecMatchWorkdir(repo._handle, _handle, flags: _bits(flags)),
    );
  }

  /// Matches this pathspec against the files in [tree].
  ///
  /// Throws [NotFoundException] when no paths matched and [flags]
  /// contains [PathspecFlag.noMatchError].
  PathspecMatchList matchTree(Tree tree, {Set<PathspecFlag> flags = const {}}) {
    return PathspecMatchList._(
      pathspecMatchTree(tree._handle, _handle, flags: _bits(flags)),
    );
  }

  /// Matches this pathspec against the entries of [index].
  ///
  /// Case sensitivity follows the case-sensitivity of [index]
  /// itself; [PathspecFlag.useCase] and [PathspecFlag.ignoreCase]
  /// currently have no effect here.
  ///
  /// Throws [NotFoundException] when no paths matched and [flags]
  /// contains [PathspecFlag.noMatchError].
  PathspecMatchList matchIndex(
    Index index, {
    Set<PathspecFlag> flags = const {},
  }) {
    return PathspecMatchList._(
      pathspecMatchIndex(index._handle, _handle, flags: _bits(flags)),
    );
  }

  /// Matches this pathspec against the deltas of [diff].
  ///
  /// Entries of the returned [PathspecMatchList] are diff deltas,
  /// not filenames — read them with [PathspecMatchList.diffEntry].
  ///
  /// Throws [NotFoundException] when no paths matched and [flags]
  /// contains [PathspecFlag.noMatchError].
  PathspecMatchList matchDiff(Diff diff, {Set<PathspecFlag> flags = const {}}) {
    return PathspecMatchList._(
      pathspecMatchDiff(diff._handle, _handle, flags: _bits(flags)),
    );
  }

  /// Releases the native pathspec handle.
  void dispose() {
    _finalizer.detach(this);
    pathspecFree(_handle);
  }

  static int _bits(Set<PathspecFlag> flags) {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    return bits;
  }
}
