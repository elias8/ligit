part of 'api.dart';

/// A loaded list of filters that apply to a single path.
///
/// Which filters run for a given file is determined by the
/// `.gitattributes` rules for that path. libgit2 ships the `crlf`
/// and `ident` filters, and applications can register more through
/// the `sys/` API.
///
/// Obtain a [FilterList] with [FilterList.load] or
/// [FilterList.loadFromCommit]; both return `null` when no filters
/// apply. Must be [dispose]d when done.
///
/// ```dart
/// final filters = FilterList.load(
///   repo: repo,
///   path: 'README.md',
///   mode: FilterMode.toOdb,
/// );
/// if (filters != null) {
///   try {
///     final cleaned = filters.applyToBuffer(workdirBytes);
///     // ...
///   } finally {
///     filters.dispose();
///   }
/// }
/// ```
@immutable
final class FilterList {
  static final _finalizer = Finalizer<int>(filterListFree);

  final int _handle;

  /// Loads the filter pipeline that applies to [path] in [repo].
  ///
  /// Returns `null` when no filters are requested for that file.
  /// [blob] supplies the blob the filters will run on, when known.
  /// [flags] tunes whether system attributes are loaded and which
  /// source the attributes are read from.
  static FilterList? load({
    required Repository repo,
    required String path,
    required FilterMode mode,
    Blob? blob,
    Set<FilterFlag> flags = const {},
  }) {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    final handle = filterListLoad(
      repo._handle,
      path,
      mode.value,
      blobHandle: blob?._handle ?? 0,
      flags: bits,
    );
    if (handle == 0) return null;
    return FilterList._(handle);
  }

  /// Loads the filter pipeline using attributes pulled from the
  /// commit identified by [attrCommitId].
  ///
  /// Returns `null` when no filters are requested for that file.
  /// [flags] must include [FilterFlag.attributesFromCommit] for this
  /// path to take effect.
  static FilterList? loadFromCommit({
    required Repository repo,
    required String path,
    required FilterMode mode,
    required Oid attrCommitId,
    Blob? blob,
    Set<FilterFlag> flags = const {FilterFlag.attributesFromCommit},
  }) {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    final handle = filterListLoadExt(
      repo._handle,
      path,
      mode.value,
      blobHandle: blob?._handle ?? 0,
      flags: bits,
      attrCommitId: attrCommitId._bytes,
    );
    if (handle == 0) return null;
    return FilterList._(handle);
  }

  FilterList._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Whether the filter named [name] is part of this list.
  ///
  /// Use the canonical filter names — `crlf`, `ident`, or the value
  /// of the `filter` attribute for custom drivers.
  bool contains(String name) => filterListContains(_handle, name);

  /// Applies this filter list to the in-memory [data].
  Uint8List applyToBuffer(Uint8List data) =>
      filterListApplyToBuffer(_handle, data);

  /// Applies this filter list to the file at [path] inside [repo].
  ///
  /// A relative [path] is taken as relative to the working
  /// directory.
  Uint8List applyToFile(Repository repo, String path) =>
      filterListApplyToFile(_handle, repo._handle, path);

  /// Applies this filter list to the contents of [blob].
  Uint8List applyToBlob(Blob blob) =>
      filterListApplyToBlob(_handle, blob._handle);

  /// Streams the filtered result of [data] through [onChunk].
  ///
  /// Useful for large buffers where materializing the full output
  /// into a single [Uint8List] is undesirable.
  void streamBuffer(Uint8List data, void Function(Uint8List chunk) onChunk) =>
      filterListStreamBuffer(_handle, data, onChunk);

  /// Streams the filtered contents of [blob] through [onChunk].
  void streamBlob(Blob blob, void Function(Uint8List chunk) onChunk) =>
      filterListStreamBlob(_handle, blob._handle, onChunk);

  /// Streams the filtered contents of the file at [path] inside
  /// [repo] through [onChunk].
  ///
  /// A relative [path] is taken as relative to the working
  /// directory.
  void streamFile(
    Repository repo,
    String path,
    void Function(Uint8List chunk) onChunk,
  ) => filterListStreamFile(_handle, repo._handle, path, onChunk);

  /// Releases the native filter list.
  void dispose() {
    _finalizer.detach(this);
    filterListFree(_handle);
  }
}
