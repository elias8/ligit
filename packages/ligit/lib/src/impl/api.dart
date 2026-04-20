/// Internal: the unified Dart API library.
///
/// All idiomatic wrapper classes are declared as `part` files of this library
/// so that their underscore-prefixed handles, fields, and constructors are
/// truly private to the package. Cross-class access happens through these
/// private members directly, never through public accessors that would let
/// FFI types or raw handles escape `package:ligit`.
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../bindings/annotated_commit.dart';
import '../bindings/apply.dart' as apply_bindings;
import '../bindings/apply.dart' show ApplyLocation;
import '../bindings/attr.dart';
import '../bindings/blame.dart';
import '../bindings/blob.dart';
import '../bindings/branch.dart';
import '../bindings/cert.dart';
import '../bindings/checkout.dart' as bindings_checkout;
import '../bindings/checkout.dart' show CheckoutStrategy;
import '../bindings/cherry_pick.dart' as cp;
import '../bindings/clone.dart' as clone_bindings;
import '../bindings/clone.dart' show CloneLocal;
import '../bindings/commit.dart';
import '../bindings/common.dart';
import '../bindings/config.dart';
import '../bindings/credential.dart';
import '../bindings/describe.dart';
import '../bindings/diff.dart';
import '../bindings/email.dart';
import '../bindings/errors.dart';
import '../bindings/filter.dart';
import '../bindings/global.dart';
import '../bindings/graph.dart';
import '../bindings/ignore.dart';
import '../bindings/index.dart';
import '../bindings/indexer.dart';
import '../bindings/mailmap.dart';
import '../bindings/merge.dart';
import '../bindings/message.dart';
import '../bindings/net.dart';
import '../bindings/notes.dart';
import '../bindings/object.dart';
import '../bindings/odb.dart';
import '../bindings/odb_backend.dart';
import '../bindings/oid.dart';
import '../bindings/pack.dart';
import '../bindings/patch.dart';
import '../bindings/pathspec.dart';
import '../bindings/proxy.dart';
import '../bindings/rebase.dart';
import '../bindings/refdb.dart';
import '../bindings/reflog.dart';
import '../bindings/refs.dart';
import '../bindings/refspec.dart';
import '../bindings/remote.dart';
import '../bindings/repository.dart';
import '../bindings/reset.dart' as rst;
import '../bindings/rev_parse.dart' as rp;
import '../bindings/revert.dart' as rv;
import '../bindings/revwalk.dart';
import '../bindings/signature.dart';
import '../bindings/stash.dart';
import '../bindings/status.dart';
import '../bindings/submodule.dart';
import '../bindings/tag.dart';
import '../bindings/trace.dart';
import '../bindings/transaction.dart';
import '../bindings/tree.dart';
import '../bindings/version.dart';
import '../bindings/worktree.dart';

export '../ffi/libgit2_enums.g.dart'
    show
        ApplyLocation,
        BlameFlag,
        CertSshRawType,
        CheckoutStrategy,
        CloneLocal,
        ConfigLevel,
        DescribeStrategy,
        DiffFlag,
        DiffFormat,
        DiffOption,
        DiffStatsFormat,
        FetchPrune,
        FilterFlag,
        FilterMode,
        IndexAddOption,
        IndexCapability,
        IndexStage,
        MergeAnalysis,
        MergeFileFavor,
        MergeFileFlag,
        MergeFlag,
        MergePreference,
        PackbuilderStage,
        PathspecFlag,
        RepositoryItem,
        RepositoryOpenFlag,
        RepositoryState,
        StatusShow,
        SubmoduleIgnore,
        SubmoduleRecurse,
        SubmoduleStatus,
        SubmoduleUpdate,
        TraceLevel;

part 'annotated_commit.dart';
part 'apply.dart';
part 'attr.dart';
part 'blame.dart';
part 'blob.dart';
part 'branch.dart';
part 'cert.dart';
part 'checkout.dart';
part 'cherry_pick.dart';
part 'commit.dart';
part 'config.dart';
part 'credential.dart';
part 'describe.dart';
part 'diff.dart';
part 'email.dart';
part 'errors.dart';
part 'filter.dart';
part 'global.dart';
part 'graph.dart';
part 'ignore.dart';
part 'index.dart';
part 'indexer.dart';
part 'mailmap.dart';
part 'merge.dart';
part 'message.dart';
part 'net.dart';
part 'notes.dart';
part 'object.dart';
part 'odb.dart';
part 'odb_backend.dart';
part 'oid.dart';
part 'pack.dart';
part 'patch.dart';
part 'pathspec.dart';
part 'proxy.dart';
part 'rebase.dart';
part 'refdb.dart';
part 'reflog.dart';
part 'refs.dart';
part 'refspec.dart';
part 'remote.dart';
part 'repository.dart';
part 'reset.dart';
part 'rev_parse.dart';
part 'revert.dart';
part 'revwalk.dart';
part 'signature.dart';
part 'stash.dart';
part 'status.dart';
part 'submodule.dart';
part 'tag.dart';
part 'trace.dart';
part 'transaction.dart';
part 'tree.dart';
part 'version.dart';
part 'worktree.dart';
