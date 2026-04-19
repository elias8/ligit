part of 'api.dart';

/// Formatting options for diff e-mail generation.
typedef EmailCreateFlag = EmailCreateFlags;

/// Email-patch generation on [Commit].
extension CommitEmail on Commit {
  /// Formats this commit as an mbox-ready email patch.
  ///
  /// The commit must not be a merge commit.
  ///
  /// Set [subjectPrefix] to override the default `PATCH` prefix;
  /// pass the empty string to show only patch numbers. [startNumber]
  /// sets the starting patch number (default 1). [rerollNumber]
  /// records a re-roll (`v2`, `v3`, ...); `0` means no re-roll.
  String toEmailPatch({
    Set<EmailCreateFlag> flags = const {},
    String? subjectPrefix,
    int startNumber = 1,
    int rerollNumber = 0,
  }) {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    return emailCreateFromCommit(
      _handle,
      flags: bits,
      subjectPrefix: subjectPrefix,
      startNumber: startNumber,
      rerollNumber: rerollNumber,
    );
  }
}
