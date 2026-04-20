@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

void main() {
  group('Message', () {
    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    group('prettify', () {
      test('collapses blank lines and appends a trailing newline', () {
        expect(
          Message.prettify('Subject\n\n\n\nBody\n\n'),
          'Subject\n\nBody\n',
        );
      });

      test('leaves comment lines in place by default', () {
        expect(
          Message.prettify('Subject\n\n# keep me\nBody\n'),
          'Subject\n\n# keep me\nBody\n',
        );
      });

      test('removes comment lines when stripComments is true', () {
        expect(
          Message.prettify('Subject\n\n# drop me\nBody\n', stripComments: true),
          'Subject\n\nBody\n',
        );
      });

      test('honours a custom commentChar', () {
        expect(
          Message.prettify(
            'Subject\n\n; drop me\nBody\n',
            stripComments: true,
            commentChar: ';',
          ),
          'Subject\n\nBody\n',
        );
      });

      test('throws ArgumentError when commentChar is not one character', () {
        expect(
          () => Message.prettify('Subject\n', commentChar: ''),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => Message.prettify('Subject\n', commentChar: '##'),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('trailers', () {
      test('returns the empty list when the message has none', () {
        expect(
          Message.trailers('Subject line\n\nSome body text without trailers\n'),
          isEmpty,
        );
      });

      test('parses a single trailer', () {
        final trailers = Message.trailers(
          'Subject\n\nBody\n\nSigned-off-by: Ada <ada@example.com>\n',
        );

        expect(trailers, hasLength(1));
        expect(trailers.single.key, 'Signed-off-by');
        expect(trailers.single.value, 'Ada <ada@example.com>');
      });

      test('parses multiple trailers in order', () {
        final trailers = Message.trailers(
          'Subject\n'
          '\n'
          'Body\n'
          '\n'
          'Signed-off-by: Ada <ada@example.com>\n'
          'Reviewed-by: Linus <linus@example.com>\n',
        );

        expect(trailers, hasLength(2));
        expect(trailers[0].key, 'Signed-off-by');
        expect(trailers[0].value, 'Ada <ada@example.com>');
        expect(trailers[1].key, 'Reviewed-by');
        expect(trailers[1].value, 'Linus <linus@example.com>');
      });
    });
  });
}
