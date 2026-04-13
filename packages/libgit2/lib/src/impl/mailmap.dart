part of 'api.dart';

/// A set of mappings from alternate committer or author identities to
/// canonical ones.
///
/// Mailmaps let a repository map commits authored under several
/// name/email combinations back to a single logical person. Load one
/// through [Mailmap.fromRepository] (which reads `.mailmap`, the
/// blob named by the `mailmap.blob` config entry, and the path in
/// `mailmap.file`) or [Mailmap.fromString], or build one
/// programmatically with [Mailmap.empty] plus [addEntry].
///
/// Must be [dispose]d when done.
///
/// ```dart
/// final mailmap = Mailmap.fromRepository(repo);
/// try {
///   final resolved = mailmap.resolve(
///     name: 'ada',
///     email: 'ada@old.example',
///   );
///   print('${resolved.name} <${resolved.email}>');
/// } finally {
///   mailmap.dispose();
/// }
/// ```
@immutable
final class Mailmap {
  static final _finalizer = Finalizer<int>(mailmapFree);

  final int _handle;

  /// Allocates an empty mailmap.
  ///
  /// Populate it with [addEntry] before using it for lookups.
  factory Mailmap.empty() => Mailmap._(mailmapNew());

  /// Loads the mailmap for [repo] from the working copy or
  /// configuration.
  ///
  /// Files are consulted in this order:
  ///  1. `.mailmap` in the root of the working directory, if present.
  ///  2. The blob named by the `mailmap.blob` config entry, if set.
  ///     In a bare repository `mailmap.blob` defaults to
  ///     `HEAD:.mailmap`.
  ///  3. The path in the `mailmap.file` config entry, if set.
  factory Mailmap.fromRepository(Repository repo) =>
      Mailmap._(mailmapFromRepository(repo._handle));

  /// Parses [content] as a single mailmap file.
  factory Mailmap.fromString(String content) =>
      Mailmap._(mailmapFromBuffer(content));

  Mailmap._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Adds a single entry to this mailmap.
  ///
  /// If an entry with the same [replaceEmail] (and [replaceName], if
  /// given) already exists, it is replaced. Pass `null` for
  /// [realName] or [realEmail] to leave that side of the output
  /// unchanged, and `null` for [replaceName] to match by email only.
  void addEntry({
    String? realName,
    String? realEmail,
    String? replaceName,
    required String replaceEmail,
  }) {
    mailmapAddEntry(
      _handle,
      realName: realName,
      realEmail: realEmail,
      replaceName: replaceName,
      replaceEmail: replaceEmail,
    );
  }

  /// Releases the native mailmap handle.
  void dispose() {
    _finalizer.detach(this);
    mailmapFree(_handle);
  }

  /// Resolves [name] and [email] through this mailmap, returning the
  /// corresponding real name and email.
  ///
  /// Inputs that no rule matches are returned unchanged.
  ({String name, String email}) resolve({
    required String name,
    required String email,
  }) {
    return mailmapResolve(_handle, name, email);
  }

  /// Resolves [signature] through this mailmap, returning a new
  /// [Signature] with the real name and email.
  Signature resolveSignature(Signature signature) {
    final srcHandle = signatureNew(
      signature.name,
      signature.email,
      signature._record.time,
      signature._record.offset,
    );
    try {
      final outHandle = mailmapResolveSignature(_handle, srcHandle);
      final resolved = Signature._fromHandle(outHandle);
      signatureFree(outHandle);
      return resolved;
    } finally {
      signatureFree(srcHandle);
    }
  }

  /// Resolves [name] and [email] without a mailmap, passing the
  /// inputs through unchanged.
  ///
  /// Useful as a drop-in for [resolve] when no mailmap is available.
  static ({String name, String email}) passthrough({
    required String name,
    required String email,
  }) {
    return mailmapResolve(null, name, email);
  }
}

/// Resolves commit author/committer signatures through a [Mailmap].
extension CommitMailmapExt on Commit {
  /// The author signature resolved through [mailmap].
  ///
  /// Pass `null` to let libgit2 locate the mailmap automatically
  /// based on the repository configuration.
  Signature authorWithMailmap([Mailmap? mailmap]) {
    return _signatureFromRecord(
      commitAuthorWithMailmap(_handle, mailmap?._handle ?? 0),
    );
  }

  /// The committer signature resolved through [mailmap].
  ///
  /// Pass `null` to let libgit2 locate the mailmap automatically
  /// based on the repository configuration.
  Signature committerWithMailmap([Mailmap? mailmap]) {
    return _signatureFromRecord(
      commitCommitterWithMailmap(_handle, mailmap?._handle ?? 0),
    );
  }
}
