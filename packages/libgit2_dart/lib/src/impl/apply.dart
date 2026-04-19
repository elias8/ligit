part of 'api.dart';

/// Flags controlling the behavior of [RepositoryApply.apply] and
/// [RepositoryApply.applyToTree].
typedef ApplyFlag = apply_bindings.ApplyFlags;

/// Patch application routines operating on a [Repository].
extension RepositoryApply on Repository {
  /// Applies [diff] to this repository, making changes directly in
  /// the working directory, the index, or both.
  ///
  /// [location] selects the target: [ApplyLocation.workdir] (the
  /// default) mirrors `git apply`, [ApplyLocation.index] mirrors
  /// `git apply --cached`, and [ApplyLocation.both] mirrors
  /// `git apply --index`. Include [ApplyFlag.check] in [flags] to
  /// probe whether the patch would apply without writing any
  /// changes.
  ///
  /// [onDelta] is invoked immediately before each file delta and
  /// [onHunk] before each hunk. Return `0` to keep the change, a
  /// positive value to skip it, or a negative value to abort the
  /// whole apply. A Dart exception thrown from either callback
  /// translates to an abort.
  void apply(
    Diff diff, {
    ApplyLocation location = ApplyLocation.workdir,
    Set<ApplyFlag> flags = const {},
    int Function(DiffDelta delta)? onDelta,
    int Function(DiffHunk hunk)? onHunk,
  }) {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    apply_bindings.apply(
      _handle,
      diff._handle,
      location: location.value,
      flags: bits,
      onDelta: onDelta == null ? null : (r) => onDelta(DiffDelta._(r)),
      onHunk: onHunk == null ? null : (r) => onHunk(DiffHunk._(r)),
    );
  }

  /// Applies [diff] to [preimage] and returns the resulting image
  /// as an [Index].
  ///
  /// [onDelta] and [onHunk] behave as in [apply]. Callers must
  /// [Index.dispose] the returned index.
  Index applyToTree(
    Tree preimage,
    Diff diff, {
    Set<ApplyFlag> flags = const {},
    int Function(DiffDelta delta)? onDelta,
    int Function(DiffHunk hunk)? onHunk,
  }) {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    return Index._(
      apply_bindings.applyToTree(
        _handle,
        preimage._handle,
        diff._handle,
        flags: bits,
        onDelta: onDelta == null ? null : (r) => onDelta(DiffDelta._(r)),
        onHunk: onHunk == null ? null : (r) => onHunk(DiffHunk._(r)),
      ),
    );
  }
}
