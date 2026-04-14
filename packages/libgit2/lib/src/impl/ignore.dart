part of 'api.dart';

/// Ignore-rule management on [Repository].
extension RepositoryIgnore on Repository {
  /// Adds [rules] to the repository's internal ignore list.
  ///
  /// In addition to the rules read from `.gitignore` files in the
  /// tree and the system excludes file, libgit2 keeps a
  /// per-repository set of in-memory ignore rules. This method
  /// appends to that set; the rules are not persisted.
  ///
  /// [rules] is the text you would write in a `.gitignore` file.
  /// Multiple rules may be included in a single call if each rule is
  /// terminated by a newline.
  void addIgnoreRule(String rules) => ignoreAddRule(_handle, rules);

  /// Resets the internal ignore list to libgit2's default rules.
  ///
  /// Removes every entry previously added via [addIgnoreRule].
  /// `.gitignore` files on disk are not affected. The default
  /// internal rules ignore `.`, `..` and `.git`.
  void clearInternalIgnoreRules() => ignoreClearInternalRules(_handle);

  /// Whether the ignore rules would apply to [path].
  ///
  /// Checks the ignore rules independently of whether [path] is
  /// already tracked in the index or committed. Equivalent to
  /// `git check-ignore --no-index`. [path] is interpreted relative
  /// to the working directory and does not have to exist on disk.
  bool isIgnored(String path) => ignorePathIsIgnored(_handle, path);
}
