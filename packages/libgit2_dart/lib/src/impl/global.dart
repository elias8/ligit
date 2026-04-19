part of 'api.dart';

/// Configurable features of libgit2; either optional settings (like
/// threading), or features that can be enabled by one of a number of
/// different backend providers (like HTTPS, which can be provided by
/// OpenSSL, mbedTLS, or system libraries).
typedef LibgitFeature = Feature;

/// Global initialization, shutdown, and introspection for libgit2.
///
/// [init] must run before any other libgit2 call. It is reference
/// counted and safe to call from every module that needs libgit2, as
/// long as each [init] is paired with a matching [shutdown]. Real
/// cleanup of global state and the threading context only happens on
/// the [shutdown] that balances the last outstanding [init].
///
/// [initCount] observes the current reference count; [shutdownAll]
/// unwinds every outstanding [init] in one go.
///
/// [runtimeVersion], [prerelease], [features], and [featureBackend]
/// report what the dynamically loaded libgit2 library supports at
/// run time.
abstract final class Libgit2 {
  /// The libgit2 version this package was built against.
  ///
  /// Compile-time constant. When the package runs against a
  /// dynamically loaded libgit2 of a different version, this value
  /// still reflects the build-time headers.
  static const version = Libgit2Version(
    major: libgit2VersionMajor,
    minor: libgit2VersionMinor,
    revision: libgit2VersionRevision,
    // ignore: avoid_redundant_argument_values
    patch: libgit2VersionPatch,
  );

  /// ABI soversion of the linked libgit2 shared library.
  ///
  /// Only bumped on breaking ABI changes, so it can lag the [version]
  /// string across API-only releases.
  static const soversion = libgit2Soversion;

  /// The version reported by the dynamically loaded libgit2 library
  /// at run time.
  ///
  /// Compare against [version] (the compile-time constant) to verify
  /// the runtime library matches the headers the package was built
  /// against.
  ///
  /// Requires a prior [init] call.
  ///
  /// Throws [Libgit2Exception] when the query fails.
  static Libgit2Version get runtimeVersion {
    final v = commonLibgit2Version();
    return Libgit2Version(major: v.major, minor: v.minor, revision: v.revision);
  }

  /// The prerelease label of the loaded libgit2 (`alpha`, `beta`,
  /// `rc1`, etc.), or `null` for a final release.
  ///
  /// Requires a prior [init] call.
  static String? get prerelease => commonLibgit2Prerelease();

  /// The set of features compiled into the loaded libgit2.
  ///
  /// Each [LibgitFeature] flag indicates a capability that is present
  /// (threads, HTTPS, SSH, etc.).
  ///
  /// Requires a prior [init] call.
  static Set<LibgitFeature> get features => commonLibgit2Features();

  /// The provider backend name for [feature], or `null` when
  /// [feature] is not compiled in.
  ///
  /// For example, HTTPS support might return `openssl`, `mbedtls`, or
  /// `schannel` depending on how libgit2 was built.
  ///
  /// Requires a prior [init] call.
  static String? featureBackend(LibgitFeature feature) =>
      commonLibgit2FeatureBackend(feature);

  static var _outstanding = 0;

  /// The number of outstanding libgit2 global-state references as of
  /// the most recent [init] or [shutdown] call.
  ///
  /// Starts at `0` before the first [init]. Mirrors libgit2's own
  /// atomic reference counter: each [init] updates it with the count
  /// returned by libgit2 (including that call), and each [shutdown]
  /// updates it with the remaining count (after that call). Reaches
  /// `0` only when libgit2's global state has been torn down.
  static int get initCount => _outstanding;

  /// Initializes libgit2's global state and threading context.
  ///
  /// Must run before any other libgit2 call. Safe to invoke multiple
  /// times; each call increments the reference count, updates
  /// [initCount], and must be paired with a matching [shutdown].
  /// Returns the total init count including this call.
  ///
  /// Throws [Libgit2Exception] when libgit2 reports an error setting
  /// up global state.
  static int init() => _outstanding = libgit2Init();

  /// Decrements the init count, releasing libgit2's global state and
  /// threading context once it reaches zero.
  ///
  /// Must be called exactly once for every [init]; real cleanup only
  /// happens on the [shutdown] that balances the last outstanding
  /// [init]. Earlier calls are cheap counter decrements. Returns the
  /// remaining init count after this call, also exposed via
  /// [initCount].
  ///
  /// Throws [Libgit2Exception] when libgit2 reports an error tearing
  /// global state down.
  static int shutdown() => _outstanding = libgit2Shutdown();

  /// Fully tears down libgit2 by running [shutdown] until [initCount]
  /// reaches zero.
  ///
  /// Unwinds every outstanding init, including any made outside this
  /// class, since the underlying reference counter is libgit2's global
  /// atomic. After this returns, libgit2's global state is gone and
  /// [init] must run again before any further libgit2 use.
  ///
  /// A no-op when [initCount] is already zero.
  ///
  /// Throws [Libgit2Exception] when any [shutdown] fails along the
  /// way; the remaining inits are left outstanding and [initCount]
  /// reflects the partial unwinding.
  static void shutdownAll() {
    while (_outstanding > 0) {
      shutdown();
    }
  }
}
