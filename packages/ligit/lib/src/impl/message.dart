part of 'api.dart';

/// Commit-message helpers for whitespace prettification and trailer
/// parsing.
///
/// Pure string transformations; nothing here touches a repository or
/// holds native state, so every operation is exposed as a `static`
/// method.
abstract final class Message {
  /// Cleans up excess whitespace in [message] and ensures it ends
  /// with a trailing newline.
  ///
  /// When [stripComments] is `true`, any line starting with
  /// [commentChar] is removed. [commentChar] defaults to `#` and must
  /// be exactly one character.
  ///
  /// Throws [ArgumentError] when [commentChar] is not a single
  /// character, or [Libgit2Exception] when the message cannot be
  /// prettified.
  static String prettify(
    String message, {
    bool stripComments = false,
    String commentChar = '#',
  }) => messagePrettify(
    message,
    stripComments: stripComments,
    commentChar: commentChar,
  );

  /// Parses trailers out of [message].
  ///
  /// A trailer is a `Key: value` line in the last paragraph of the
  /// message, not counting any patches or merge-conflict blocks that
  /// may follow. Returns an empty list when no trailers are present
  /// and preserves the order in which they appear.
  ///
  /// Throws [Libgit2Exception] when the message cannot be parsed.
  static List<({String key, String value})> trailers(String message) =>
      messageTrailers(message);
}
