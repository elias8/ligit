@Tags(['ffi'])
library;

import 'package:libgit2/libgit2.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  setUpAll(Libgit2.init);
  tearDownAll(Libgit2.shutdown);

  group('RepositoryAttr', () {
    late GitFixture git;
    late Repository repo;

    setUp(() {
      git = GitFixture.init();
      git.writeFile('.gitattributes', '*.c foo\n*.h -foo\n*.txt eol=lf\n');
      git.commit('initial');
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('attribute', () {
      test('classifies set / unset / value / unspecified', () {
        final setAttr = repo.attribute('a.c', 'foo');
        expect(setAttr.kind, AttrKind.true$);
        expect(setAttr.isSet, isTrue);

        final unsetAttr = repo.attribute('a.h', 'foo');
        expect(unsetAttr.kind, AttrKind.false$);
        expect(unsetAttr.isUnset, isTrue);

        final valued = repo.attribute('a.txt', 'eol');
        expect(valued.kind, AttrKind.string);
        expect(valued.stringValue, 'lf');
        expect(valued.hasValue, isTrue);

        final unspec = repo.attribute('random.md', 'foo');
        expect(unspec.kind, AttrKind.unspecified);
        expect(unspec.isUnspecified, isTrue);
      });
    });

    group('attributes', () {
      test('returns a map keyed by the requested names', () {
        final map = repo.attributes('a.txt', ['eol', 'foo']);
        expect(map['eol']!.stringValue, 'lf');
        expect(map['foo']!.isUnspecified, isTrue);
      });
    });

    group('forEachAttribute', () {
      test('visits every attribute rule applying to the path', () {
        final seen = <String, String?>{};
        repo.forEachAttribute('a.txt', (name, value) {
          seen[name] = value;
          return 0;
        });

        expect(seen, containsPair('eol', 'lf'));
      });

      test('stops when the callback returns non-zero', () {
        var calls = 0;
        final code = repo.forEachAttribute('a.txt', (_, _) {
          calls += 1;
          return 42;
        });

        expect(code, 42);
        expect(calls, 1);
      });
    });

    group('addAttrMacro', () {
      test('registers a macro without error and survives cache flush', () {
        repo.addAttrMacro('binary-like', '-diff -crlf');
        repo.flushAttrCache();
        expect(repo.attribute('a.c', 'foo').kind, AttrKind.true$);
      });
    });
  });

  group('AttrLookup', () {
    group('builders', () {
      test('noSystem produces a distinct flags value', () {
        const base = AttrLookup.workdirThenIndex;
        final modified = base.noSystem();
        expect(modified.flags, isNot(equals(base.flags)));
      });

      test('includeHead produces a distinct flags value', () {
        const base = AttrLookup.indexOnly;
        final modified = base.includeHead();
        expect(modified.flags, isNot(equals(base.flags)));
      });

      test('includeCommit produces a distinct flags value', () {
        const base = AttrLookup.indexThenWorkdir;
        final modified = base.includeCommit();
        expect(modified.flags, isNot(equals(base.flags)));
      });

      test('chained builders accumulate flags', () {
        final a = AttrLookup.workdirThenIndex.noSystem();
        final b = AttrLookup.workdirThenIndex.noSystem().includeHead();
        expect(b.flags, isNot(equals(a.flags)));
      });
    });

    group('==', () {
      test('same flags compare equal', () {
        final a = AttrLookup.workdirThenIndex.noSystem();
        final b = AttrLookup.workdirThenIndex.noSystem();
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('different flags are not equal', () {
        expect(
          AttrLookup.workdirThenIndex,
          isNot(equals(AttrLookup.indexOnly)),
        );
      });
    });
  });

  group('AttrResult', () {
    late GitFixture git;
    late Repository repo;

    setUp(() {
      git = GitFixture.init();
      git.writeFile('.gitattributes', '*.c foo\n*.txt eol=lf\n');
      git.commit('initial');
      repo = Repository.open(git.path);
    });

    tearDown(() {
      repo.dispose();
      git.dispose();
    });

    group('==', () {
      test('two lookups of the same attribute compare equal', () {
        final a = repo.attribute('a.txt', 'eol');
        final b = repo.attribute('a.txt', 'eol');
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('different attribute values are not equal', () {
        final set = repo.attribute('a.c', 'foo');
        final unspec = repo.attribute('a.txt', 'bar');
        expect(set, isNot(equals(unspec)));
      });
    });
  });
}
