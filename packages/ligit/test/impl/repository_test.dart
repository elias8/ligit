@Tags(['ffi'])
library;

import 'dart:io';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Repository', () {
    late String tempDir;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() => tempDir = createTempDir());

    tearDown(() => deleteTempDir(tempDir));

    group('init', () {
      test('creates a non-bare repository with a .git directory', () {
        final repo = Repository.init(tempDir);
        addTearDown(repo.dispose);

        expect(repo.isBare, isFalse);
        expect(repo.isEmpty, isTrue);
        expect(Directory('$tempDir/.git').existsSync(), isTrue);
      });

      test('creates a bare repository', () {
        final repo = Repository.init(tempDir, bare: true);
        addTearDown(repo.dispose);

        expect(repo.isBare, isTrue);
      });
    });

    group('open', () {
      test('opens an existing repository', () {
        Repository.init(tempDir).dispose();

        final repo = Repository.open(tempDir);
        addTearDown(repo.dispose);

        expect(repo.isBare, isFalse);
      });

      test('throws on a non-existent path', () {
        expect(
          () => Repository.open('$tempDir/nonexistent'),
          throwsA(isA<Libgit2Exception>()),
        );
      });
    });

    group('openBare', () {
      test('opens a bare repository', () {
        Repository.init(tempDir, bare: true).dispose();

        final repo = Repository.openBare(tempDir);
        addTearDown(repo.dispose);

        expect(repo.isBare, isTrue);
      });
    });

    group('clone', () {
      late GitFixture upstream;
      late String cloneDir;

      setUp(() {
        upstream = GitFixture.init();
        upstream.commit('initial', files: {'a.txt': 'hello\n'});
        cloneDir = '$tempDir/clone';
      });

      tearDown(() => upstream.dispose());

      test('copies the upstream repository into the target directory', () {
        final cloned = Repository.clone(
          url: upstream.path,
          localPath: cloneDir,
        );
        addTearDown(cloned.dispose);

        expect(File('$cloneDir/a.txt').existsSync(), isTrue);
        final head = Reference.lookup(cloned, 'HEAD');
        addTearDown(head.dispose);
        expect(head.symbolicTarget, 'refs/heads/main');
      });

      test('creates a bare repository when bare is true', () {
        final cloned = Repository.clone(
          url: upstream.path,
          localPath: cloneDir,
          bare: true,
          checkoutStrategy: const {},
        );
        addTearDown(cloned.dispose);

        expect(cloned.isBare, isTrue);
      });
    });

    group('discover', () {
      test('finds a repository from a subdirectory', () {
        Repository.init(tempDir).dispose();
        final sub = Directory('$tempDir/a/b/c')..createSync(recursive: true);

        final found = Repository.discover(sub.path);

        expect(found, isNotNull);
        expect(found, contains('.git'));
      });

      test('returns null when no repository exists', () {
        expect(Repository.discover(tempDir), isNull);
      });
    });

    group('path', () {
      test('points at the .git directory', () {
        final repo = Repository.init(tempDir);
        addTearDown(repo.dispose);

        expect(repo.path, contains('.git'));
      });
    });

    group('workDir', () {
      test('returns the working directory for a non-bare repo', () {
        final repo = Repository.init(tempDir);
        addTearDown(repo.dispose);

        expect(repo.workDir, isNotNull);
      });

      test('returns null for a bare repository', () {
        final repo = Repository.init(tempDir, bare: true);
        addTearDown(repo.dispose);

        expect(repo.workDir, isNull);
      });
    });

    group('commonDir', () {
      test('returns a non-empty path', () {
        final repo = Repository.init(tempDir);
        addTearDown(repo.dispose);

        expect(repo.commonDir, isNotEmpty);
      });
    });

    group('isEmpty', () {
      test('is true for a freshly initialized repository', () {
        final repo = Repository.init(tempDir);
        addTearDown(repo.dispose);

        expect(repo.isEmpty, isTrue);
      });
    });

    group('isHeadUnborn', () {
      test('is true for a fresh repository with no commits', () {
        final repo = Repository.init(tempDir);
        addTearDown(repo.dispose);

        expect(repo.isHeadUnborn, isTrue);
      });
    });

    group('state', () {
      test('is none for a clean repository', () {
        final repo = Repository.init(tempDir);
        addTearDown(repo.dispose);

        expect(repo.state, RepositoryState.none);
      });
    });

    group('namespace', () {
      test('is null by default and round-trips through setNamespace', () {
        final repo = Repository.init(tempDir);
        addTearDown(repo.dispose);

        expect(repo.namespace, isNull);
        repo.setNamespace('test');
        expect(repo.namespace, 'test');
      });
    });

    group('ident', () {
      test('round-trips through setIdent', () {
        final repo = Repository.init(tempDir);
        addTearDown(repo.dispose);

        repo.setIdent(name: 'Test', email: 'test@example.com');

        expect(repo.ident.name, 'Test');
        expect(repo.ident.email, 'test@example.com');
      });
    });

    group('message', () {
      test('returns null when no prepared message exists', () {
        final repo = Repository.init(tempDir);
        addTearDown(repo.dispose);

        expect(repo.message, isNull);
      });
    });

    group('==', () {
      test('two opens of the same repo compare equal', () {
        Repository.init(tempDir).dispose();

        final a = Repository.open(tempDir);
        addTearDown(a.dispose);
        final b = Repository.open(tempDir);
        addTearDown(b.dispose);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('different repositories compare unequal', () {
        final dirA = Directory('$tempDir/a')..createSync();
        final dirB = Directory('$tempDir/b')..createSync();

        final a = Repository.init(dirA.path);
        addTearDown(a.dispose);
        final b = Repository.init(dirB.path);
        addTearDown(b.dispose);

        expect(a, isNot(equals(b)));
      });
    });

    group('odb', () {
      test('returns an object database with at least one backend', () {
        final repo = Repository.init(tempDir);
        addTearDown(repo.dispose);

        final odb = repo.odb();
        addTearDown(odb.dispose);

        expect(odb.backendCount, greaterThan(0));
      });
    });

    group('refDb', () {
      test('returns a refdb rooted at the repository', () {
        final repo = Repository.init(tempDir);
        addTearDown(repo.dispose);

        final refdb = repo.refDb();
        addTearDown(refdb.dispose);
      });
    });

    group('index', () {
      test('returns the repository index', () {
        final repo = Repository.init(tempDir);
        addTearDown(repo.dispose);

        final index = repo.index();
        addTearDown(index.dispose);

        expect(index.entryCount, 0);
      });
    });

    group('oidType', () {
      test('is sha1 for default init', () {
        final repo = Repository.init(tempDir);
        addTearDown(repo.dispose);

        expect(repo.oidType, ObjectIdType.sha1);
      });
    });

    group('forEachFetchHead', () {
      test('visits every line of FETCH_HEAD', () {
        final git = GitFixture.init();
        addTearDown(git.dispose);
        git.commit('initial', files: {'a.txt': 'hello\n'});
        final head = git.revParse('HEAD');
        File('${git.path}/.git/FETCH_HEAD').writeAsStringSync(
          "$head\t\tbranch 'main' of https://example.com/r\n",
        );

        final repo = Repository.open(git.path);
        addTearDown(repo.dispose);

        final seen = <String>[];
        repo.forEachFetchHead(({
          required refName,
          required remoteUrl,
          required oid,
          required isMerge,
        }) {
          seen.add(remoteUrl);
          return 0;
        });

        expect(seen, ['https://example.com/r']);
      });
    });

    group('forEachMergeHead', () {
      test('visits every recorded MERGE_HEAD entry', () {
        final git = GitFixture.init();
        addTearDown(git.dispose);
        git.commit('initial', files: {'a.txt': 'hello\n'});
        final head = git.revParse('HEAD');
        File('${git.path}/.git/MERGE_HEAD').writeAsStringSync('$head\n');

        final repo = Repository.open(git.path);
        addTearDown(repo.dispose);

        final ids = <Oid>[];
        repo.forEachMergeHead((oid) {
          ids.add(oid);
          return 0;
        });

        expect(ids.single, Oid.fromString(head));
      });
    });
  });
}
