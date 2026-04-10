import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:libgit2/src/hook/library_provider.dart';

void main(List<String> args) async {
  await build(args, _build);
}

Future<void> _build(BuildInput input, BuildOutputBuilder output) async {
  if (!input.config.buildCodeAssets) return;

  final targetOS = input.config.code.targetOS;
  final libFileName = targetOS.dylibFileName('git2');
  final installDir = input.outputDirectory;
  final libFile = File.fromUri(installDir.resolve('lib/$libFileName'));

  if (!libFile.existsSync()) {
    final provider = LibraryProvider.resolve(input);
    await provider.provide(libFile);
  }

  if (!libFile.existsSync()) {
    throw Exception(
      'Native library not found at ${libFile.path} after build.\n'
      'Options:\n'
      '  - Install cmake (https://cmake.org/download) to compile from source\n'
      '  - Ensure a GitHub Release exists for the current version',
    );
  }

  output.assets.code.add(
    CodeAsset(
      package: input.packageName,
      name: 'libgit2.dart',
      linkMode: DynamicLoadingBundled(),
      file: libFile.uri,
    ),
  );
}
