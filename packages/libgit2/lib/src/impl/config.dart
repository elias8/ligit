part of 'api.dart';

/// A Git configuration.
///
/// A [Config] is a prioritized stack of backends (system, global,
/// XDG, local, worktree, app). Reads return the value from the
/// highest-priority backend that defines the key; writes go to the
/// highest writable level by default. Obtain one through
/// [Config.fromRepository], [Config.openDefault], [Config.openOnDisk],
/// [Config.empty], or [Repository.config].
///
/// Typed getters return `null` when the key is not set; typed setters
/// write unconditionally. Must be [dispose]d when done.
///
/// ```dart
/// final cfg = repo.config();
/// try {
///   cfg.setString('user.name', 'Ada');
///   print(cfg.getString('user.name'));
///   for (final e in cfg.list(pattern: r'^user\.')) {
///     print('${e.name}=${e.value}');
///   }
/// } finally {
///   cfg.dispose();
/// }
/// ```
@immutable
final class Config {
  static final _finalizer = Finalizer<int>(configFree);

  final int _handle;

  /// Allocates an empty configuration object.
  ///
  /// Use [addFileOnDisk] to layer on-disk files at specific priority
  /// levels.
  factory Config.empty() => Config._(configNew());

  /// Opens the merged multi-level configuration for [repo].
  factory Config.fromRepository(Repository repo) =>
      Config._(configFromRepository(repo._handle));

  /// Opens the global, XDG and system configuration files as a single
  /// prioritized object, following git's rules.
  factory Config.openDefault() => Config._(configOpenDefault());

  /// Opens the single on-disk configuration file at [path].
  factory Config.openOnDisk(String path) => Config._(configOpenOnDisk(path));

  /// Creates a consistent read-only snapshot of the configuration for
  /// [repo].
  factory Config.snapshotFromRepository(Repository repo) =>
      Config._(configSnapshotFromRepository(repo._handle));

  Config._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Adds [path] as an on-disk backend of this configuration at
  /// [level].
  ///
  /// The file is created on first write if missing. Set [force] to
  /// replace any existing backend at [level]. Pass [repo] to enable
  /// conditional `includeIf` parsing against that repository.
  ///
  /// Throws [ExistsException] when a backend is already registered at
  /// [level] and [force] is false.
  void addFileOnDisk(
    String path,
    ConfigLevel level, {
    Repository? repo,
    bool force = false,
  }) {
    configAddFileOnDisk(
      _handle,
      path,
      level,
      repoHandle: repo?._handle,
      force: force,
    );
  }

  /// Deletes the variable [name] from the config file with the
  /// highest level (usually the local one).
  ///
  /// Throws [NotFoundException] when no such variable is set.
  void deleteEntry(String name) => configDeleteEntry(_handle, name);

  /// Deletes every multivar entry for [name] whose value matches the
  /// regular expression [pattern].
  void deleteMultivar(String name, String pattern) =>
      configDeleteMultivar(_handle, name, pattern);

  /// Releases the native configuration handle.
  void dispose() {
    _finalizer.detach(this);
    configFree(_handle);
  }

  /// Reads the boolean value of [name], or `null` when unset.
  bool? getBool(String name) => configGetBool(_handle, name);

  /// Reads the full [ConfigEntry] for [name], or `null` when unset.
  ConfigEntry? getEntry(String name) {
    final raw = configGetEntry(_handle, name);
    if (raw == null) return null;
    return ConfigEntry._(
      name: raw.name,
      value: raw.value,
      backendType: raw.backendType,
      originPath: raw.originPath,
      includeDepth: raw.includeDepth,
      level: raw.level,
    );
  }

  /// Reads the 64-bit integer value of [name], or `null` when unset.
  ///
  /// Honors the `k`, `m` and `g` suffixes.
  int? getInt(String name) => configGetInt64(_handle, name);

  /// Reads the 32-bit integer value of [name], or `null` when unset.
  ///
  /// Honors the `k`, `m` and `g` suffixes.
  int? getInt32(String name) => configGetInt32(_handle, name);

  /// Reads the path value of [name], or `null` when unset.
  ///
  /// A leading `~` is expanded to the configured home directory, and
  /// `~user` to the user's home directory.
  String? getPath(String name) => configGetPath(_handle, name);

  /// Reads the string value of [name], or `null` when unset.
  String? getString(String name) => configGetString(_handle, name);

  /// Lists every variable as `(name, value)` records.
  ///
  /// When [pattern] is non-null, only variables whose name matches
  /// the regular expression are returned.
  List<({String name, String value})> list({String? pattern}) =>
      configList(_handle, pattern: pattern);

  /// Lists every value of the multivar [name].
  ///
  /// When [pattern] is non-null, values are filtered to those
  /// matching the regular expression.
  List<String> multivar(String name, {String? pattern}) =>
      configMultivar(_handle, name, pattern: pattern);

  /// Opens the global or XDG configuration file that should receive
  /// writes, following git's rules.
  Config openGlobal() => Config._(configOpenGlobal(_handle));

  /// Opens a single-level view of this configuration focused on
  /// [level].
  ///
  /// Throws [NotFoundException] when no backend is registered at
  /// [level].
  Config openLevel(ConfigLevel level) =>
      Config._(configOpenLevel(_handle, level));

  /// Sets the boolean variable [name] to [value] in the config file
  /// with the highest level (usually the local one).
  void setBool(String name, {required bool value}) =>
      configSetBool(_handle, name, value: value);

  /// Sets the 64-bit integer variable [name] to [value].
  void setInt(String name, int value) => configSetInt64(_handle, name, value);

  /// Sets the 32-bit integer variable [name] to [value].
  void setInt32(String name, int value) => configSetInt32(_handle, name, value);

  /// Replaces every value of the multivar [name] whose existing value
  /// matches [pattern] with [value].
  void setMultivar(String name, String pattern, String value) =>
      configSetMultivar(_handle, name, pattern, value);

  /// Sets the string variable [name] to [value].
  void setString(String name, String value) =>
      configSetString(_handle, name, value);

  /// Creates a consistent read-only snapshot of this configuration.
  ///
  /// Subsequent reads hit the snapshot and therefore do not observe
  /// changes made to the underlying files after this call.
  Config snapshot() => Config._(configSnapshot(_handle));

  /// Invokes [callback] for every variable in this configuration.
  ///
  /// Pass [pattern] to restrict iteration to variables whose name
  /// matches the regular expression. Returning a non-zero value from
  /// [callback] stops iteration and is surfaced as this method's
  /// return.
  int forEach(int Function(ConfigEntry entry) callback, {String? pattern}) {
    return configForeach(
      _handle,
      (raw) => callback(_entryFrom(raw)),
      pattern: pattern,
    );
  }

  /// Invokes [callback] for every value of the multivar [name].
  ///
  /// Pass [pattern] to filter values with a regular expression.
  /// Returning a non-zero value from [callback] stops iteration.
  int forEachMultivar(
    String name,
    int Function(ConfigEntry entry) callback, {
    String? pattern,
  }) {
    return configMultivarForeach(
      _handle,
      name,
      (raw) => callback(_entryFrom(raw)),
      pattern: pattern,
    );
  }

  /// Sets the order in which writes are applied across backends.
  ///
  /// An empty list restores the default
  /// (highest-priority-writable-first) ordering.
  void setWriteOrder(List<ConfigLevel> levels) =>
      configSetWriteOrder(_handle, levels);

  static ConfigEntry _entryFrom(ConfigEntryRecord raw) {
    return ConfigEntry._(
      name: raw.name,
      value: raw.value,
      backendType: raw.backendType,
      originPath: raw.originPath,
      includeDepth: raw.includeDepth,
      level: raw.level,
    );
  }

  /// Locates the user's global configuration file (typically
  /// `~/.gitconfig`), or returns `null` when none is found.
  static String? findGlobal() => configFindGlobal();

  /// Locates the ProgramData configuration file (Windows-only), or
  /// returns `null` when none is found.
  static String? findProgramData() => configFindProgramData();

  /// Locates the system-wide configuration file, or returns `null`
  /// when none is found.
  static String? findSystem() => configFindSystem();

  /// Locates the XDG-compatible configuration file, or returns
  /// `null` when none is found.
  static String? findXdg() => configFindXdg();

  /// Parses [value] as a boolean using git's rules.
  ///
  /// Valid `true` values are `true`, `yes`, `on` and any positive
  /// integer. Valid `false` values are `false`, `no`, `off` and `0`.
  static bool parseBool(String value) => configParseBool(value);

  /// Parses [value] as a 64-bit integer, honoring the `k`, `m` and
  /// `g` suffixes.
  static int parseInt(String value) => configParseInt64(value);

  /// Parses [value] as a 32-bit integer, honoring the `k`, `m` and
  /// `g` suffixes.
  static int parseInt32(String value) => configParseInt32(value);

  /// Parses [value] as a path, expanding a leading `~` to the
  /// configured home directory (and `~user` to that user's home).
  static String parsePath(String value) => configParsePath(value);
}

/// A single resolved configuration entry.
///
/// A pure Dart value type: every field is copied out of libgit2's
/// buffers at construction time, so instances outlive the [Config]
/// they came from.
@immutable
final class ConfigEntry {
  /// Normalized name of the entry.
  final String name;

  /// Literal string value of the entry.
  final String value;

  /// Backend type that produced the entry (typically `file`).
  final String backendType;

  /// Path to the origin of the entry.
  ///
  /// For file-backed entries, this is the on-disk path of the file.
  final String originPath;

  /// Depth of `include` chains where the variable was found.
  final int includeDepth;

  /// Configuration level the entry was read from.
  final ConfigLevel level;

  const ConfigEntry._({
    required this.name,
    required this.value,
    required this.backendType,
    required this.originPath,
    required this.includeDepth,
    required this.level,
  });

  @override
  int get hashCode =>
      Object.hash(name, value, backendType, originPath, includeDepth, level);

  @override
  bool operator ==(Object other) =>
      other is ConfigEntry &&
      name == other.name &&
      value == other.value &&
      backendType == other.backendType &&
      originPath == other.originPath &&
      includeDepth == other.includeDepth &&
      level == other.level;

  @override
  String toString() => 'ConfigEntry($name=$value)';
}
