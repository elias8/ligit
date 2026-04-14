part of 'api.dart';

/// Stash flags.
typedef StashFlag = StashFlags;

/// Stash application flags.
typedef StashApplyFlag = StashApplyFlags;

/// Stash operations on [Repository].
extension RepositoryStash on Repository {
  /// Saves the local modifications to a new stash.
  ///
  /// The returned [Oid] is the commit containing the stashed state,
  /// which is also the target of the direct reference `refs/stash`.
  /// [stasher] is recorded as both author and committer. [message]
  /// is an optional description. [flags] controls which changes are
  /// included. When [paths] is non-empty the stash is restricted to
  /// matching files.
  ///
  /// Throws [NotFoundException] when there is nothing to stash.
  Oid stash({
    required Signature stasher,
    String? message,
    Set<StashFlag> flags = const {},
    List<String> paths = const [],
  }) {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    final stasherHandle = signatureNew(
      stasher.name,
      stasher.email,
      stasher._record.time,
      stasher._record.offset,
    );
    try {
      final bytes = paths.isEmpty
          ? stashSave(_handle, stasherHandle, message: message, flags: bits)
          : stashSaveWithOpts(
              _handle,
              stasherHandle,
              message: message,
              flags: bits,
              paths: paths,
            );
      return Oid._(bytes);
    } finally {
      signatureFree(stasherHandle);
    }
  }

  /// Applies the stash at [index] without removing it from the list.
  ///
  /// Index `0` refers to the most recent stashed state. Include
  /// [StashApplyFlag.reinstateIndex] to also restore the staged
  /// changes.
  ///
  /// When local changes in the working directory conflict with the
  /// stashed state the index and working directory are left
  /// unmodified; when restoring untracked or ignored files and a
  /// conflict occurs while applying modified files, those files
  /// remain in the working directory.
  ///
  /// Throws [NotFoundException] when no stash exists at [index].
  /// Throws [ConflictException] when the working tree or index
  /// conflicts with the stashed state.
  void applyStash(int index, {Set<StashApplyFlag> flags = const {}}) {
    stashApply(_handle, index, flags: _apply(flags));
  }

  /// Applies the stash at [index] and drops it on success.
  ///
  /// See [applyStash] for the conflict semantics. Index `0` refers
  /// to the most recent stashed state.
  void popStash(int index, {Set<StashApplyFlag> flags = const {}}) {
    stashPop(_handle, index, flags: _apply(flags));
  }

  /// Removes the stash at [index].
  ///
  /// Index `0` refers to the most recent stashed state.
  ///
  /// Throws [NotFoundException] when no stash exists at [index].
  void dropStash(int index) => stashDrop(_handle, index);

  /// Invokes [callback] for every stashed state, newest first.
  ///
  /// [callback] receives the 0-based stash index, the stash
  /// message, and the commit [Oid] of the stashed state. Returning
  /// a non-zero value stops iteration and is surfaced as this
  /// call's return.
  int forEachStash(
    int Function(int index, String message, Oid stashId) callback,
  ) {
    return stashForeach(
      _handle,
      (index, message, id) => callback(index, message, Oid._(id)),
    );
  }

  static int _apply(Set<StashApplyFlag> flags) {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    return bits;
  }
}
