import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

/// A CMake "target triple" approximating libgit2's supported platforms.
///
/// libgit2 itself does not name binaries by triple, but we use the same
/// `<arch>-<os>` slug used by libghostty to keep prebuilt asset filenames
/// stable across releases.
String? cmakeTarget(OS targetOS, Architecture targetArch, {IOSSdk? iOSSdk}) {
  final archStr = switch (targetArch) {
    Architecture.x64 => 'x86_64',
    Architecture.arm64 => 'aarch64',
    Architecture.arm => 'arm',
    Architecture.ia32 => 'x86',
    _ => throw ArgumentError('Unsupported architecture: $targetArch'),
  };

  final osStr = switch (targetOS) {
    OS.macOS => 'macos',
    OS.linux => 'linux',
    OS.windows => 'windows',
    OS.iOS => iOSSdk == IOSSdk.iPhoneSimulator ? 'ios-simulator' : 'ios',
    OS.android => switch (targetArch) {
      Architecture.arm64 || Architecture.x64 => 'linux-android',
      Architecture.arm => 'linux-androideabi',
      _ => throw ArgumentError('Unsupported Android architecture: $targetArch'),
    },
    _ => throw ArgumentError('Unsupported OS: $targetOS'),
  };

  return '$archStr-$osStr';
}

extension BuildInputCMakeTarget on BuildInput {
  String? targetTriple() {
    final os = config.code.targetOS;
    final arch = config.code.targetArchitecture;
    final iOSSdk = os == OS.iOS ? config.code.iOS.targetSdk : null;
    return cmakeTarget(os, arch, iOSSdk: iOSSdk);
  }
}
