part of 'api.dart';

/// Flags indicating how a revision spec was interpreted by
/// [Repository.revParseRange].
typedef RevSpecFlag = rp.RevspecT;

/// The parsed result of a revision range expression such as
/// `main..topic` or `main...topic`.
///
/// [from] is the left side of the expression; [to] is the right side,
/// or `null` when the expression did not imply a second endpoint.
/// [flags] records which operators the spec used.
///
/// Instances own the contained [GitObject]s and must be [dispose]d
/// when no longer needed.
///
/// ```dart
/// final spec = repo.revParseRange('main..topic');
/// try {
///   print(spec.from.id);
///   print(spec.to?.id);
///   print(spec.flags); // {RevSpecFlag.range}
/// } finally {
///   spec.dispose();
/// }
/// ```
final class RevSpec {
  /// The left-hand object of the range.
  final GitObject from;

  /// The right-hand object of the range, or `null` when the
  /// expression did not imply a second endpoint.
  final GitObject? to;

  /// The operators recognized while parsing the spec.
  final Set<RevSpecFlag> flags;

  const RevSpec._({required this.from, required this.to, required this.flags});

  /// Whether the spec targeted a single object.
  bool get isSingle => flags.contains(RevSpecFlag.single);

  /// Whether the spec used `..` to request a commit range.
  bool get isRange => flags.contains(RevSpecFlag.range);

  /// Whether the spec used `...` to request the merge-base range.
  bool get isMergeBase => flags.contains(RevSpecFlag.mergeBase);

  /// Releases both endpoints.
  void dispose() {
    from.dispose();
    to?.dispose();
  }
}

Set<RevSpecFlag> _decodeRevSpecFlags(int bits) {
  return {
    for (final f in RevSpecFlag.values)
      if (bits & f.value != 0) f,
  };
}
