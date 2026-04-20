import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';

import 'asset_hashes.dart';
import 'cmake_target.dart';
import 'libgit2_source.dart';

/// Returns the dynamic library file extension for [os].
String libraryExtension(OS os) => switch (os) {
  OS.macOS || OS.iOS => 'dylib',
  OS.windows => 'dll',
  _ => 'so',
};

/// Environment variable that overrides system-library discovery with an
/// explicit absolute path to a libgit2 dynamic library.
const libgit2LibEnvKey = 'LIBGIT2_LIB';

/// Well-known directories searched by [SystemLibrary] when no explicit path
/// is supplied.
const systemSearchDirectories = <String>[
  '/usr/local/lib',
  '/opt/homebrew/lib',
  '/usr/lib',
  '/usr/lib/x86_64-linux-gnu',
  '/usr/lib/aarch64-linux-gnu',
];

sealed class LibraryProvider {
  const LibraryProvider();

  /// Acquires the native library and writes it to [target] file.
  Future<void> provide(File target);

  /// Selects the provider based on user-defined hook options.
  ///
  /// Source values:
  /// - `"prebuilt"` (default): downloads a prebuilt binary from GitHub
  ///   Releases and verifies its SHA-256.
  /// - `"compile"`: builds the library from source using CMake. The source
  ///   may be supplied via the `LIBGIT2_SRC` environment variable,
  ///   otherwise it is downloaded based on the `download` user-define. On
  ///   Windows with vcpkg-installed dependencies, set the
  ///   `cmake_toolchain_file` user-define to vcpkg's toolchain file path.
  /// - `"system"`: uses an OS-installed libgit2. Looks at `LIBGIT2_LIB`
  ///   first, then a small set of well-known directories.
  static LibraryProvider resolve(BuildInput input) {
    final source = input.userDefines['source'];

    return switch (source) {
      'prebuilt' || null => DownloadPrebuilt(input),
      'compile' => CompileFromSource(
        input,
        sourcePath: Platform.environment[libgit2SrcEnvKey],
        cmakeToolchainFile:
            input.userDefines['cmake_toolchain_file'] as String?,
        downloadMethod: switch (input.userDefines['download']) {
          'git' => SourceLocation.git,
          'tarball' || null => SourceLocation.tarball,
          _ => throw ArgumentError(
            'Invalid download method: ${input.userDefines['download']}. '
            'Valid options are "git" or "tarball".',
          ),
        },
      ),
      'system' => SystemLibrary(
        input,
        explicitPath: Platform.environment[libgit2LibEnvKey],
      ),
      _ => throw ArgumentError(
        'Invalid source: $source. '
        'Valid options are "prebuilt", "compile", or "system".',
      ),
    };
  }

  /// Whether `cmake` is on PATH and runnable.
  static bool cmakeAvailable() {
    try {
      final result = Process.runSync('cmake', ['--version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }
}

/// Source download method when [LibraryProvider] is configured to compile.
enum SourceLocation {
  /// Download a tarball of the pinned tag from GitHub.
  tarball,

  /// `git clone` the pinned tag from GitHub.
  git,
}

final class CompileFromSource extends LibraryProvider {
  final BuildInput input;
  final String? sourcePath;
  final String? cmakeToolchainFile;
  final SourceLocation downloadMethod;

  const CompileFromSource(
    this.input, {
    this.sourcePath,
    this.cmakeToolchainFile,
    this.downloadMethod = SourceLocation.tarball,
  });

  @override
  Future<void> provide(File target) async {
    final sourceDir = await _resolveSource();
    await _compile(sourceDir, target);
  }

  Future<void> _compile(Directory sourceDir, File target) async {
    final os = input.config.code.targetOS;
    final hostOs = OS.current;
    if (os != hostOs) {
      throw UnsupportedError(
        'Cross-compiling libgit2 from source is not yet supported. '
        'Build for the host OS ($hostOs) only, or use the prebuilt provider.',
      );
    }

    if (!LibraryProvider.cmakeAvailable()) {
      throw StateError(
        'cmake is required to build libgit2 from source but was not found '
        'on PATH. Install cmake (https://cmake.org/download) or switch to '
        'the prebuilt provider.',
      );
    }

    final installDir = target.parent.parent;
    final buildDir = Directory.fromUri(
      input.outputDirectory.resolve('cmake-build/'),
    );
    if (buildDir.existsSync()) buildDir.deleteSync(recursive: true);
    buildDir.createSync(recursive: true);

    final cmakeArgs = <String>[
      '-S',
      sourceDir.path,
      '-B',
      buildDir.path,
      '-DCMAKE_BUILD_TYPE=Release',
      '-DBUILD_SHARED_LIBS=ON',
      '-DBUILD_TESTS=OFF',
      '-DBUILD_CLI=OFF',
      '-DUSE_HTTPS=ON',
      '-DUSE_SSH=libssh2',
      '-DCMAKE_INSTALL_PREFIX=${installDir.path}',
    ];

    if (cmakeToolchainFile != null && cmakeToolchainFile!.isNotEmpty) {
      cmakeArgs.add('-DCMAKE_TOOLCHAIN_FILE=$cmakeToolchainFile');
    }

    final configure = Process.runSync('cmake', cmakeArgs);
    if (configure.exitCode != 0) {
      throw Exception(
        'cmake configure failed (exit ${configure.exitCode}):\n'
        'stdout: ${configure.stdout}\n'
        'stderr: ${configure.stderr}\n\n'
        'libgit2 requires HTTPS and SSH dependencies. Install:\n'
        '  Linux:   sudo apt install libssl-dev libssh2-1-dev\n'
        '  macOS:   brew install libssh2\n'
        '  Windows: vcpkg install libssh2:x64-windows, then set the\n'
        '           cmake_toolchain_file user_define in pubspec.yaml to\n'
        '           <vcpkg>/scripts/buildsystems/vcpkg.cmake',
      );
    }

    final build = Process.runSync('cmake', [
      '--build',
      buildDir.path,
      '--target',
      'install',
      '--config',
      'Release',
    ]);
    if (build.exitCode != 0) {
      throw Exception(
        'cmake build failed (exit ${build.exitCode}):\n'
        'stdout: ${build.stdout}\n'
        'stderr: ${build.stderr}',
      );
    }

    final libFileName = os.dylibFileName('git2');
    final candidates = [
      File('${installDir.path}/lib/$libFileName'),
      File('${installDir.path}/bin/$libFileName'),
      File('${installDir.path}/lib64/$libFileName'),
    ];
    final found = candidates.firstWhere(
      (f) => f.existsSync(),
      orElse: () => throw StateError(
        'cmake reported success but $libFileName was not found under '
        '${installDir.path}',
      ),
    );
    if (found.path != target.path) {
      target.parent.createSync(recursive: true);
      found.renameSync(target.path);
    }
  }

  Future<Directory> _downloadTarball() => downloadSource(
    input.outputDirectoryShared,
    packageRoot: input.packageRoot,
  );

  Future<Directory> _gitClone() async {
    final tag = pinnedTag(input.packageRoot);
    final cacheDir = Directory.fromUri(
      input.outputDirectoryShared.resolve('libgit2-git-$tag/'),
    );

    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);

      final result = Process.runSync('git', [
        'clone',
        '--depth',
        '1',
        '--branch',
        tag,
        'https://github.com/libgit2/libgit2.git',
        '.',
      ], workingDirectory: cacheDir.path);

      if (result.exitCode != 0) {
        cacheDir.deleteSync(recursive: true);
        throw Exception('git clone failed: ${result.stderr}');
      }
    }

    return cacheDir;
  }

  Future<Directory> _resolveSource() async {
    if (sourcePath != null && sourcePath!.isNotEmpty) {
      final dir = Directory(sourcePath!);
      if (dir.existsSync()) return dir;
    }

    final workspaceRoot = input.packageRoot.resolve('../../');
    final local = Directory.fromUri(workspaceRoot.resolve('libgit2/'));
    if (local.existsSync()) return local;

    return switch (downloadMethod) {
      .tarball => _downloadTarball(),
      .git => _gitClone(),
    };
  }
}

final class DownloadPrebuilt extends LibraryProvider {
  static const _repoUrl = 'https://github.com/elias8/libgit2';
  static const _defaultBaseUrl = '$_repoUrl/releases/download';

  final String baseUrl;
  final BuildInput input;
  final Map<String, String> hashes;

  const DownloadPrebuilt(
    this.input, {
    this.baseUrl = _defaultBaseUrl,
    Map<String, String>? hashes,
  }) : hashes = hashes ?? assetHashes;

  @override
  Future<void> provide(File target) async {
    final os = input.config.code.targetOS;
    final targetTriple = input.targetTriple();
    if (targetTriple == null) {
      throw Exception(
        'Cannot determine target triple for $os. Prebuilt binaries may '
        'not be available for this platform.',
      );
    }

    final cb = input.outputDirectoryShared;
    final extension = libraryExtension(os);
    final fileName = 'libgit2-$targetTriple.$extension';
    final cacheDir = Directory.fromUri(cb.resolve('prebuilt-$releaseTag/'));
    final cachedFile = File('${cacheDir.path}/$fileName');

    if (cachedFile.existsSync() && !_validateHash(cachedFile, fileName)) {
      cachedFile.deleteSync();
    }

    if (!cachedFile.existsSync()) {
      await _download(fileName, cachedFile);
      if (!_validateHash(cachedFile, fileName)) {
        cachedFile.deleteSync();
        throw Exception(
          'SHA256 hash mismatch for downloaded $fileName. The file may be '
          'corrupted. Try again, or file an issue at '
          'https://github.com/elias8/libgit2/issues',
        );
      }
    }

    target.parent.createSync(recursive: true);
    cachedFile.copySync(target.path);
  }

  Future<void> _download(String fileName, File destination) async {
    final url = '$baseUrl/$releaseTag/$fileName';

    destination.parent.createSync(recursive: true);
    final tmp = File('${destination.path}.tmp');

    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download prebuilt library from $url '
          '(HTTP ${response.statusCode}).\n'
          'Options:\n'
          '  - Install cmake and rebuild from source\n'
          '  - Check https://github.com/elias8/libgit2/releases',
        );
      }
      final sink = tmp.openWrite();
      await response.pipe(sink);
    } on Exception {
      rethrow;
    } on Object {
      throw Exception(
        'Failed to download prebuilt library from $url. Please check your '
        'internet connection and try again.',
      );
    } finally {
      httpClient.close();
    }

    tmp.renameSync(destination.path);
  }

  bool _validateHash(File file, String hashKey) {
    final expectedHash = hashes[hashKey];
    if (expectedHash == null) {
      throw Exception(
        'No known hash for $hashKey. This target is not included in this '
        'release.\n'
        'See https://github.com/elias8/libgit2/releases/tag/$releaseTag',
      );
    }

    final bytes = file.readAsBytesSync();
    final digest = sha256.convert(bytes).toString();
    return digest == expectedHash;
  }
}

/// Uses an OS-installed libgit2 dynamic library.
///
/// This is intended for development and CI environments where libgit2 is
/// available via the system package manager (e.g. `brew install libgit2`,
/// `apt install libgit2-dev`). It is not appropriate for distribution.
final class SystemLibrary extends LibraryProvider {
  final BuildInput input;

  /// Optional explicit path to a dynamic library file. When provided, no
  /// directory search is performed.
  final String? explicitPath;

  /// Directories searched when [explicitPath] is null.
  final List<String> searchDirectories;

  const SystemLibrary(
    this.input, {
    this.explicitPath,
    this.searchDirectories = systemSearchDirectories,
  });

  @override
  Future<void> provide(File target) async {
    final source = _locate();
    if (source == null) {
      throw StateError(
        'Could not find a system libgit2 library. Set $libgit2LibEnvKey to '
        'an absolute path, or install libgit2 via your package manager '
        '(e.g. `brew install libgit2`, `apt install libgit2-dev`).',
      );
    }
    target.parent.createSync(recursive: true);
    source.copySync(target.path);
  }

  File? _locate() {
    if (explicitPath != null && explicitPath!.isNotEmpty) {
      final f = File(explicitPath!);
      return f.existsSync() ? f : null;
    }

    final os = input.config.code.targetOS;
    final fileName = os.dylibFileName('git2');
    for (final dir in searchDirectories) {
      final f = File('$dir/$fileName');
      if (f.existsSync()) return f;
    }
    return null;
  }
}
