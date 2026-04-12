part of 'api.dart';

/// A reference database.
///
/// [RefDb] is the pluggable reference-store a repository uses to read
/// and write `refs/...` entries. Most callers never need to touch it
/// directly: [RepositoryReference.references] and [Reference.create]
/// already go through the repository's default refdb. Reach for this
/// class when you need to [compress] an on-disk refdb (which packs
/// loose refs), or when an API requires an explicit refdb instance.
///
/// Instances own native memory and must be [dispose]d when no longer
/// needed.
///
/// ```dart
/// final refdb = RefDb.fromRepository(repo);
/// try {
///   refdb.compress();
/// } finally {
///   refdb.dispose();
/// }
/// ```
@immutable
final class RefDb {
  static final _finalizer = Finalizer<int>(refdbFree);

  final int _handle;

  /// Opens a refdb for [repo] and attaches the default backends.
  ///
  /// The default backend reads and writes loose and packed refs from
  /// disk, treating the repository directory as the storage folder.
  /// The result is a fresh handle; the repository's own refdb is
  /// unaffected. Use [RefDb.fromRepository] to obtain the refdb the
  /// repository already has installed.
  factory RefDb.open(Repository repo) => RefDb._(refdbOpen(repo._handle));

  /// Returns a handle for the refdb currently in use by [repo].
  factory RefDb.fromRepository(Repository repo) =>
      RefDb._(refdbFromRepository(repo._handle));

  /// Creates an empty refdb for [repo] with no backends attached.
  ///
  /// Before the refdb can be read or written a custom backend must
  /// be registered through the libgit2 `sys/` extension hooks. Most
  /// callers should prefer [RefDb.open] or [RefDb.fromRepository].
  factory RefDb.empty(Repository repo) => RefDb._(refdbNew(repo._handle));

  RefDb._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Asks the refdb to compact or optimize its storage.
  ///
  /// The behaviour is backend-specific. On the default on-disk
  /// backend this packs every loose reference; other backends may
  /// no-op.
  void compress() => refdbCompress(_handle);

  /// Releases the native refdb handle.
  void dispose() {
    _finalizer.detach(this);
    refdbFree(_handle);
  }
}
