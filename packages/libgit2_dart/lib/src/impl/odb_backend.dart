part of 'api.dart';

/// A pluggable [Odb] backend.
///
/// Build one of the built-in backends with [OdbBackend.loose],
/// [OdbBackend.pack], or [OdbBackend.onePack] and attach it through
/// [OdbBackendOps.addBackend] or [OdbBackendOps.addAlternate]. The
/// target [Odb] takes ownership on attachment: the same backend
/// must not be attached twice and the wrapper must not be reused.
///
/// ```dart
/// final odb = Odb.fromObjectsDir('/path/.git/objects');
/// final extra = OdbBackend.pack('/path/to/other/objects');
/// odb.addBackend(extra, priority: 10);
/// ```
@immutable
final class OdbBackend {
  final int _handle;

  /// Creates a backend serving loose objects rooted at [objectsDir].
  ///
  /// [compressionLevel] follows zlib's 0–9 range — pass `-1` for
  /// the default. When [doFsync] is true every write is flushed to
  /// survive a crash. [dirMode] and [fileMode] set POSIX permissions
  /// for newly created directories and files; `0` picks the
  /// defaults.
  factory OdbBackend.loose(
    String objectsDir, {
    int compressionLevel = -1,
    bool doFsync = false,
    int dirMode = 0,
    int fileMode = 0,
  }) => OdbBackend._(
    odbBackendLoose(
      objectsDir,
      compressionLevel: compressionLevel,
      doFsync: doFsync,
      dirMode: dirMode,
      fileMode: fileMode,
    ),
  );

  /// Creates a backend serving the single packfile whose `.idx`
  /// lives at [indexFile].
  ///
  /// Useful for inspecting the contents of an individual packfile.
  factory OdbBackend.onePack(String indexFile) =>
      OdbBackend._(odbBackendOnePack(indexFile));

  /// Creates a backend serving every packfile under [objectsDir].
  ///
  /// [objectsDir] is the `.git/objects` directory of a repository.
  factory OdbBackend.pack(String objectsDir) =>
      OdbBackend._(odbBackendPack(objectsDir));

  const OdbBackend._(this._handle);
}

/// Backend-management operations on [Odb].
extension OdbBackendOps on Odb {
  /// Attaches [backend] as an alternate store.
  ///
  /// Alternate backends are consulted after the primaries and never
  /// accept writes. Higher [priority] values are checked first.
  /// Ownership of [backend] transfers to this database.
  void addAlternate(OdbBackend backend, {int priority = 0}) {
    odbAddAlternate(_handle, backend._handle, priority);
  }

  /// Attaches [backend] as a primary backend.
  ///
  /// Higher [priority] values are consulted first. Ownership of
  /// [backend] transfers to this database.
  void addBackend(OdbBackend backend, {int priority = 0}) {
    odbAddBackend(_handle, backend._handle, priority);
  }

  /// Returns the backend at [position].
  ///
  /// The returned wrapper shares its handle with this database and
  /// must not be attached to another [Odb].
  OdbBackend backendAt(int position) {
    return OdbBackend._(odbGetBackend(_handle, position));
  }
}
