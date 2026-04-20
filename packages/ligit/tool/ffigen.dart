/// Generates FFI bindings from libgit2 headers.
///
/// Usage:
///   cd packages/ligit
///   dart run tool/ffigen.dart
///
/// Header location: looks at `LIBGIT2_INCLUDE` first, then a small set of
/// well-known directories under `/usr/local`, `/opt/homebrew`, and `/usr`.
library;

import 'dart:io';

import 'package:ffigen/ffigen.dart';
import 'package:ffigen/src/code_generator.dart';
import 'package:ffigen/src/context.dart';
import 'package:ffigen/src/header_parser.dart' as ffigen;
import 'package:logging/logging.dart';

import 'ffigen/enums.dart';
import 'ffigen/naming.dart';

const _nativeOutput = 'lib/src/ffi/libgit2.g.dart';
const _enumsOutput = 'lib/src/ffi/libgit2_enums.g.dart';

void main() {
  Logger.root.onRecord.listen((r) => stderr.writeln(r));

  final include = _resolveIncludeDir();
  if (include == null) {
    stderr.writeln(
      'Could not find libgit2 headers. Set LIBGIT2_INCLUDE to the directory '
      'containing `git2.h`, or install libgit2 via your package manager.',
    );
    exit(1);
  }
  stdout.writeln('Using libgit2 headers from $include');

  final compilerOpts = ['-I$include', ..._sdkIncludeOpts()];
  final renames = _extractEnumMemberRenames(compilerOpts);

  try {
    _createGenerator(
      enumMemberRenames: renames,
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

String? _resolveIncludeDir() {
  final env = Platform.environment['LIBGIT2_INCLUDE'];
  if (env != null && env.isNotEmpty && _hasGit2H(env)) return env;

  const candidates = [
    '/usr/local/include',
    '/opt/homebrew/include',
    '/usr/include',
  ];
  for (final dir in candidates) {
    if (_hasGit2H(dir)) return dir;
  }
  return null;
}

bool _hasGit2H(String dir) => File('$dir/git2.h').existsSync();

List<String> _sdkIncludeOpts() {
  if (!Platform.isMacOS) return const [];
  final result = Process.runSync('xcrun', ['--show-sdk-path']);
  if (result.exitCode != 0) return const [];
  final sdk = (result.stdout as String).trim();
  if (sdk.isEmpty) return const [];
  return ['-isysroot', sdk];
}

Map<String, Map<String, String>> _extractEnumMemberRenames(
  List<String> compilerOpts,
) {
  final generator = FfiGenerator(
    output: Output(dartFile: Uri.file(_nativeOutput)),
    headers: _headers(compilerOpts: compilerOpts),
    enums: const Enums(include: _includeType),
  );

  final library = ffigen.parse(Context(Logger.root, generator));
  final renames = <String, Map<String, String>>{};

  for (final binding in library.bindings) {
    if (binding is! EnumClass) continue;

    final members = [
      for (final c in binding.enumConstants) c.originalName ?? c.name,
    ];
    final prefix = longestCommonPrefix(members);

    renames[binding.originalName] = {
      for (final m in members)
        m: toCamelCase(
          prefix.isNotEmpty && m.startsWith(prefix)
              ? m.substring(prefix.length)
              : m,
        ),
    };
  }

  return renames;
}

Headers _headers({required List<String> compilerOpts}) {
  final include = compilerOpts.first.substring(2);
  return Headers(
    entryPoints: [Uri.file('$include/git2.h')],
    include: (header) {
      final path = header.path;
      return path == '$include/git2.h' || path.startsWith('$include/git2/');
    },
    compilerOptions: compilerOpts,
  );
}

FfiGenerator _createGenerator({
  required Map<String, Map<String, String>>? enumMemberRenames,
  required List<String> compilerOpts,
}) => FfiGenerator(
  output: Output(
    dartFile: Uri.file(_nativeOutput),
    sort: true,
    preamble: '// ignore_for_file: unused_field',
    style: const NativeExternalBindings(assetId: 'package:ligit/ligit.dart'),
  ),
  headers: _headers(compilerOpts: compilerOpts),
  functions: Functions(include: (d) => d.originalName.startsWith('git_')),
  unions: const Unions(include: _includeType, rename: _stripPrefix),
  structs: const Structs(include: _includeType, rename: _stripPrefix),
  typedefs: const Typedefs(include: _includeType, rename: _stripPrefix),
  enums: Enums(
    include: _includeType,
    rename: _stripPrefixAndTypeSuffix,
    renameMember: enumMemberRenames != null
        ? Declarations.renameMemberWithMap(enumMemberRenames)
        : (d, m) => m,
  ),
  globals: const Globals(include: _includeType, rename: _stripPrefix),
  macros: const Macros(include: _includeType),
);

bool _includeType(Declaration d) =>
    d.originalName.startsWith('git_') ||
    d.originalName.startsWith('GIT_') ||
    d.originalName.startsWith('LIBGIT2_');

String _stripPrefix(Declaration d) {
  final n = d.originalName;
  if (n.startsWith('git_')) return _toUpperCamel(n.substring(4));
  if (n.startsWith('GIT_')) return n.substring(4);
  return n;
}

String _stripPrefixAndTypeSuffix(Declaration d) {
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
