# ligit

[![pub](https://img.shields.io/pub/v/ligit.svg)](https://pub.dev/packages/ligit)
[![ci](https://github.com/elias8/libgit2/actions/workflows/ci.yml/badge.svg)](https://github.com/elias8/libgit2/actions/workflows/ci.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Idiomatic Dart bindings to [libgit2](https://libgit2.org), the portable C
implementation of Git. Open, inspect, and manipulate repositories without
shelling out to `git`.

| Android | iOS | macOS | Linux | Windows |
|:-------:|:---:|:-----:|:-----:|:-------:|
|    ✓    |  ✓  |   ✓   |   ✓   |    ✓    |

## Why another one?

The existing Dart bindings I looked at were either unmaintained for years,
incomplete, or still on the old native-asset plumbing. I wanted a complete
binding of the libgit2 C API in idiomatic Dart, built on the current Dart
build hook system, so it's ready for an upcoming project of mine. This is
that.

## Install

```yaml
# pubspec.yaml
dependencies:
  ligit: ^0.0.1
```

## Usage

```dart
import 'dart:io';
import 'package:ligit/ligit.dart';

void main() {
  Libgit2.init();
  try {
    final repo = Repository.init('/tmp/demo');
    File('/tmp/demo/README.md').writeAsStringSync('# hi\n');

    final index = repo.index();
    index.addByPath('README.md');
    index.write();
    final treeId = index.writeTree();
    index.dispose();

    final sig = Signature.now(name: 'Ada', email: 'ada@example.com');
    final tree = Tree.lookup(repo, treeId);
    final head = Commit.create(
      repo: repo,
      updateRef: 'HEAD',
      author: sig,
      committer: sig,
      message: 'initial commit\n',
      tree: tree,
    );
    tree.dispose();
    repo.dispose();

    print('HEAD: ${head.sha}');
  } finally {
    Libgit2.shutdown();
  }
}
```

## Development

By default the build hook downloads a SHA256 verified prebuilt binary from
this repo's GitHub releases. When working on the package itself, override
the `source` user-define: `compile` builds from source with CMake; `system`
uses the OS installed libgit2.

```yaml
hooks:
  user_defines:
    ligit:
      source: compile
```

The pinned C-library tag lives in [`libgit2.version`](libgit2.version).

## License

MIT. See [LICENSE](LICENSE).
