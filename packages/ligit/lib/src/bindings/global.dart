import '../ffi/libgit2.g.dart';
import 'types/result.dart';

int libgit2Init() {
  final result = git_libgit2_init();
  checkCode(result);
  return result;
}

int libgit2Shutdown() {
  final result = git_libgit2_shutdown();
  checkCode(result);
  return result;
}
