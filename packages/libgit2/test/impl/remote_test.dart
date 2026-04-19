@Tags(['ffi'])
library;

import 'dart:io';

import 'package:libgit2/libgit2.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Remote', () {
    late GitFixture git;
    late GitFixture upstream;
    late Repository repo;

    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    setUp(() {
      upstream = GitFixture.init();
      upstream.commit('initial', files: {'a.txt': 'hello\n'});

      git = GitFixture.init();
      git.commit('initial', files: {'a.txt': 'hello\n'});

      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
      upstream.dispose();
    });

    group('create', () {
      test('registers a named remote with the default refspec', () {
        final remote = Remote.create(
          repo: repo,
          name: 'origin',
          url: upstream.fileUrl,
        );
        addTearDown(remote.dispose);

        expect(remote.name, 'origin');
        expect(remote.url, upstream.fileUrl);
        expect(remote.fetchRefspecs, ['+refs/heads/*:refs/remotes/origin/*']);
      });
    });

    group('lookup', () {
      test('finds a configured remote by name', () {
        Remote.create(
          repo: repo,
          name: 'upstream',
          url: upstream.fileUrl,
        ).dispose();

        final remote = Remote.lookup(repo, 'upstream');
        addTearDown(remote.dispose);

        expect(remote.name, 'upstream');
      });

      test('throws NotFoundException for a missing remote', () {
        expect(
          () => Remote.lookup(repo, 'nope'),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('fetch', () {
      test('downloads the upstream tip into a remote-tracking ref', () {
        final remote = Remote.create(
          repo: repo,
          name: 'origin',
          url: upstream.fileUrl,
        );
        addTearDown(remote.dispose);

        remote.fetch();

        final ref = Reference.lookup(repo, 'refs/remotes/origin/main');
        addTearDown(ref.dispose);
        expect(ref.target!.sha, upstream.revParse('HEAD'));
      });

      test('accepts a RemoteCallbacks without firing cert-check for '
          'file:// remotes', () {
        final remote = Remote.create(
          repo: repo,
          name: 'origin',
          url: upstream.fileUrl,
        );
        addTearDown(remote.dispose);

        var invoked = 0;
        remote.fetch(
          options: FetchOptions(
            callbacks: RemoteCallbacks(
              certificateCheck: (cert, valid, host) {
                invoked++;
                return 0;
              },
            ),
          ),
        );

        expect(invoked, 0);
      });

      test('accepts builtinUserpass credentials without a Dart trampoline', () {
        final remote = Remote.create(
          repo: repo,
          name: 'origin',
          url: upstream.fileUrl,
        );
        addTearDown(remote.dispose);

        remote.fetch(
          options: const FetchOptions(
            callbacks: RemoteCallbacks(
              builtinUserpass: (username: 'git', password: 'hunter2'),
            ),
          ),
        );

        final ref = Reference.lookup(repo, 'refs/remotes/origin/main');
        addTearDown(ref.dispose);
        expect(ref.target!.sha, upstream.revParse('HEAD'));
      });

      test(
        'fires updateRefs for each remote-tracking ref the fetch touches',
        () {
          final remote = Remote.create(
            repo: repo,
            name: 'origin',
            url: upstream.fileUrl,
          );
          addTearDown(remote.dispose);

          final updates = <String>[];
          remote.fetch(
            options: FetchOptions(
              callbacks: RemoteCallbacks(
                updateRefs: (refname, oldId, newId) {
                  updates.add(refname);
                  return 0;
                },
              ),
            ),
          );

          expect(updates, contains('refs/remotes/origin/main'));
        },
      );
    });

    group('refspecCount', () {
      test('returns the number of configured refspecs', () {
        final remote = Remote.create(
          repo: repo,
          name: 'origin',
          url: upstream.fileUrl,
        );
        addTearDown(remote.dispose);

        // Default fetch creates one refspec.
        expect(remote.refspecCount, 1);
      });
    });

    group('stop', () {
      test('can be called after connect without crashing', () {
        final remote = Remote.createAnonymous(repo, upstream.fileUrl);
        addTearDown(remote.dispose);

        remote.connect(Direction.fetch);
        remote.stop();
        remote.disconnect();
      });
    });

    group('push', () {
      test('sends local commits to a bare remote', () {
        final bareDir = createTempDir();
        addTearDown(() => deleteTempDir(bareDir));
        _initBare(bareDir, git.path);

        final remote = Remote.create(
          repo: repo,
          name: 'bare',
          url: fileUrl(bareDir),
        );
        addTearDown(remote.dispose);

        final extraId = git.commit('extra', files: {'b.txt': 'new\n'});
        remote.push(refspecs: ['refs/heads/main:refs/heads/main']);

        final result = Process.runSync('git', [
          '-C',
          bareDir,
          'rev-parse',
          'main',
        ]);
        expect((result.stdout as String).trim(), extraId.sha);
      });
    });

    group('upload', () {
      test('sends packfile without updating remote-tracking refs', () {
        final bareDir = createTempDir();
        addTearDown(() => deleteTempDir(bareDir));
        _initBare(bareDir, git.path);

        final remote = Remote.create(
          repo: repo,
          name: 'bare',
          url: fileUrl(bareDir),
        );
        addTearDown(remote.dispose);

        git.commit('extra', files: {'b.txt': 'new\n'});

        // upload should not throw for a file:// transport.
        expect(
          () => remote.upload(refspecs: ['refs/heads/main:refs/heads/main']),
          returnsNormally,
        );
      });
    });

    group('download', () {
      test('fetches objects without updating refs', () {
        final remote = Remote.create(
          repo: repo,
          name: 'origin',
          url: upstream.fileUrl,
        );
        addTearDown(remote.dispose);

        remote.connect(Direction.fetch);
        addTearDown(remote.disconnect);

        expect(remote.download, returnsNormally);
      });
    });

    group('updateTips', () {
      test('installs remote-tracking refs after a download', () {
        final remote = Remote.create(
          repo: repo,
          name: 'origin',
          url: upstream.fileUrl,
        );
        addTearDown(remote.dispose);

        remote.connect(Direction.fetch);
        remote.download();
        remote.updateTips();
        remote.disconnect();

        final ref = Reference.lookup(repo, 'refs/remotes/origin/main');
        addTearDown(ref.dispose);
        expect(ref.target!.sha, upstream.revParse('HEAD'));
      });
    });

    group('prune', () {
      test('removes a remote-tracking ref that is no longer on the remote', () {
        // Fetch to create the remote-tracking ref.
        final remote = Remote.create(
          repo: repo,
          name: 'origin',
          url: upstream.fileUrl,
        );
        addTearDown(remote.dispose);
        remote.fetch();

        // Create and fetch a feature branch from the upstream.
        upstream.git(['checkout', '-b', 'feature']);
        upstream.commit('feat', files: {'f.txt': 'f\n'});
        remote.fetch();
        upstream.git(['checkout', 'main']);

        // Delete the branch on the upstream, then prune.
        upstream.git(['branch', '-D', 'feature']);
        remote.fetch(options: const FetchOptions(prune: FetchPrune.prune));

        expect(
          () => Reference.lookup(repo, 'refs/remotes/origin/feature'),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('stats', () {
      test('returns non-null transfer stats after a fetch', () {
        final remote = Remote.create(
          repo: repo,
          name: 'origin',
          url: upstream.fileUrl,
        );
        addTearDown(remote.dispose);

        // Add a commit to upstream that the local repo does not have,
        // so there are objects to actually transfer.
        upstream.commit('extra', files: {'x.txt': 'new\n'});

        remote.fetch();

        final s = remote.stats;
        expect(s, isNotNull);
        expect(s!.totalObjects, greaterThan(0));
        expect(s.receivedBytes, greaterThanOrEqualTo(0));
      });
    });

    group('nameIsValid', () {
      test('accepts well-formed names and rejects invalid ones', () {
        expect(Remote.nameIsValid('origin'), isTrue);
        expect(Remote.nameIsValid(''), isFalse);
      });
    });

    group('createWithOpts', () {
      test('persists a named remote with the given URL', () {
        final remote = Remote.createWithOpts(
          'https://example.com/repo.git',
          repo: repo,
          name: 'example',
        );
        addTearDown(remote.dispose);

        expect(repo.remoteNames(), contains('example'));
        expect(remote.url, 'https://example.com/repo.git');
      });
    });

    group('dup', () {
      test('returns an independent handle to the same remote', () {
        final remote = Remote.createWithOpts(
          'https://example.com/repo.git',
          repo: repo,
          name: 'example',
        );
        addTearDown(remote.dispose);

        final copy = remote.dup();
        addTearDown(copy.dispose);

        expect(copy.url, 'https://example.com/repo.git');
        expect(copy.name, 'example');
      });
    });

    group('setInstanceUrl / setInstancePushUrl', () {
      test('override the in-memory URLs without touching config', () {
        Remote.create(
          repo: repo,
          name: 'alpha',
          url: 'https://orig.example/repo.git',
        ).dispose();

        final remote = Remote.lookup(repo, 'alpha');
        addTearDown(remote.dispose);
        remote.setInstanceUrl('https://override.example/repo.git');
        remote.setInstancePushUrl('https://push.example/repo.git');

        expect(remote.url, 'https://override.example/repo.git');
        expect(remote.pushUrl, 'https://push.example/repo.git');

        final persisted = Remote.lookup(repo, 'alpha');
        addTearDown(persisted.dispose);
        expect(persisted.url, 'https://orig.example/repo.git');
      });
    });

    group('ownerPath', () {
      test('returns the backing repository path for a persisted remote', () {
        Remote.create(
          repo: repo,
          name: 'back',
          url: 'https://example.com/repo.git',
        ).dispose();
        final remote = Remote.lookup(repo, 'back');
        addTearDown(remote.dispose);

        expect(remote.ownerPath, startsWith(repo.path));
      });
    });

    group('connect / ls', () {
      test('lists refs advertised by the upstream', () {
        final remote = Remote.createAnonymous(repo, upstream.fileUrl);
        addTearDown(remote.dispose);

        remote.connect(Direction.fetch);
        addTearDown(remote.disconnect);

        final heads = remote.ls();

        expect(heads, isNotEmpty);
        expect(heads.map((h) => h.name), contains('refs/heads/main'));
      });
    });
  });

  group('RepositoryRemote', () {
    late GitFixture git;
    late GitFixture upstream;
    late Repository repo;

    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    setUp(() {
      upstream = GitFixture.init();
      upstream.commit('initial', files: {'a.txt': 'hello\n'});
      git = GitFixture.init();
      git.commit('initial', files: {'a.txt': 'hello\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
      upstream.dispose();
    });

    group('remoteNames / renameRemote / deleteRemote', () {
      test('round-trips the set of configured remote names', () {
        Remote.create(
          repo: repo,
          name: 'origin',
          url: upstream.fileUrl,
        ).dispose();
        Remote.create(
          repo: repo,
          name: 'other',
          url: upstream.fileUrl,
        ).dispose();

        expect(repo.remoteNames(), containsAll(['origin', 'other']));

        repo.renameRemote('origin', 'renamed');
        expect(repo.remoteNames(), contains('renamed'));

        repo.deleteRemote('renamed');
        expect(repo.remoteNames(), isNot(contains('renamed')));
      });
    });

    group('addRemoteFetch / addRemotePush', () {
      test('appends refspecs to the persisted config', () {
        Remote.create(
          repo: repo,
          name: 'origin',
          url: upstream.fileUrl,
        ).dispose();

        repo.addRemoteFetch('origin', '+refs/tags/*:refs/tags/*');
        repo.addRemotePush('origin', 'refs/heads/main:refs/heads/main');

        final remote = Remote.lookup(repo, 'origin');
        addTearDown(remote.dispose);

        expect(remote.fetchRefspecs, contains('+refs/tags/*:refs/tags/*'));
        expect(
          remote.pushRefspecs,
          contains('refs/heads/main:refs/heads/main'),
        );
      });
    });

    group('setRemoteUrl', () {
      test('persists a new fetch URL to config', () {
        Remote.create(
          repo: repo,
          name: 'origin',
          url: 'https://old.example/repo.git',
        ).dispose();

        repo.setRemoteUrl('origin', 'https://new.example/repo.git');

        final remote = Remote.lookup(repo, 'origin');
        addTearDown(remote.dispose);
        expect(remote.url, 'https://new.example/repo.git');
      });
    });

    group('setRemotePushUrl', () {
      test('persists a new push URL to config', () {
        Remote.create(
          repo: repo,
          name: 'origin',
          url: 'https://fetch.example/repo.git',
        ).dispose();

        repo.setRemotePushUrl('origin', 'https://push.example/repo.git');

        final remote = Remote.lookup(repo, 'origin');
        addTearDown(remote.dispose);
        expect(remote.pushUrl, 'https://push.example/repo.git');
      });
    });

    group('setRemoteAutotag', () {
      test('writes the tag-following rule to config', () {
        Remote.create(
          repo: repo,
          name: 'origin',
          url: 'https://example.com/repo.git',
        ).dispose();

        repo.setRemoteAutotag('origin', RemoteAutotag.none);

        final remote = Remote.lookup(repo, 'origin');
        addTearDown(remote.dispose);
        expect(remote.autotag, RemoteAutotag.none);
      });
    });
  });
}

/// Creates a bare clone of [source] into [bareDir] and returns the path.
String _initBare(String bareDir, String sourceDir) {
  Process.runSync('git', ['init', '--bare', '-b', 'main', bareDir]);
  Process.runSync('git', [
    '-C',
    sourceDir,
    'push',
    '--mirror',
    fileUrl(bareDir),
  ]);
  return bareDir;
}
