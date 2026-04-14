part of 'api.dart';

/// Status flags for a single file.
///
/// A combination of these values describes how a file has changed.
/// `INDEX` flags compare the staged state to HEAD; `WT` flags compare
/// the working directory to the index.
typedef StatusFlag = Status;

/// Flags controlling which files and comparisons status reports
/// include.
typedef StatusOption = StatusOpt;

/// Status entry for a single path.
///
/// [flags] is the set of [StatusFlag] values describing how [path]
/// differs between HEAD, the index, and the working tree.
@immutable
final class StatusEntry {
  /// Path to the affected file, relative to the working directory.
  final String path;

  /// Status bits for this path.
  final Set<StatusFlag> flags;

  const StatusEntry._({required this.path, required this.flags});

  /// Whether this entry is unchanged.
  bool get isCurrent => flags.isEmpty || flags.contains(StatusFlag.current);

  /// Whether the file is ignored.
  bool get isIgnored => flags.contains(StatusFlag.ignored);

  /// Whether the file has unresolved merge conflicts.
  bool get isConflicted => flags.contains(StatusFlag.conflicted);

  @override
  int get hashCode => Object.hash(path, Object.hashAllUnordered(flags));

  @override
  bool operator ==(Object other) =>
      other is StatusEntry &&
      other.path == path &&
      other.flags.length == flags.length &&
      other.flags.containsAll(flags);

  @override
  String toString() => 'StatusEntry($path, $flags)';
}

/// Working-tree status on [Repository].
extension RepositoryStatus on Repository {
  /// Reads the status of a single [path].
  ///
  /// Throws [NotFoundException] when [path] is absent from HEAD,
  /// index, and working tree. Throws [AmbiguousException] when
  /// [path] resolves to more than one file.
  Set<StatusFlag> fileStatus(String path) =>
      _decodeStatus(statusFile(_handle, path));

  /// Whether the ignore rules would ignore [path] if it were added.
  bool shouldIgnore(String path) => statusShouldIgnore(_handle, path);

  /// Computes the status for every file in the repository matching
  /// the options.
  ///
  /// [show] restricts the comparison to the HEAD/index side, the
  /// index/workdir side, or both. [options] controls untracked and
  /// ignored inclusion, rename detection, and other flags.
  /// [pathspec] filters the reported paths. Pass [baseline] to
  /// compare against a tree other than HEAD. [renameThreshold] is
  /// the similarity percentage above which a file is considered a
  /// rename.
  List<StatusEntry> status({
    StatusShow show = StatusShow.indexAndWorkdir,
    Set<StatusOption> options = const {},
    List<String> pathspec = const [],
    Tree? baseline,
    int renameThreshold = 50,
  }) {
    final bits = options.isEmpty
        ? statusOptDefaults
        : options.fold<int>(0, (acc, f) => acc | f.value);
    final listHandle = statusListNew(
      _handle,
      show: show,
      flags: bits,
      pathspec: pathspec,
      baselineTreeHandle: baseline?._handle,
      renameThreshold: renameThreshold,
    );
    try {
      final count = statusListEntryCount(listHandle);
      final result = <StatusEntry>[];
      for (var i = 0; i < count; i++) {
        final entry = statusListEntry(listHandle, i);
        if (entry == null) continue;
        result.add(
          StatusEntry._(path: entry.path, flags: _decodeStatus(entry.flags)),
        );
      }
      return result;
    } finally {
      statusListFree(listHandle);
    }
  }

  /// Invokes [callback] for every changed file.
  ///
  /// When all of [options], [show], [pathspec], [baseline], and
  /// [renameThreshold] are left at their defaults, uses the
  /// lightweight iteration path; supplying any of them switches to
  /// the extended form with the same option semantics as [status].
  /// Returning a non-zero value from [callback] stops iteration and
  /// is surfaced as this call's return.
  int forEachStatus(
    int Function(StatusEntry entry) callback, {
    StatusShow? show,
    Set<StatusOption>? options,
    List<String> pathspec = const [],
    Tree? baseline,
    int? renameThreshold,
  }) {
    int bridge(String path, int flags) =>
        callback(StatusEntry._(path: path, flags: _decodeStatus(flags)));
    if (show == null &&
        options == null &&
        pathspec.isEmpty &&
        baseline == null &&
        renameThreshold == null) {
      return statusForeach(_handle, bridge);
    }
    final bits = options == null
        ? statusOptDefaults
        : options.fold<int>(0, (acc, f) => acc | f.value);
    return statusForeachExt(
      _handle,
      bridge,
      show: show ?? StatusShow.indexAndWorkdir,
      flags: bits,
      pathspec: pathspec,
      baselineTreeHandle: baseline?._handle,
      renameThreshold: renameThreshold ?? 50,
    );
  }

  static Set<StatusFlag> _decodeStatus(int bits) {
    if (bits == 0) return const {StatusFlag.current};
    return {
      for (final f in StatusFlag.values)
        if (f != StatusFlag.current && bits & f.value != 0) f,
    };
  }
}
