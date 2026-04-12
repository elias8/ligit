import 'dart:io';

import 'package:libgit2/libgit2.dart';

/// Creates a fresh temporary directory and returns its path.
///
/// Caller owns cleanup via [deleteTempDir] in `tearDown`/`addTearDown`.
String createTempDir() =>
    Directory.systemTemp.createTempSync('libgit2_test_').path;

/// Recursively deletes [path] on a best-effort basis.
void deleteTempDir(String path) {
  try {
    Directory(path).deleteSync(recursive: true);
  } on FileSystemException {
    // best effort cleanup
  }
}

/// Temporary git repository seeded with the system `git` CLI.
///
/// Owns a unique temp directory and tears it down on [dispose]. The
/// repository is initialized with `user.name` and `user.email` set so
/// commits succeed regardless of the host's git configuration.
///
/// ```dart
/// final git = GitFixture.init();
/// addTearDown(git.dispose);
/// final first = git.commit('initial', files: {'a.txt': 'hello'});
/// final repo = Repository.open(git.path);
/// ```
class GitFixture {
  /// Absolute path to the worktree root.
  final String path;

  /// Creates a new repository on the default branch [branch].
  factory GitFixture.init({String branch = 'main'}) {
    final dir = Directory.systemTemp.createTempSync('libgit2_test_').path;
    _run(['init', '-b', branch, dir]);
    _run(['-C', dir, 'config', 'user.name', 'Test']);
    _run(['-C', dir, 'config', 'user.email', 'test@example.com']);
    return GitFixture._(dir);
  }

  GitFixture._(this.path);

  /// Writes [files] into the worktree (creating parent directories as
  /// needed), stages every change, and commits with [message]. Returns
  /// the new commit's [Oid].
  Oid commit(String message, {Map<String, String> files = const {}}) {
    files.forEach(writeFile);
    git(['add', '--all']);
    git(['commit', '-m', message]);
    return oid('HEAD');
  }

  /// Recursively removes the worktree. Best-effort — swallows
  /// [FileSystemException] so teardown never masks a real failure.
  void dispose() {
    try {
      Directory(path).deleteSync(recursive: true);
    } on FileSystemException {
      // best effort
    }
  }

  /// Runs `git <args>` inside this worktree. Throws [StateError] on
  /// non-zero exit.
  ProcessResult git(List<String> args) => _run(['-C', path, ...args]);

  /// Resolves [spec] to an [Oid] via [revParse].
  Oid oid(String spec) => Oid.fromString(revParse(spec));

  /// Resolves [spec] to a full hex SHA via `git rev-parse`.
  String revParse(String spec) {
    return (git(['rev-parse', spec]).stdout as String).trim();
  }

  /// Writes [content] to [relative] inside the worktree without
  /// staging. Parent directories are created on demand.
  void writeFile(String relative, String content) {
    final file = File('$path/$relative');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  static ProcessResult _run(List<String> args) {
    final result = Process.runSync('git', args);
    if (result.exitCode != 0) {
      throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
    }
    return result;
  }
}
