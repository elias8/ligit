@Tags(['ffi'])
library;

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:ligit/src/hook/library_provider.dart';
import 'package:test/test.dart';

import 'helpers/build_input_fixture.dart';

void main() {
  group('libgit2LibEnvKey', () {
    test('constant value is LIBGIT2_LIB', () {
      expect(libgit2LibEnvKey, 'LIBGIT2_LIB');
    });
  });

  group('cmakeAvailable', () {
    test('returns a bool without throwing', () {
      expect(LibraryProvider.cmakeAvailable(), isA<bool>());
    });
  });

  group('LibraryProvider.resolve', () {
    BuildInput inputWith(Map<String, Object?> userDefines) =>
        createTestBuildInput(userDefines: userDefines);

    test('defaults to DownloadPrebuilt when no source user-define is set', () {
      expect(
        LibraryProvider.resolve(createTestBuildInput()),
        isA<DownloadPrebuilt>(),
      );
    });

    test('resolves source=prebuilt to DownloadPrebuilt', () {
      expect(
        LibraryProvider.resolve(inputWith({'source': 'prebuilt'})),
        isA<DownloadPrebuilt>(),
      );
    });

    test('resolves source=compile to CompileFromSource', () {
      expect(
        LibraryProvider.resolve(inputWith({'source': 'compile'})),
        isA<CompileFromSource>(),
      );
    });

    test('resolves source=system to SystemLibrary', () {
      expect(
        LibraryProvider.resolve(inputWith({'source': 'system'})),
        isA<SystemLibrary>(),
      );
    });

    test('throws ArgumentError for unknown source value', () {
      expect(
        () => LibraryProvider.resolve(inputWith({'source': 'magic'})),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for unknown download method', () {
      expect(
        () => LibraryProvider.resolve(
          inputWith({'source': 'compile', 'download': 'rsync'}),
        ),
        throwsArgumentError,
      );
    });

    test('resolves source=compile with download=git to CompileFromSource', () {
      final provider =
          LibraryProvider.resolve(
                inputWith({'source': 'compile', 'download': 'git'}),
              )
              as CompileFromSource;
      expect(provider.downloadMethod, SourceLocation.git);
    });

    test(
      'resolves source=compile with download=tarball to CompileFromSource',
      () {
        final provider =
            LibraryProvider.resolve(
                  inputWith({'source': 'compile', 'download': 'tarball'}),
                )
                as CompileFromSource;
        expect(provider.downloadMethod, SourceLocation.tarball);
      },
    );
  });

  group('DownloadPrebuilt', () {
    group('fields', () {
      test('stores input and uses default baseUrl', () {
        final input = createTestBuildInput();
        final provider = DownloadPrebuilt(input);
        expect(provider.input, same(input));
        expect(provider.baseUrl, contains('github.com'));
      });

      test('accepts a custom baseUrl', () {
        const customUrl = 'https://example.com/releases';
        final provider = DownloadPrebuilt(
          createTestBuildInput(),
          baseUrl: customUrl,
        );
        expect(provider.baseUrl, customUrl);
      });

      test('uses supplied hashes map', () {
        const fakeHashes = {'libgit2-aarch64-macos.dylib': 'abc123'};
        final provider = DownloadPrebuilt(
          createTestBuildInput(),
          hashes: fakeHashes,
        );
        expect(provider.hashes, fakeHashes);
      });

      test('defaults to assetHashes when hashes is omitted', () {
        final provider = DownloadPrebuilt(createTestBuildInput());
        expect(provider.hashes, isA<Map<String, String>>());
      });
    });

    group('provide', () {
      test('throws when the target-triple has no entry in hashes', () async {
        final tmp = Directory.systemTemp.createTempSync('libgit2_dp_');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final cacheDir = Directory('${tmp.path}/shared/prebuilt-libgit2-v0.0.1')
          ..createSync(recursive: true);
        final fakeLib = File('${cacheDir.path}/libgit2-aarch64-macos.dylib')
          ..writeAsBytesSync([1, 2, 3]);
        addTearDown(fakeLib.deleteSync);

        final input = createTestBuildInput();
        final provider = DownloadPrebuilt(
          input,
          hashes: const {'libgit2-aarch64-macos.dylib': 'wrong-hash'},
        );

        await expectLater(
          provider.provide(File('${tmp.path}/out/libgit2.dylib')),
          throwsA(isA<Exception>()),
        );
      });
    });
  });

  group('CompileFromSource', () {
    group('fields', () {
      test('stores input with default downloadMethod=tarball', () {
        final input = createTestBuildInput();
        final provider = CompileFromSource(input);
        expect(provider.input, same(input));
        expect(provider.sourcePath, isNull);
        expect(provider.downloadMethod, SourceLocation.tarball);
      });

      test('stores explicit sourcePath and downloadMethod', () {
        final input = createTestBuildInput();
        final provider = CompileFromSource(
          input,
          sourcePath: '/tmp/libgit2',
          downloadMethod: SourceLocation.git,
        );
        expect(provider.sourcePath, '/tmp/libgit2');
        expect(provider.downloadMethod, SourceLocation.git);
      });
    });

    group('provide', () {
      test('throws UnsupportedError when cross-compiling', () async {
        final tmp = Directory.systemTemp.createTempSync('libgit2_cfs_');
        addTearDown(() => tmp.deleteSync(recursive: true));

        // Supply an existing source dir so _resolveSource succeeds and the
        // cross-compile guard in _compile is reached. Pick any OS that is
        // not the host so the guard fires regardless of which runner this
        // test executes on.
        final fakeSource = Directory('${tmp.path}/src')..createSync();
        final crossOs = OS.current == OS.iOS ? OS.android : OS.iOS;
        final provider = CompileFromSource(
          createTestBuildInput(os: crossOs),
          sourcePath: fakeSource.path,
        );
        await expectLater(
          provider.provide(File('${tmp.path}/out/libgit2.so')),
          throwsUnsupportedError,
        );
      });
    });
  });

  group('SystemLibrary', () {
    group('provide', () {
      test('copies library to target path when explicitPath exists', () async {
        final tmp = Directory.systemTemp.createTempSync('libgit2_sys_');
        addTearDown(() => tmp.deleteSync(recursive: true));
        final lib = File('${tmp.path}/libgit2.dylib')..writeAsBytesSync([1, 2]);

        final provider = SystemLibrary(
          createTestBuildInput(),
          explicitPath: lib.path,
        );
        final dest = File('${tmp.path}/out/libgit2.dylib');
        await provider.provide(dest);

        expect(dest.existsSync(), isTrue);
        expect(dest.readAsBytesSync(), [1, 2]);
      });

      test('throws StateError when no library can be located', () async {
        final tmp = Directory.systemTemp.createTempSync('libgit2_sys_');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final provider = SystemLibrary(
          createTestBuildInput(),
          searchDirectories: const ['/definitely/does/not/exist'],
        );
        await expectLater(
          provider.provide(File('${tmp.path}/out/libgit2.dylib')),
          throwsStateError,
        );
      });

      test('error message references libgit2LibEnvKey', () async {
        final tmp = Directory.systemTemp.createTempSync('libgit2_sys2_');
        addTearDown(() => tmp.deleteSync(recursive: true));

        final provider = SystemLibrary(
          createTestBuildInput(),
          searchDirectories: const ['/definitely/does/not/exist'],
        );
        await expectLater(
          provider.provide(File('${tmp.path}/out/libgit2.dylib')),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains(libgit2LibEnvKey),
            ),
          ),
        );
      });
    });
  });

  group('libraryExtension', () {
    test('maps OS to native library file extension', () {
      expect(libraryExtension(OS.macOS), 'dylib');
      expect(libraryExtension(OS.iOS), 'dylib');
      expect(libraryExtension(OS.windows), 'dll');
      expect(libraryExtension(OS.linux), 'so');
      expect(libraryExtension(OS.android), 'so');
    });
  });
}
