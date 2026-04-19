import 'dart:io';

/// Environment variable that overrides source resolution with a local checkout.
const libgit2SrcEnvKey = 'LIBGIT2_SRC';

const _defaultTarballBase =
    'https://github.com/libgit2/libgit2/archive/refs/tags';

/// Downloads a libgit2 source tarball, extracts it, and caches the result.
///
/// Uses [tarballUrl] if provided, otherwise builds a URL from the pinned tag
/// in `libgit2.version`.
Future<Directory> downloadSource(
  Uri cacheBase, {
  required Uri packageRoot,
  String? tarballUrl,
}) async {
  final tag = pinnedTag(packageRoot);
  final cacheDir = Directory.fromUri(cacheBase.resolve('libgit2-source-$tag/'));
  if (cacheDir.existsSync()) return cacheDir;

  tarballUrl ??= '$_defaultTarballBase/$tag.tar.gz';

  final tarball = File.fromUri(cacheBase.resolve('$tag.tar.gz'));
  tarball.parent.createSync(recursive: true);

  final httpClient = HttpClient();
  try {
    final request = await httpClient.getUrl(Uri.parse(tarballUrl));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download libgit2 source: HTTP ${response.statusCode}. '
        'Check your network connection or set $libgit2SrcEnvKey to a local '
        'checkout.',
      );
    }
    final sink = tarball.openWrite();
    await response.pipe(sink);
  } finally {
    httpClient.close();
  }

  cacheDir.createSync(recursive: true);
  final extractResult = Process.runSync('tar', [
    'xzf',
    tarball.path,
    '-C',
    cacheDir.path,
    '--strip-components=1',
  ]);
  if (extractResult.exitCode != 0) {
    cacheDir.deleteSync(recursive: true);
    throw Exception(
      'Failed to extract libgit2 source: ${extractResult.stderr}',
    );
  }

  tarball.deleteSync();

  return cacheDir;
}

/// Reads the pinned libgit2 tag from `libgit2.version` at [packageRoot].
String pinnedTag(Uri packageRoot) {
  final file = File.fromUri(packageRoot.resolve('libgit2.version'));
  if (!file.existsSync()) {
    throw StateError(
      'libgit2.version not found at ${file.path}. '
      'This file must contain the pinned libgit2 release tag (e.g. v1.8.4).',
    );
  }
  return file.readAsStringSync().trim();
}

/// Resolves the libgit2 source directory.
///
/// Resolution order:
/// 1. [libgit2SrcEnvKey] environment variable
/// 2. Local `libgit2/` directory at the workspace root
/// 3. Download from GitHub (cached in [cacheBase])
Future<Directory> resolveSource({
  required Uri packageRoot,
  required Uri cacheBase,
}) async {
  final envPath = Platform.environment[libgit2SrcEnvKey];
  if (envPath != null && envPath.isNotEmpty) {
    final dir = Directory(envPath);
    if (dir.existsSync()) return dir;
  }

  final workspaceRoot = packageRoot.resolve('../../');
  final localCheckout = Directory.fromUri(workspaceRoot.resolve('libgit2/'));
  if (localCheckout.existsSync()) return localCheckout;

  return downloadSource(cacheBase, packageRoot: packageRoot);
}
