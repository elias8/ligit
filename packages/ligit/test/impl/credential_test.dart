@Tags(['ffi'])
library;

import 'dart:io';

import 'package:ligit/ligit.dart';
import 'package:test/test.dart';

import 'helpers/git_fixture.dart';

void main() {
  group('Credential', () {
    setUpAll(Libgit2.init);

    tearDownAll(Libgit2.shutdown);

    group('userpass', () {
      test('stores username and password, hasUsername is true', () {
        final cred = Credential.userpass(username: 'git', password: 'hunter2');
        addTearDown(cred.dispose);

        expect(cred.hasUsername, isTrue);
        expect(cred.username, 'git');
      });
    });

    group('username', () {
      test('stores a username-only credential', () {
        final cred = Credential.username('alice');
        addTearDown(cred.dispose);

        expect(cred.username, 'alice');
        expect(cred.hasUsername, isTrue);
      });
    });

    group('negotiateDefault', () {
      test('creates a negotiate credential with no username attached', () {
        final cred = Credential.negotiateDefault();
        addTearDown(cred.dispose);

        expect(cred.hasUsername, isFalse);
      });
    });

    group('sshKey', () {
      test('stores username and key paths for an on-disk SSH key', () {
        final tempDir = createTempDir();
        addTearDown(() => deleteTempDir(tempDir));

        final keyPath = '$tempDir/id_ed25519';
        Process.runSync('ssh-keygen', [
          '-t',
          'ed25519',
          '-f',
          keyPath,
          '-N',
          '',
          '-q',
        ]);

        final cred = Credential.sshKey(
          username: 'git',
          privateKeyPath: keyPath,
          publicKeyPath: '$keyPath.pub',
        );
        addTearDown(cred.dispose);

        expect(cred.hasUsername, isTrue);
        expect(cred.username, 'git');
      });
    });

    group('sshKeyInMemory', () {
      test('accepts PEM key content and stores the username', () {
        final tempDir = createTempDir();
        addTearDown(() => deleteTempDir(tempDir));

        final keyPath = '$tempDir/id_ed25519';
        Process.runSync('ssh-keygen', [
          '-t',
          'ed25519',
          '-f',
          keyPath,
          '-N',
          '',
          '-q',
        ]);

        final privateKey = File(keyPath).readAsStringSync();
        final publicKey = File('$keyPath.pub').readAsStringSync();

        final cred = Credential.sshKeyInMemory(
          username: 'git',
          privateKey: privateKey,
          publicKey: publicKey,
        );
        addTearDown(cred.dispose);

        expect(cred.hasUsername, isTrue);
        expect(cred.username, 'git');
      });
    });

    group('sshAgent', () {
      test('constructs with a username without requiring a running agent', () {
        final cred = Credential.sshAgent('deploy');
        addTearDown(cred.dispose);

        expect(cred.hasUsername, isTrue);
        expect(cred.username, 'deploy');
      });
    });
  });
}
