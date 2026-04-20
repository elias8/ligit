part of 'api.dart';

/// Authentication methods supported by the library.
typedef CredentialType = CredentialT;

/// Authentication material handed to a transport during a remote
/// operation.
///
/// A transport that accepts a credential takes ownership of it, so
/// in typical callback use the caller does not need to [dispose].
/// The explicit [dispose] exists for paths where a credential was
/// built but never consumed.
///
/// Interactive and custom-signature SSH credentials are not
/// wrapped: they expose libssh2 session types that have no stable
/// Dart representation. Use [Credential.sshAgent] or
/// [Credential.sshKey] instead.
@immutable
final class Credential {
  static final _finalizer = Finalizer<int>(credentialFree);

  final int _handle;

  /// Creates a plain-text username/password credential.
  factory Credential.userpass({
    required String username,
    required String password,
  }) => Credential._(credentialUserpassPlaintextNew(username, password));

  /// Creates a "default" credential used for Negotiate mechanisms
  /// like NTLM or Kerberos.
  factory Credential.negotiateDefault() => Credential._(credentialDefaultNew());

  /// Creates a credential that only specifies a username.
  ///
  /// Used with SSH authentication to announce a username when none
  /// is present in the URL.
  factory Credential.username(String username) =>
      Credential._(credentialUsernameNew(username));

  /// Creates a passphrase-protected SSH key credential reading keys
  /// from disk.
  ///
  /// [publicKeyPath] may be null to let libgit2 derive it from the
  /// private key. [passphrase] unlocks an encrypted private key.
  factory Credential.sshKey({
    required String username,
    required String privateKeyPath,
    String? publicKeyPath,
    String? passphrase,
  }) => Credential._(
    credentialSshKeyNew(
      username,
      privateKeyPath,
      publicKeyPath: publicKeyPath,
      passphrase: passphrase,
    ),
  );

  /// Creates an SSH key credential by reading the keys from memory.
  ///
  /// Support depends on the crypto backend libgit2 was built with;
  /// some builds only support loading keys from disk.
  factory Credential.sshKeyInMemory({
    required String username,
    required String privateKey,
    String? publicKey,
    String? passphrase,
  }) => Credential._(
    credentialSshKeyMemoryNew(
      username,
      privateKey,
      publicKey: publicKey,
      passphrase: passphrase,
    ),
  );

  /// Creates an SSH key credential that queries the running
  /// ssh-agent.
  factory Credential.sshAgent(String username) =>
      Credential._(credentialSshKeyFromAgent(username));

  Credential._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Whether this credential has a non-null username.
  bool get hasUsername => credentialHasUsername(_handle);

  /// Username associated with this credential, or null when none is
  /// attached.
  String? get username => credentialGetUsername(_handle);

  /// Releases the native credential.
  ///
  /// Only needed when the credential was not handed to a transport;
  /// transports consume credentials they accept.
  void dispose() {
    _finalizer.detach(this);
    credentialFree(_handle);
  }

  void _handOffToLibgit2() {
    _finalizer.detach(this);
  }
}
