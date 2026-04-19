# libgit2_dart

Idiomatic Dart bindings to [libgit2](https://libgit2.org), the portable C
implementation of Git.

| Android | iOS | macOS | Linux | Windows |
|:-------:|:---:|:-----:|:-----:|:-------:|
|    yes  | yes |  yes  |  yes  |   yes   |

## Getting started

```yaml
# pubspec.yaml
dependencies:
  libgit2_dart: ^0.0.1
```

The build hook fetches a prebuilt native library from GitHub Releases by
default. To build from source instead, set the workspace user-define:

```yaml
hooks:
  user_defines:
    libgit2_dart:
      source: compile  # uses CMake; requires cmake + a C compiler on PATH
```

For local development against an existing libgit2 checkout, set the
`LIBGIT2_SRC` environment variable to its path.

## Status

This package is in active early development. The API surface mirrors the
[libgit2 reference](https://libgit2.org/docs/reference/main/) and grows
incrementally.
