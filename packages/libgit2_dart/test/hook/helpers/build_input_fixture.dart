import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:test/test.dart';

BuildInput createTestBuildInput({
  OS os = OS.macOS,
  Architecture arch = Architecture.arm64,
  Map<String, Object?> userDefines = const <String, Object?>{},
}) {
  final tmp = Directory.systemTemp.createTempSync('libgit2_build_input_');
  addTearDown(() => tmp.deleteSync(recursive: true));

  return BuildInput(<String, dynamic>{
    'package_name': 'test_package',
    'package_root': tmp.path,
    'out_dir': '${tmp.path}/out',
    'out_dir_shared': '${tmp.path}/shared',
    'user_defines': <String, dynamic>{
      'workspace_pubspec': <String, dynamic>{
        'base_path': tmp.uri.toFilePath(),
        'defines': userDefines,
      },
    },
    'config': <String, dynamic>{
      'build_code_assets': true,
      'build_asset_types': <String>[],
      'extensions': <String, dynamic>{
        'code_assets': <String, dynamic>{
          'target_os': os.name,
          'target_architecture': arch.name,
          'ios': <String, dynamic>{'target_sdk': 'iphoneos'},
        },
      },
    },
  });
}
