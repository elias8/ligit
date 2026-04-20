part of 'api.dart';

/// Type of SSH host fingerprint.
typedef CertSshHashes = CertSsh;

/// Type of host certificate passed to the check callback.
typedef CertType = CertT;

/// A certificate presented by a remote during a network connection.
///
/// The certificate-check callback on [RemoteCallbacks] receives one
/// of the concrete subtypes: [CertHostkey] for an SSH hostkey,
/// [CertX509] for a TLS certificate, or [CertNone] when the
/// transport (typically libcurl) does not expose the raw material.
@immutable
sealed class Cert {
  /// Kind of certificate.
  final CertType type;

  const Cert._(this.type);

  factory Cert._fromAddress(int address) {
    final type = CertType.fromValue(certReadType(address));
    return switch (type) {
      CertType.hostkeyLibssh2 => CertHostkey._(certReadHostkey(address)),
      CertType.x509 => CertX509._(certReadX509(address)),
      _ => CertNone._(type),
    };
  }

  @override
  int get hashCode => type.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Cert && type == other.type);
}

/// Hostkey information taken from libssh2.
///
/// Only the fields flagged in [availableHashes] carry valid data.
@immutable
final class CertHostkey extends Cert {
  /// Set of hash and raw-key fields that are populated.
  final Set<CertSshHashes> availableHashes;

  /// MD5 hash of the hostkey when [availableHashes] contains
  /// [CertSshHashes.md5].
  final Uint8List md5;

  /// SHA-1 hash of the hostkey when [availableHashes] contains
  /// [CertSshHashes.sha1].
  final Uint8List sha1;

  /// SHA-256 hash of the hostkey when [availableHashes] contains
  /// [CertSshHashes.sha256].
  final Uint8List sha256;

  /// Algorithm of the raw hostkey when [hostkey] is populated.
  final CertSshRawType rawType;

  /// Raw contents of the hostkey when [availableHashes] contains
  /// [CertSshHashes.raw]; otherwise empty.
  final Uint8List hostkey;

  const CertHostkey._raw({
    required this.availableHashes,
    required this.md5,
    required this.sha1,
    required this.sha256,
    required this.rawType,
    required this.hostkey,
  }) : super._(CertType.hostkeyLibssh2);

  factory CertHostkey._(CertHostkeyRecord r) => CertHostkey._raw(
    availableHashes: {
      for (final v in CertSshHashes.values)
        if ((r.availableHashes & v.value) != 0) v,
    },
    md5: r.md5,
    sha1: r.sha1,
    sha256: r.sha256,
    rawType: CertSshRawType.fromValue(r.rawType),
    hostkey: r.hostkey,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CertHostkey &&
          _setEq(availableHashes, other.availableHashes) &&
          _listEq(md5, other.md5) &&
          _listEq(sha1, other.sha1) &&
          _listEq(sha256, other.sha256) &&
          rawType == other.rawType &&
          _listEq(hostkey, other.hostkey));

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(availableHashes),
    Object.hashAll(md5),
    Object.hashAll(sha1),
    Object.hashAll(sha256),
    rawType,
    Object.hashAll(hostkey),
  );
}

/// A certificate whose contents are not exposed by the transport.
///
/// Typically produced by libcurl-backed transports; [type] records
/// which certificate flavour was being produced.
@immutable
final class CertNone extends Cert {
  const CertNone._(super.type) : super._();
}

/// X.509 certificate information.
@immutable
final class CertX509 extends Cert {
  /// DER-encoded certificate data.
  final Uint8List data;

  const CertX509._raw({required this.data}) : super._(CertType.x509);

  factory CertX509._(CertX509Record r) => CertX509._raw(data: r.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CertX509 && _listEq(data, other.data));

  @override
  int get hashCode => Object.hashAll(data);
}
