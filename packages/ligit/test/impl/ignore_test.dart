@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('RepositoryIgnore', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit(
        'initial',
        files: {'.gitignore': 'build/\n', 'a.txt': 'hello\n'},
      );
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('isIgnored', () {
      test('honors patterns from .gitignore', () {
        expect(repo.isIgnored('build/output.log'), isTrue);
        expect(repo.isIgnored('src/main.dart'), isFalse);
      });
    });

    group('addIgnoreRule', () {
      test('applies an in-memory rule on top of .gitignore', () {
        expect(repo.isIgnored('scratch.txt'), isFalse);
        repo.addIgnoreRule('scratch.txt\n');
        expect(repo.isIgnored('scratch.txt'), isTrue);
      });
    });

    group('clearInternalIgnoreRules', () {
      test('reverts rules added via addIgnoreRule', () {
        repo.addIgnoreRule('temp.txt\n');
        expect(repo.isIgnored('temp.txt'), isTrue);

        repo.clearInternalIgnoreRules();
        expect(repo.isIgnored('temp.txt'), isFalse);
      });
    });
  });
}
