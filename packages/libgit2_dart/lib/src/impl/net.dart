part of 'api.dart';

/// Networking constants for the git:// transport.
abstract final class GitNet {
  /// Default port of the git protocol (`"9418"`).
  ///
  /// Used with `git://host/path` URLs that do not specify a port.
  static const defaultPort = gitDefaultPort;
}
