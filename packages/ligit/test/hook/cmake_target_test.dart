@Tags(['ffi'])
library;

import 'package:code_assets/code_assets.dart';
import 'package:ligit/src/hook/cmake_target.dart';
import 'package:test/test.dart';

import 'helpers/build_input_fixture.dart';

void main() {
  group('cmakeTarget', () {
    group('macOS', () {
      test('arm64 maps to aarch64-macos', () {
        expect(cmakeTarget(OS.macOS, Architecture.arm64), 'aarch64-macos');
      });

      test('x64 maps to x86_64-macos', () {
        expect(cmakeTarget(OS.macOS, Architecture.x64), 'x86_64-macos');
      });
    });

    group('Linux', () {
      test('arm64 maps to aarch64-linux', () {
        expect(cmakeTarget(OS.linux, Architecture.arm64), 'aarch64-linux');
      });
    });

    group('Windows', () {
      test('x64 maps to x86_64-windows', () {
        expect(cmakeTarget(OS.windows, Architecture.x64), 'x86_64-windows');
      });
    });

    group('iOS', () {
      test('device arm64 maps to aarch64-ios', () {
        expect(
          cmakeTarget(OS.iOS, Architecture.arm64, iOSSdk: IOSSdk.iPhoneOS),
          'aarch64-ios',
        );
      });

      test('simulator arm64 maps to aarch64-ios-simulator', () {
        expect(
          cmakeTarget(
            OS.iOS,
            Architecture.arm64,
            iOSSdk: IOSSdk.iPhoneSimulator,
          ),
          'aarch64-ios-simulator',
        );
      });
    });

    group('Android', () {
      test('arm64 maps to aarch64-linux-android', () {
        expect(
          cmakeTarget(OS.android, Architecture.arm64),
          'aarch64-linux-android',
        );
      });

      test('arm maps to arm-linux-androideabi', () {
        expect(
          cmakeTarget(OS.android, Architecture.arm),
          'arm-linux-androideabi',
        );
      });
    });

    group('errors', () {
      test('throws ArgumentError for unsupported architectures', () {
        expect(
          () => cmakeTarget(OS.macOS, Architecture.riscv64),
          throwsArgumentError,
        );
      });

      test('throws ArgumentError for unsupported OS', () {
        expect(
          () => cmakeTarget(OS.fuchsia, Architecture.arm64),
          throwsArgumentError,
        );
      });
    });
  });

  group('BuildInputCMakeTarget.targetTriple', () {
    test('macOS arm64 input produces aarch64-macos triple', () {
      final input = createTestBuildInput();
      expect(input.targetTriple(), 'aarch64-macos');
    });

    test('macOS x64 input produces x86_64-macos triple', () {
      final input = createTestBuildInput(arch: Architecture.x64);
      expect(input.targetTriple(), 'x86_64-macos');
    });

    test('Linux arm64 input produces aarch64-linux triple', () {
      final input = createTestBuildInput(os: OS.linux);
      expect(input.targetTriple(), 'aarch64-linux');
    });

    test('Windows x64 input produces x86_64-windows triple', () {
      final input = createTestBuildInput(
        os: OS.windows,
        arch: Architecture.x64,
      );
      expect(input.targetTriple(), 'x86_64-windows');
    });

    test('Android arm64 input produces aarch64-linux-android triple', () {
      final input = createTestBuildInput(os: OS.android);
      expect(input.targetTriple(), 'aarch64-linux-android');
    });
  });
}
