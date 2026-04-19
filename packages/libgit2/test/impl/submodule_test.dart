@Tags(['ffi'])
library;

import 'dart:io';

import 'package:libgit2/libgit2.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  late GitFixture subFixture;
  late GitFixture superFixture;

  setUpAll(Libgit2.init);

  tearDownAll(Libgit2.shutdown);

  setUp(() {
    subFixture = GitFixture.init();
    subFixture.commit('initial', files: {'a.txt': 'hello\n'});

    superFixture = GitFixture.init();
    superFixture.commit('initial', files: {'root.txt': 'root\n'});
    _addSubmodule(superFixture.path, subFixture.path, 'vendor/lib');
  });

  tearDown(() {
    subFixture.dispose();
    superFixture.dispose();
  });

  group('Submodule', () {
    group('lookup', () {
      test('returns the submodule with its name, path, and url', () {
        final repo = Repository.open(superFixture.path);
        addTearDown(repo.dispose);

        final sm = Submodule.lookup(repo, 'vendor/lib');
        addTearDown(sm.dispose);

        expect(sm.name, 'vendor/lib');
        expect(sm.path, 'vendor/lib');
        expect(sm.url, subFixture.fileUrl);
      });

      test('throws NotFoundException for a missing submodule', () {
        final repo = Repository.open(superFixture.path);
        addTearDown(repo.dispose);

        expect(
          () => Submodule.lookup(repo, 'nope'),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('headId / indexId / workdirId', () {
      test('reports the submodule OID recorded in HEAD and the index', () {
        final repo = Repository.open(superFixture.path);
        addTearDown(repo.dispose);
        final sm = Submodule.lookup(repo, 'vendor/lib');
        addTearDown(sm.dispose);

        final sha = subFixture.revParse('HEAD');
        expect(sm.indexId?.sha, sha);
        expect(sm.headId?.sha, sha);
      });
    });

    group('branch', () {
      test('is null when no branch is configured', () {
        final repo = Repository.open(superFixture.path);
        addTearDown(repo.dispose);
        final sm = Submodule.lookup(repo, 'vendor/lib');
        addTearDown(sm.dispose);

        expect(sm.branch, isNull);
      });

      test('returns the configured branch after setSubmoduleBranch', () {
        final repo = Repository.open(superFixture.path);
        addTearDown(repo.dispose);

        repo.setSubmoduleBranch('vendor/lib', 'main');

        final sm = Submodule.lookup(repo, 'vendor/lib');
        addTearDown(sm.dispose);
        sm.reload(force: true);

        expect(sm.branch, 'main');
      });
    });

    group('dup', () {
      test('produces an independent copy with the same name and url', () {
        final repo = Repository.open(superFixture.path);
        addTearDown(repo.dispose);
        final sm = Submodule.lookup(repo, 'vendor/lib');
        addTearDown(sm.dispose);

        final copy = Submodule.copy(sm);
        addTearDown(copy.dispose);

        expect(copy.name, sm.name);
        expect(copy.url, sm.url);
      });
    });

    group('open', () {
      test('opens the sub-repository checked out in the working tree', () {
        final repo = Repository.open(superFixture.path);
        addTearDown(repo.dispose);
        final sm = Submodule.lookup(repo, 'vendor/lib');
        addTearDown(sm.dispose);

        final subRepo = sm.open();
        addTearDown(subRepo.dispose);

        expect(subRepo.path, contains('.git'));
      });
    });

    group('update', () {
      test('succeeds on an already-checked-out submodule', () {
        final repo = Repository.open(superFixture.path);
        addTearDown(repo.dispose);
        final sm = Submodule.lookup(repo, 'vendor/lib');
        addTearDown(sm.dispose);

        sm.update();

        expect(
          File('${superFixture.path}/vendor/lib/a.txt').existsSync(),
          isTrue,
        );
      });
    });
  });

  group('SubmoduleUpdateOptions', () {
    group('==', () {
      test('instances with equal fields compare equal', () {
        const a = SubmoduleUpdateOptions(checkoutPaths: ['src']);
        const b = SubmoduleUpdateOptions(checkoutPaths: ['src']);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('instances that differ in allowFetch are not equal', () {
        const a = SubmoduleUpdateOptions();
        const b = SubmoduleUpdateOptions(allowFetch: false);

        expect(a, isNot(equals(b)));
      });

      test('instances that differ in checkoutStrategy are not equal', () {
        const a = SubmoduleUpdateOptions(
          checkoutStrategy: {CheckoutStrategy.force},
        );
        const b = SubmoduleUpdateOptions(
          checkoutStrategy: {CheckoutStrategy.none},
        );

        expect(a, isNot(equals(b)));
      });
    });
  });

  group('RepositorySubmodule', () {
    group('submoduleNames', () {
      test('enumerates every tracked submodule name', () {
        final repo = Repository.open(superFixture.path);
        addTearDown(repo.dispose);

        expect(repo.submoduleNames(), ['vendor/lib']);
      });
    });

    group('statusOfSubmodule', () {
      test('reports IN_HEAD / IN_INDEX / IN_CONFIG / IN_WD for a clean '
          'submodule', () {
        final repo = Repository.open(superFixture.path);
        addTearDown(repo.dispose);

        final status = repo.statusOfSubmodule('vendor/lib');

        expect(
          status,
          containsAll(<SubmoduleStatus>[
            SubmoduleStatus.inHead,
            SubmoduleStatus.inIndex,
            SubmoduleStatus.inConfig,
            SubmoduleStatus.inWd,
          ]),
        );
      });
    });

    group('setSubmoduleUrl', () {
      test('persists a new URL and reload picks it up', () {
        final repo = Repository.open(superFixture.path);
        addTearDown(repo.dispose);

        repo.setSubmoduleUrl('vendor/lib', 'https://example.com/x.git');

        final sm = Submodule.lookup(repo, 'vendor/lib');
        addTearDown(sm.dispose);
        sm.reload(force: true);

        expect(sm.url, 'https://example.com/x.git');
      });
    });
  });
}

void _addSubmodule(String superDir, String subDir, String path) {
  final r = Process.runSync('git', [
    '-c',
    'protocol.file.allow=always',
    '-C',
    superDir,
    'submodule',
    'add',
    fileUrl(subDir),
    path,
  ]);
  if (r.exitCode != 0) {
    throw StateError('git submodule add failed: ${r.stderr}');
  }
  Process.runSync('git', ['-C', superDir, 'commit', '-m', 'add submodule']);
}
