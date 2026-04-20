import 'dart:io';

import 'package:ligit/ligit.dart';

void main() {
  Libgit2.init();
  try {
    final tmp = Directory.systemTemp.createTempSync('ligit_example_');
    print('repo: ${tmp.path}');

    final repo = Repository.init(tmp.path);
    try {
      File('${tmp.path}/README.md').writeAsStringSync('# hello libgit2\n');

      final index = repo.index();
      index.addByPath('README.md');
      index.write();
      final treeId = index.writeTree();
      index.dispose();

      final author = Signature.now(name: 'Example', email: 'e@example.com');
      final tree = Tree.lookup(repo, treeId);
      final headOid = Commit.create(
        repo: repo,
        updateRef: 'HEAD',
        author: author,
        committer: author,
        message: 'initial commit\n',
        tree: tree,
      );
      tree.dispose();

      print('HEAD: ${headOid.sha}');
    } finally {
      repo.dispose();
      tmp.deleteSync(recursive: true);
    }
  } finally {
    Libgit2.shutdown();
  }
}
