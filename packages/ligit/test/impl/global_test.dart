@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

void main() {
  group('Libgit2', () {
    tearDown(() {
      while (Libgit2.initCount > 0) {
        Libgit2.shutdown();
      }
    });

    group('initCount', () {
      test('starts at zero before any init', () {
        expect(Libgit2.initCount, 0);
      });
    });

    group('init', () {
      test('bumps initCount and returns the new count', () {
        expect(Libgit2.init(), 1);
        expect(Libgit2.initCount, 1);
        expect(Libgit2.init(), 2);
        expect(Libgit2.initCount, 2);
      });
    });

    group('shutdown', () {
      test('decrements initCount and returns the remaining count', () {
        Libgit2.init();
        Libgit2.init();

        expect(Libgit2.shutdown(), 1);
        expect(Libgit2.initCount, 1);
        expect(Libgit2.shutdown(), 0);
        expect(Libgit2.initCount, 0);
      });
    });

    group('shutdownAll', () {
      test('unwinds every outstanding init', () {
        Libgit2.init();
        Libgit2.init();
        Libgit2.init();

        Libgit2.shutdownAll();

        expect(Libgit2.initCount, 0);
      });

      test('is a no-op when initCount is zero', () {
        Libgit2.shutdownAll();

        expect(Libgit2.initCount, 0);
      });
    });

    group('runtime introspection', () {
      setUp(Libgit2.init);

      test('runtimeVersion exposes non-negative components matching the '
          'compile-time version', () {
        final v = Libgit2.runtimeVersion;

        expect(v.major, Libgit2.version.major);
        expect(v.minor, Libgit2.version.minor);
        expect(v.revision, Libgit2.version.revision);
      });

      test('prerelease is null or a non-empty label', () {
        final pr = Libgit2.prerelease;

        if (pr != null) expect(pr, isNotEmpty);
      });

      test('features includes every always-on feature', () {
        expect(
          Libgit2.features,
          containsAll([
            LibgitFeature.httpParser,
            LibgitFeature.regex,
            LibgitFeature.compression,
            LibgitFeature.sha1,
          ]),
        );
      });

      test('featureBackend returns a name for supported features and null '
          'for unsupported ones', () {
        final supported = Libgit2.featureBackend(LibgitFeature.sha1);
        expect(supported, isNotNull);
        expect(supported, isNotEmpty);

        final missing = LibgitFeature.values.firstWhere(
          (f) => !Libgit2.features.contains(f),
          orElse: () => LibgitFeature.sha1,
        );
        if (!Libgit2.features.contains(missing)) {
          expect(Libgit2.featureBackend(missing), isNull);
        }
      });
    });
  });
}
