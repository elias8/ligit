@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:libgit2/libgit2.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Blob', () {
    late String tempDir;
    late Repository repo;

    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    setUp(() {
      tempDir = createTempDir();
      repo = Repository.init(tempDir);
      // libgit2's filter pipeline honors core.autocrlf, which Windows git
      // globally sets to true. Pin it off so filter tests round-trip
      // bytes on every host.
      Process.runSync('git', [
        '-C',
        tempDir,
        'config',
        'core.autocrlf',
        'false',
      ]);
    });

    tearDown(() {
      repo.dispose();
      deleteTempDir(tempDir);
    });

    group('fromBuffer', () {
      test('writes the bytes and rounds trip via lookup', () {
        final content = Uint8List.fromList(utf8.encode('hello world\n'));

        final blob = Blob.fromBuffer(repo, content);
        addTearDown(blob.dispose);

        expect(blob.content, content);
        expect(blob.size, content.length);
      });
    });

    group('fromWorkDir', () {
      test('reads a file from the working directory', () {
        File('$tempDir/greet.txt').writeAsStringSync('hi\n');

        final blob = Blob.fromWorkDir(repo, 'greet.txt');
        addTearDown(blob.dispose);

        expect(utf8.decode(blob.content), 'hi\n');
      });

      test('throws on a bare repository', () {
        final bareDir = createTempDir();
        addTearDown(() => deleteTempDir(bareDir));
        final bare = Repository.init(bareDir, bare: true);
        addTearDown(bare.dispose);

        expect(
          () => Blob.fromWorkDir(bare, 'missing.txt'),
          throwsA(isA<Libgit2Exception>()),
        );
      });
    });

    group('fromDisk', () {
      test('reads any file on disk', () {
        final outside = File('$tempDir/../outside.txt')
          ..writeAsStringSync('elsewhere');
        addTearDown(() {
          try {
            outside.deleteSync();
          } on FileSystemException {
            // best effort
          }
        });

        final blob = Blob.fromDisk(repo, outside.path);
        addTearDown(blob.dispose);

        expect(utf8.decode(blob.content), 'elsewhere');
      });
    });

    group('lookup', () {
      test('throws NotFoundException for a missing id', () {
        expect(
          () => Blob.lookup(
            repo,
            Oid.fromString('0000000000000000000000000000000000000001'),
          ),
          throwsA(isA<NotFoundException>()),
        );
      });
    });

    group('lookupPrefix', () {
      test('resolves a blob from a short prefix', () {
        final written = Blob.fromBuffer(
          repo,
          Uint8List.fromList(utf8.encode('prefix test\n')),
        );
        addTearDown(written.dispose);

        final found = Blob.lookupPrefix(repo, written.id, Oid.minPrefixLength);
        addTearDown(found.dispose);

        expect(found.id, written.id);
      });
    });

    group('metadata', () {
      test('size and content reflect the stored bytes', () {
        final blob = Blob.fromBuffer(repo, Uint8List.fromList([1, 2, 3, 4]));
        addTearDown(blob.dispose);

        expect(blob.size, 4);
        expect(blob.content, [1, 2, 3, 4]);
      });

      test('isBinary flags blobs containing NUL bytes', () {
        final binary = Blob.fromBuffer(
          repo,
          Uint8List.fromList([0x00, 0x01, 0x02, 0x00]),
        );
        addTearDown(binary.dispose);

        final text = Blob.fromBuffer(
          repo,
          Uint8List.fromList(utf8.encode('plain text here\n')),
        );
        addTearDown(text.dispose);

        expect(binary.isBinary, isTrue);
        expect(text.isBinary, isFalse);
      });
    });

    group('isDataBinary', () {
      test('uses the same heuristic without a stored blob', () {
        expect(
          Blob.isDataBinary(Uint8List.fromList([0x00, 0x01, 0x02])),
          isTrue,
        );
        expect(
          Blob.isDataBinary(Uint8List.fromList(utf8.encode('hello'))),
          isFalse,
        );
      });
    });

    group('fromStream', () {
      test('assembles chunks into the same blob as fromBuffer', () {
        final streamed = Blob.fromStream(repo, [
          Uint8List.fromList(utf8.encode('hel')),
          Uint8List.fromList(utf8.encode('lo\n')),
        ]);
        addTearDown(streamed.dispose);

        final buffered = Blob.fromBuffer(
          repo,
          Uint8List.fromList(utf8.encode('hello\n')),
        );
        addTearDown(buffered.dispose);

        expect(streamed.id, buffered.id);
      });
    });

    group('filter', () {
      test('returns the raw content when no filter applies', () {
        final blob = Blob.fromBuffer(
          repo,
          Uint8List.fromList(utf8.encode('plain\n')),
        );
        addTearDown(blob.dispose);

        expect(blob.filter('a.txt'), blob.content);
      });
    });

    group('dup', () {
      test('produces an independent handle that compares equal', () {
        final a = Blob.fromBuffer(repo, Uint8List.fromList([1, 2, 3]));
        addTearDown(a.dispose);

        final b = a.dup();
        addTearDown(b.dispose);

        expect(identical(a, b), isFalse);
        expect(a, equals(b));
      });
    });

    group('==', () {
      test('same id compares equal across lookups', () {
        final written = Blob.fromBuffer(repo, Uint8List.fromList([5, 6, 7]));
        final id = written.id;
        written.dispose();

        final a = Blob.lookup(repo, id);
        addTearDown(a.dispose);
        final b = Blob.lookup(repo, id);
        addTearDown(b.dispose);

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });
    });
  });
}
