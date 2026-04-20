@Tags(['ffi'])
library;

import 'dart:io';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Config', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('initial', files: {'a.txt': 'hello\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('Repository.config', () {
      test('reads values written by git config', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);

        expect(cfg.getString('user.name'), 'Test');
        expect(cfg.getString('user.email'), 'test@example.com');
        expect(cfg.getString('does.not.exist'), isNull);
      });
    });

    group('snapshotFromRepository', () {
      test('takes a read-only snapshot of the repository config', () {
        final snap = Config.snapshotFromRepository(repo);
        addTearDown(snap.dispose);

        expect(snap.getString('user.name'), 'Test');
      });
    });

    group('set / get', () {
      test('writes and reads back every typed value', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);

        cfg.setString('my.string', 'hello');
        cfg.setInt('my.int', 42);
        cfg.setInt32('my.int32', 7);
        cfg.setBool('my.bool', value: true);

        expect(cfg.getString('my.string'), 'hello');
        expect(cfg.getInt('my.int'), 42);
        expect(cfg.getInt32('my.int32'), 7);
        expect(cfg.getBool('my.bool'), isTrue);
      });
    });

    group('getPath', () {
      test('reads a path value with tilde expansion', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);

        cfg.setString('my.path', '~/foo');
        final p = cfg.getPath('my.path');
        expect(p, isNotNull);
        expect(p, isNot(startsWith('~')));
      });
    });

    group('deleteEntry', () {
      test('removes an existing variable', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);

        cfg.setString('to.delete', 'bye');
        expect(cfg.getString('to.delete'), 'bye');

        cfg.deleteEntry('to.delete');
        expect(cfg.getString('to.delete'), isNull);
      });

      test('throws NotFoundException for a missing variable', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);

        expect(
          () => cfg.deleteEntry('nope.nope'),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('setMultivar / multivar / deleteMultivar', () {
      test('adds, reads, and deletes multivar entries', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);

        // Seed two values via git CLI.
        git.git(['config', '--add', 'my.multi', 'one']);
        git.git(['config', '--add', 'my.multi', 'two']);

        // setMultivar replaces values matching a regex.
        cfg.setMultivar('my.multi', 'one', 'ONE');
        final values = cfg.multivar('my.multi');
        expect(values, contains('ONE'));
        expect(values, contains('two'));

        // deleteMultivar removes entries matching a regex.
        cfg.deleteMultivar('my.multi', 'two');
        expect(cfg.multivar('my.multi'), isNot(contains('two')));
      });
    });

    group('list', () {
      test('enumerates every set variable', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);
        cfg.setString('color.ui', 'auto');

        final entries = cfg.list();
        expect(entries.map((e) => e.name), contains('color.ui'));
      });
    });

    group('getEntry', () {
      test('returns the full entry metadata at the local level', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);
        cfg.setString('meta.key', 'value');

        final entry = cfg.getEntry('meta.key');
        expect(entry, isNotNull);
        expect(entry!.name, 'meta.key');
        expect(entry.value, 'value');
        expect(entry.level, ConfigLevel.levelLocal);
      });
    });

    group('openOnDisk', () {
      test('reads a standalone config file', () {
        final path = '${git.path}/.git/config';

        final cfg = Config.openOnDisk(path);
        addTearDown(cfg.dispose);

        expect(cfg.getString('core.bare'), 'false');
      });
    });

    group('snapshot', () {
      test('freezes the config at the moment of the call', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);
        cfg.setString('snap.key', 'before');

        final snap = cfg.snapshot();
        addTearDown(snap.dispose);

        cfg.setString('snap.key', 'after');

        // Snapshot sees the value at the time it was taken.
        expect(snap.getString('snap.key'), 'before');
      });
    });

    group('openLevel', () {
      test('returns a single-level view of the local config', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);
        cfg.setString('level.key', 'local');

        final local = cfg.openLevel(ConfigLevel.levelLocal);
        addTearDown(local.dispose);

        expect(local.getString('level.key'), 'local');
      });
    });

    group('openGlobal', () {
      test('returns a writable global config object', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);

        // openGlobal may throw NotFoundException when there is no
        // global config file. Accept either outcome.
        Config? global;
        try {
          global = cfg.openGlobal();
        } on NotFoundException {
          return;
        }
        addTearDown(global.dispose);
        expect(global, isA<Config>());
      });
    });

    group('forEach', () {
      test('visits every entry and respects the callback return', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);
        cfg.setString('my.alpha', 'a');
        cfg.setString('my.beta', 'b');

        final names = <String>[];
        cfg.forEach((entry) {
          names.add(entry.name);
          return 0;
        }, pattern: r'^my\.');

        expect(names, containsAll(<String>['my.alpha', 'my.beta']));
      });
    });

    group('forEachMultivar', () {
      test('visits every value of a repeated key', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);
        git.git(['config', '--add', 'my.multi', 'one']);
        git.git(['config', '--add', 'my.multi', 'two']);

        final values = <String>[];
        cfg.forEachMultivar('my.multi', (entry) {
          values.add(entry.value);
          return 0;
        });

        expect(values, containsAll(<String>['one', 'two']));
      });
    });

    group('lock', () {
      test('returns a transaction that commits pending writes', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);

        final tx = cfg.lock();
        cfg.setString('my.locked', 'yes');
        tx.commit();
        tx.dispose();

        expect(cfg.getString('my.locked'), 'yes');
      });
    });

    group('setWriteOrder', () {
      test('accepts a list of levels without throwing', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);

        cfg.setWriteOrder(const [ConfigLevel.levelLocal]);
        cfg.setString('my.order', 'set');
        expect(cfg.getString('my.order'), 'set');
      });
    });

    group('addFileOnDisk', () {
      test('layers an additional on-disk backend', () {
        final extra = '${git.path}/extra.cfg';
        File(extra).writeAsStringSync('[extra]\nkey = val\n');

        final cfg = Config.empty();
        addTearDown(cfg.dispose);
        cfg.addFileOnDisk(extra, ConfigLevel.levelLocal);

        expect(cfg.getString('extra.key'), 'val');
      });
    });

    group('static parsers', () {
      test('parseBool recognizes git truthy/falsy tokens', () {
        expect(Config.parseBool('yes'), isTrue);
        expect(Config.parseBool('off'), isFalse);
      });

      test('parseInt honors k/m/g suffixes', () {
        expect(Config.parseInt('2k'), 2048);
        expect(Config.parseInt32('1m'), 1024 * 1024);
      });

      test('parsePath expands a leading tilde', () {
        final p = Config.parsePath('~/some/path');
        expect(p, isNot(startsWith('~')));
      });
    });

    group('findGlobal / findSystem / findXdg / findProgramData', () {
      test('each returns String? (null when the file is absent)', () {
        expect(Config.findGlobal(), anyOf(isNull, isA<String>()));
        expect(Config.findSystem(), anyOf(isNull, isA<String>()));
        expect(Config.findXdg(), anyOf(isNull, isA<String>()));
        expect(Config.findProgramData(), anyOf(isNull, isA<String>()));
      });
    });
  });

  group('ConfigEntry', () {
    late GitFixture git;
    late Repository repo;

    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    setUp(() {
      git = GitFixture.init();
      git.commit('initial', files: {'a.txt': 'x\n'});
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('==', () {
      test('two entries with identical fields compare equal', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);
        cfg.setString('eq.key', 'val');

        final a = cfg.getEntry('eq.key')!;
        final b = cfg.getEntry('eq.key')!;

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('entries with different values are not equal', () {
        final cfg = repo.config();
        addTearDown(cfg.dispose);
        cfg.setString('eq.a', 'one');
        cfg.setString('eq.b', 'two');

        final a = cfg.getEntry('eq.a')!;
        final b = cfg.getEntry('eq.b')!;

        expect(a, isNot(equals(b)));
      });
    });
  });
}
