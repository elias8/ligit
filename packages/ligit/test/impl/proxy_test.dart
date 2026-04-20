@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

void main() {
  group('ProxyOptions', () {
    setUpAll(Libgit2.init);
    tearDownAll(Libgit2.shutdown);

    group('none / auto / specified', () {
      test('sets type and url for each factory', () {
        expect(const ProxyOptions.none().type, ProxyType.none);
        expect(const ProxyOptions.none().url, isNull);

        expect(const ProxyOptions.auto().type, ProxyType.auto);
        expect(const ProxyOptions.auto().url, isNull);

        const specified = ProxyOptions.specified('http://proxy.corp:8080');
        expect(specified.type, ProxyType.specified);
        expect(specified.url, 'http://proxy.corp:8080');
      });
    });

    group('==', () {
      test('options with identical type and url compare equal', () {
        const a = ProxyOptions.specified('http://x');
        const b = ProxyOptions.specified('http://x');

        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('options with different types compare unequal', () {
        expect(
          const ProxyOptions.auto(),
          isNot(equals(const ProxyOptions.none())),
        );
      });
    });
  });
}
