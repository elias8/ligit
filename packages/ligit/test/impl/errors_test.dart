@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Libgit2LastError', () {
    late GitFixture git;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() => git = GitFixture.init());

    tearDown(() => git.dispose());

    test('read exposes message and category after a failed call', () {
      expect(
        () => Repository.open('${git.path}/not-a-repo'),
        throwsA(isA<NotFoundException>()),
      );

      final err = Libgit2LastError.read();
      expect(err, isNotNull);
      expect(err!.message, isNotEmpty);
      expect(err.category, isIn([ErrorCategory.repository, ErrorCategory.os]));
    });

    test('two reads of the same failure compare equal', () {
      expect(
        () => Repository.open('${git.path}/not-a-repo'),
        throwsA(isA<NotFoundException>()),
      );

      final a = Libgit2LastError.read()!;
      final b = Libgit2LastError.read()!;

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), '${a.category}: ${a.message}');
    });
  });

  group('Libgit2Exception', () {
    const cases = <(Libgit2Exception, Libgit2Error)>[
      (NotFoundException(), Libgit2Error.enotfound),
      (ExistsException(), Libgit2Error.eexists),
      (AmbiguousException(), Libgit2Error.eambiguous),
      (InvalidValueException(), Libgit2Error.einvalid),
      (OutOfMemoryException(), Libgit2Error.error),
      (BareRepoException(), Libgit2Error.ebarerepo),
      (UnbornBranchException(), Libgit2Error.eunbornbranch),
      (ConflictException(), Libgit2Error.econflict),
      (UserException(), Libgit2Error.euser),
    ];

    for (final (exception, expectedCode) in cases) {
      test(
        '${exception.runtimeType} exposes code, non-empty message, and klass',
        () {
          expect(exception.code, expectedCode);
          expect(exception.message, isNotEmpty);
          expect(exception.klass, isA<ErrorCategory>());
          expect(exception.toString(), exception.message);
        },
      );
    }
  });
}
