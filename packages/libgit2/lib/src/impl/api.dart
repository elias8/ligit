/// Internal: the unified Dart API library.
///
/// All idiomatic wrapper classes are declared as `part` files of this library
/// so that their underscore-prefixed handles, fields, and constructors are
/// truly private to the package. Cross-class access happens through these
/// private members directly, never through public accessors that would let
/// FFI types or raw handles escape `package:libgit2`.
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../bindings/annotated_commit.dart';
import '../bindings/cert.dart';
import '../bindings/commit.dart';
import '../bindings/common.dart';
import '../bindings/config.dart';
import '../bindings/credential.dart';
import '../bindings/global.dart';
import '../bindings/index.dart';
import '../bindings/indexer.dart';
import '../bindings/mailmap.dart';
import '../bindings/message.dart';
import '../bindings/net.dart';
import '../bindings/object.dart';
import '../bindings/odb.dart';
import '../bindings/oid.dart';
import '../bindings/proxy.dart';
import '../bindings/refdb.dart';
import '../bindings/reflog.dart';
import '../bindings/refs.dart';
import '../bindings/refspec.dart';
import '../bindings/repository.dart';
import '../bindings/rev_parse.dart' as rp;
import '../bindings/signature.dart';
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
part 'cert.dart';
part 'commit.dart';
part 'config.dart';
part 'credential.dart';
part 'global.dart';
part 'index.dart';
part 'indexer.dart';
part 'mailmap.dart';
part 'message.dart';
part 'net.dart';
part 'object.dart';
part 'odb.dart';
part 'oid.dart';
part 'proxy.dart';
part 'refdb.dart';
part 'reflog.dart';
part 'refs.dart';
part 'refspec.dart';
part 'repository.dart';
part 'rev_parse.dart';
part 'signature.dart';
part 'trace.dart';
part 'transaction.dart';
part 'tree.dart';
part 'version.dart';
part 'worktree.dart';
