/// Generates FFI bindings from libgit2 headers.
///
/// Usage:
///   cd packages/ligit
///   dart run tool/ffigen.dart
///
/// Headers come from `LIBGIT2_INCLUDE` when set; otherwise the pinned source
/// is resolved from `LIBGIT2_SRC`, the workspace, or the download cache.
library;

import 'dart:io';

import 'package:ffigen/ffigen.dart';
import 'package:ligit/src/hook/libgit2_source.dart';
import 'package:logging/logging.dart';

import 'ffigen/enums.dart';
import 'ffigen/naming.dart';

const _nativeOutput = 'lib/src/ffi/libgit2.g.dart';
const _enumsOutput = 'lib/src/ffi/libgit2_enums.g.dart';

Future<void> main() async {
  Logger.root.onRecord.listen((r) => stderr.writeln(r));

  final packageRoot = Directory.current.uri;
  String? include;
  try {
    include = await _resolveIncludeDir(packageRoot);
  } on Object catch (error) {
    stderr.writeln('Failed to resolve libgit2 headers: $error');
    exit(1);
  }
  if (include == null) {
    stderr.writeln(
      'Could not resolve libgit2 headers for ${pinnedTag(packageRoot)}. '
      'Set LIBGIT2_INCLUDE or LIBGIT2_SRC to a matching local checkout, '
      'or ensure the pinned source can be downloaded.',
    );
    exit(1);
  }
  stdout.writeln('Using libgit2 headers from $include');

  final compilerOpts = ['-I$include', ..._sdkIncludeOpts()];

  try {
    await _createGenerator(
      compilerOpts: compilerOpts,
    ).generate(logger: Logger.root);
  } on Object catch (e, s) {
    stderr.writeln('Failed to generate bindings: $e\n$s');
    exit(1);
  }

  try {
    extractEnums(
      bindingsPath: _nativeOutput,
      enumsPath: _enumsOutput,
      docPrefix: 'git_',
    );
  } on Object catch (e, s) {
    stderr.writeln('Failed to extract enums: $e\n$s');
    exit(1);
  }
}

Future<String?> _resolveIncludeDir(Uri packageRoot) async {
  final env = Platform.environment['LIBGIT2_INCLUDE'];
  if (env != null && env.isNotEmpty) {
    final include = _withoutTrailingSeparator(env);
    if (!_hasGit2H(include)) {
      throw StateError('libgit2 headers not found at $include.');
    }
    validatePinnedHeaders(
      include: Directory(include),
      packageRoot: packageRoot,
    );
    return include;
  }

  final source = await resolveSource(
    packageRoot: packageRoot,
    cacheBase: packageRoot.resolve('.dart_tool/ffigen/'),
  );
  final include = _withoutTrailingSeparator(
    Directory.fromUri(source.uri.resolve('include/')).path,
  );
  if (!_hasGit2H(include)) return null;
  validatePinnedHeaders(include: Directory(include), packageRoot: packageRoot);
  return include;
}

bool _hasGit2H(String dir) => File('$dir/git2.h').existsSync();

String _withoutTrailingSeparator(String path) =>
    path.replaceFirst(RegExp(r'[/\\]+$'), '');

List<String> _sdkIncludeOpts() {
  if (!Platform.isMacOS) return const [];
  final result = Process.runSync('xcrun', ['--show-sdk-path']);
  if (result.exitCode != 0) return const [];
  final sdk = (result.stdout as String).trim();
  if (sdk.isEmpty) return const [];
  return ['-isysroot', sdk];
}

Input _headers({required List<String> compilerOpts}) {
  final include = compilerOpts.first.substring(2);
  return Input(
    entryPoints: [Uri.file('$include/git2.h')],
    include: (header) {
      final path = header.path;
      return path == '$include/git2.h' || path.startsWith('$include/git2/');
    },
    compilerOptions: compilerOpts,
  );
}

FfiGenerator _createGenerator({required List<String> compilerOpts}) =>
    FfiGenerator(
      output: Output(
        dart: DartOutput(path: Uri.file(_nativeOutput)),
        preamble: '// ignore_for_file: unused_field',
        style: const NativeExternalBindings(
          assetId: 'package:ligit/ligit.dart',
        ),
      ),
      input: _headers(compilerOpts: compilerOpts),
      visitors: [
        Visitor(
          func: (node) =>
              node.isIncluded = node.originalName.startsWith('git_'),
          struct: (node) {
            node.isIncluded = _includeType(node);
            node.name = _stripPrefix(node);
          },
          union: (node) {
            node.isIncluded = _includeType(node);
            node.name = _stripPrefix(node);
          },
          typealias: (node) {
            node.isIncluded = _includeType(node)
                ? TypealiasInclude.always
                : TypealiasInclude.ifUsed;
            node.name = _stripPrefix(node);
          },
          enumClass: (node) {
            node.isIncluded = _includeType(node);
            node.name = _stripPrefixAndTypeSuffix(node);
            final members = node.constants.map((c) => c.originalName).toList();
            final prefix = longestCommonPrefix(members);
            for (final member in node.constants) {
              final name = member.originalName;
              member.name = toCamelCase(
                prefix.isNotEmpty && name.startsWith(prefix)
                    ? name.substring(prefix.length)
                    : name,
              );
            }
          },
          global: (node) {
            node.isIncluded = _includeType(node);
            node.name = _stripPrefix(node);
          },
          macroConstant: (node) => node.isIncluded = _includeType(node),
          unnamedEnumConstant: (node) => node.isIncluded = _includeType(node),
        ),
      ],
    );

bool _includeType(NamedNode d) =>
    d.originalName.startsWith('git_') ||
    d.originalName.startsWith('GIT_') ||
    d.originalName.startsWith('LIBGIT2_');

String _stripPrefix(NamedNode d) {
  final n = d.originalName;
  if (n.startsWith('git_')) return _toUpperCamel(n.substring(4));
  if (n.startsWith('GIT_')) return n.substring(4);
  return n;
}

String _stripPrefixAndTypeSuffix(NamedNode d) {
  var n = d.originalName;
  if (n.endsWith('_t') && !_enumKeepsTypeSuffix.contains(n)) {
    n = n.substring(0, n.length - 2);
  }
  if (n.startsWith('git_')) return _toUpperCamel(n.substring(4));
  if (n.startsWith('GIT_')) return n.substring(4);
  return n;
}

/// Enums whose stripped name would collide with a hand-written wrapper class
/// in `lib/src/impl/` or with a `dart:core` type. These keep their `T` suffix;
/// the impl layer re-exports them under a non-colliding alias
/// (e.g. `BranchType`, `CertType`, `ObjectType`).
const _enumKeepsTypeSuffix = {
  'git_branch_t',
  'git_cert_t',
  'git_configmap_t',
  'git_credential_t',
  'git_diff_binary_t',
  'git_diff_line_t',
  'git_error_t',
  'git_object_t',
  'git_odb_stream_t',
  'git_oid_t',
  'git_rebase_operation_t',
  'git_reference_t',
  'git_revspec_t',
  'git_tree_update_t',
};

String _toUpperCamel(String snake) {
  final parts = snake.split('_').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return snake;
  return parts
      .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
      .join();
}
