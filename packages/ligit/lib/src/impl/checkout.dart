part of 'api.dart';

/// Checkout operations on [Repository].
extension RepositoryCheckout on Repository {
  /// Updates the working tree and index to match the tree HEAD
  /// points at.
  ///
  /// This is not a branch switch — HEAD is untouched. To switch
  /// branches, use [checkoutTree] and then [setHead].
  ///
  /// [strategies] controls how conflicts are handled; pass
  /// [CheckoutStrategy.safe] (the default behavior) for a
  /// non-destructive update, [CheckoutStrategy.force] to overwrite
  /// local changes, or [CheckoutStrategy.dryRun] to probe without
  /// writing. [paths], when non-empty, limits the checkout to
  /// matching wildmatch patterns. [baseline] overrides the expected
  /// pre-checkout tree (defaults to HEAD). [targetDirectory]
  /// redirects writes to an alternative path. [ancestorLabel],
  /// [ourLabel], and [theirLabel] name the sides of conflict
  /// markers. [dirMode] and [fileMode] override the default
  /// permission bits. Set [disableFilters] to skip filters such as
  /// CRLF conversion.
  ///
  /// The target repository must not be bare.
  ///
  /// Throws [UnbornBranchException] when HEAD points at an unborn
  /// branch.
  void checkoutHead({
    Set<CheckoutStrategy> strategies = const {},
    Tree? baseline,
    List<String> paths = const [],
    String? targetDirectory,
    String? ancestorLabel,
    String? ourLabel,
    String? theirLabel,
    int dirMode = 0,
    int fileMode = 0,
    bool disableFilters = false,
  }) {
    bindings_checkout.checkoutHead(
      _handle,
      strategy: _bits(strategies),
      baselineTreeHandle: baseline?._handle,
      paths: paths,
      targetDirectory: targetDirectory,
      ancestorLabel: ancestorLabel,
      ourLabel: ourLabel,
      theirLabel: theirLabel,
      dirMode: dirMode,
      fileMode: fileMode,
      disableFilters: disableFilters,
    );
  }

  /// Updates the working tree and index to match the tree at
  /// [treeish].
  ///
  /// [treeish] may be any object whose content resolves to a tree:
  /// a tree, a commit, or a tag pointing at either. Pass `null` to
  /// fall back to HEAD. The target repository must not be bare. See
  /// [checkoutHead] for the option semantics.
  void checkoutTree(
    GitObject? treeish, {
    Set<CheckoutStrategy> strategies = const {},
    Tree? baseline,
    List<String> paths = const [],
    String? targetDirectory,
    String? ancestorLabel,
    String? ourLabel,
    String? theirLabel,
    int dirMode = 0,
    int fileMode = 0,
    bool disableFilters = false,
  }) {
    bindings_checkout.checkoutTree(
      _handle,
      treeish?._handle ?? 0,
      strategy: _bits(strategies),
      baselineTreeHandle: baseline?._handle,
      paths: paths,
      targetDirectory: targetDirectory,
      ancestorLabel: ancestorLabel,
      ourLabel: ourLabel,
      theirLabel: theirLabel,
      dirMode: dirMode,
      fileMode: fileMode,
      disableFilters: disableFilters,
    );
  }

  /// Updates the working tree to match the contents of the
  /// repository's index.
  ///
  /// Operates on the default repository index. The target repository
  /// must not be bare. See [checkoutHead] for the option semantics.
  void checkoutIndex({
    Set<CheckoutStrategy> strategies = const {},
    Tree? baseline,
    List<String> paths = const [],
    String? targetDirectory,
    String? ancestorLabel,
    String? ourLabel,
    String? theirLabel,
    int dirMode = 0,
    int fileMode = 0,
    bool disableFilters = false,
  }) {
    bindings_checkout.checkoutIndex(
      _handle,
      strategy: _bits(strategies),
      baselineTreeHandle: baseline?._handle,
      paths: paths,
      targetDirectory: targetDirectory,
      ancestorLabel: ancestorLabel,
      ourLabel: ourLabel,
      theirLabel: theirLabel,
      dirMode: dirMode,
      fileMode: fileMode,
      disableFilters: disableFilters,
    );
  }

  static int _bits(Set<CheckoutStrategy> flags) {
    var bits = 0;
    for (final f in flags) {
      bits |= f.value;
    }
    return bits;
  }
}
