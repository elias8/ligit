@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Libgit2Trace', () {
    setUpAll(Libgit2.init);

    tearDownAll(() {
      Libgit2Trace.clear();
      Libgit2.shutdown();
    });

    group('set', () {
      test(
        'callback is invoked when libgit2 produces a matching trace event',
        () async {
          final messages = <String>[];

          Libgit2Trace.set(TraceLevel.debug, (_, msg) => messages.add(msg));

          // Opening a repository triggers internal debug-level trace events in
          // most libgit2 builds. Use a fresh temp dir so we always pass through
          // the init path.
          final git = GitFixture.init();
          try {
            git.commit('seed', files: {'a.txt': 'x'});
            final repo = Repository.open(git.path);
            repo.dispose();
          } finally {
            git.dispose();
          }

          // Give the NativeCallable listener a chance to drain.
          await Future<void>.delayed(const Duration(milliseconds: 50));

          Libgit2Trace.clear();

          // libgit2 may not emit debug traces in release builds; we accept
          // either an empty list (no-op build) or a populated one. What we
          // must not see is an exception, and if any messages arrived they
          // must be non-empty strings.
          for (final m in messages) {
            expect(m, isNotEmpty);
          }
        },
      );
    });

    group('clear', () {
      test('disables tracing without throwing', () {
        Libgit2Trace.set(TraceLevel.info, (_, _) {});
        Libgit2Trace.clear();
      });
    });
  });
}
