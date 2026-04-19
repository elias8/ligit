part of 'api.dart';

/// Kinds of reset operation.
typedef ResetMode = rst.Reset;

/// Reset operations on [Repository].
extension RepositoryReset on Repository {
  /// Moves HEAD to [target] and optionally resets the index and
  /// working tree to match.
  ///
  /// [target] must belong to this repository and be either a commit
  /// or a tag that dereferences to one. [mode] selects the scope:
  /// [ResetMode.soft] moves HEAD only; [ResetMode.mixed] also
  /// replaces the index with the target tree; [ResetMode.hard]
  /// additionally overwrites the working directory. Untracked and
  /// ignored files are left alone.
  void reset(GitObject target, ResetMode mode) {
    rst.reset(_handle, target._handle, mode);
  }

  /// Updates index entries matching [pathspecs] to the contents of
  /// [target]'s tree.
  ///
  /// Pass `null` for [target] to remove matching entries from the
  /// index (unstage them).
  void resetDefault({
    required GitObject? target,
    required List<String> pathspecs,
  }) {
    rst.resetDefault(_handle, target?._handle, pathspecs);
  }

  /// Like [reset], but records the extended-sha expression carried
  /// by [target] in the reflog message.
  void resetFromAnnotated(AnnotatedCommit target, ResetMode mode) {
    rst.resetFromAnnotated(_handle, target._handle, mode);
  }
}
