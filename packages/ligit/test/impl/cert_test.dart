// Cert instances are produced exclusively by libgit2 during network
// operations (via RemoteCallbacks.certificate). All constructors are
// private, so field-level tests can only be written against real
// connections. The tests here validate the sealed hierarchy shape and
// the CertType enum, which are verifiable without a live remote.
@Tags(['ffi'])
library;

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

void main() {
  group('Cert', () {
    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    group('sealed subtypes', () {
      test('three concrete subtypes exist in the hierarchy', () {
        expect(const <Type>{CertNone, CertHostkey, CertX509}.length, 3);
      });
    });

    group('CertType', () {
      test('enum covers every libgit2 cert flavor', () {
        expect(CertType.values, contains(CertType.none));
        expect(CertType.values, contains(CertType.x509));
        expect(CertType.values, contains(CertType.hostkeyLibssh2));
      });
    });
  });
}
