part of 'api.dart';

/// Signature of a [RemoteCallbacks.certificateCheck] handler.
///
/// Invoked when the server presents a certificate the transport
/// could not validate on its own. [valid] reports what the TLS/SSH
/// stack already concluded. Return `0` to proceed, a negative value
/// to fail the connection, or a positive value to honor the
/// existing validity decision.
typedef CertificateCheck =
    // ignore: avoid_positional_boolean_parameters
    int Function(Cert cert, bool valid, String host);

/// Signature of a [RemoteCallbacks.credentials] handler.
///
/// Fires when the remote requires authentication. [url] is the
/// resource being connected to, [usernameFromUrl] is any user
/// component embedded in it (`user@host`), and [allowedTypes] is
/// the set of [CredentialType] values the server advertises.
///
/// Return a [Credential] — the transport takes ownership of it —
/// or `null` to fall through to the default flow.
typedef CredentialAcquire =
    Credential? Function(
      String url,
      String? usernameFromUrl,
      Set<CredentialType> allowedTypes,
    );

/// Signature of a [RemoteCallbacks.sidebandProgress] handler.
///
/// Receives the text the server emits on the progress side-band
/// (e.g. `remote: Counting objects…`).
typedef SidebandProgress = int Function(String message);

/// Snapshot of fetch-side transfer progress.
typedef TransferProgress = IndexerProgress;

/// Signature of a [RemoteCallbacks.transferProgress] handler.
typedef TransferProgressCallback = int Function(TransferProgress stats);

/// Signature of a [RemoteCallbacks.pushTransferProgress] handler.
typedef PushTransferProgress = int Function(int current, int total, int bytes);

/// Signature of a [RemoteCallbacks.updateRefs] handler.
typedef UpdateRefs = int Function(String refname, Oid oldId, Oid newId);

/// Automatic tag following option.
typedef RemoteAutotag = RemoteAutotagOption;

/// A connection to a remote repository.
///
/// A [Remote] represents a persisted remote looked up by name with
/// [Remote.lookup], a newly created one registered with
/// [Remote.create], or a throwaway one built via
/// [Remote.createAnonymous] or [Remote.createDetached]. Fetch and
/// push traffic goes through [fetch]/[push]; [ls] and
/// [defaultBranch] require an open connection via [connect].
///
/// ```dart
/// final remote = Remote.lookup(repo, 'origin');
/// try {
///   remote.fetch(
///     options: FetchOptions(prune: FetchPrune.prune),
///     reflogMessage: 'sync',
///   );
///   for (final head in (remote..connect(Direction.fetch)).ls()) {
///     print('${head.oid} ${head.name}');
///   }
///   remote.disconnect();
/// } finally {
///   remote.dispose();
/// }
/// ```
@immutable
final class Remote {
  static final _finalizer = Finalizer<int>(remoteFree);

  final int _handle;

  /// Looks up the persisted remote named [name] in [repo].
  ///
  /// [name] is validated for consistency; see [Tag.create] for the
  /// rules about valid names.
  ///
  /// Throws [NotFoundException] when the remote does not exist, or
  /// [InvalidValueException] when [name] is malformed.
  factory Remote.lookup(Repository repo, String name) =>
      Remote._(remoteLookup(repo._handle, name));

  /// Adds a persisted remote named [name] pointing at [url] to the
  /// repository's configuration.
  ///
  /// When [fetchspec] is omitted the default
  /// `+refs/heads/*:refs/remotes/<name>/*` is installed.
  ///
  /// Throws [InvalidValueException] when [name] or [fetchspec] is
  /// malformed, or [ExistsException] when a remote with the same
  /// name already exists.
  factory Remote.create({
    required Repository repo,
    required String name,
    required String url,
    String? fetchspec,
  }) {
    final handle = fetchspec == null
        ? remoteCreate(repo._handle, name, url)
        : remoteCreateWithFetchspec(repo._handle, name, url, fetchspec);
    return Remote._(handle);
  }

  /// Creates an in-memory remote at [url] bound to [repo].
  ///
  /// The remote is not persisted to the repository's configuration;
  /// use when you only have a URL rather than a remote name.
  factory Remote.createAnonymous(Repository repo, String url) =>
      Remote._(remoteCreateAnonymous(repo._handle, url));

  /// Creates an in-memory remote at [url] with no associated
  /// repository.
  ///
  /// Unlike [Remote.createAnonymous], a detached remote does not
  /// consider any repo-level configuration (such as
  /// `url.*.insteadOf` substitutions).
  factory Remote.createDetached(String url) =>
      Remote._(remoteCreateDetached(url));

  /// Creates a remote with fine-grained control over the options.
  ///
  /// Pass [repo] as null for an in-memory remote. When [name] is
  /// non-null the remote is persisted to the repository's
  /// configuration; otherwise it stays anonymous. [fetchSpec]
  /// replaces the default fetch refspec list.
  ///
  /// Throws [InvalidValueException] when [name] or a refspec is
  /// malformed, or [ExistsException] when [name] conflicts with an
  /// existing remote.
  factory Remote.createWithOpts(
    String url, {
    Repository? repo,
    String? name,
    List<String> fetchSpec = const [],
  }) => Remote._(
    remoteCreateWithOpts(
      url,
      repoHandle: repo?._handle ?? 0,
      name: name,
      fetchSpec: fetchSpec,
    ),
  );

  /// Creates an independent copy of this remote.
  ///
  /// All internal strings are duplicated; callbacks are not.
  /// Callers must [dispose] the returned [Remote].
  Remote dup() => Remote._(remoteDup(_handle));

  Remote._(this._handle) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Whether [name] is a well-formed remote name.
  static bool nameIsValid(String name) => remoteNameIsValid(name);

  /// Name of this remote, or null when in-memory.
  String? get name => remoteName(_handle);

  /// Fetch URL of this remote.
  ///
  /// Reflects any `url.*.insteadOf` substitution configured for
  /// this URL, or an override set with [setInstanceUrl].
  String get url => remoteUrl(_handle);

  /// Push URL of this remote, or null when the fetch URL is used.
  ///
  /// Reflects any `url.*.pushInsteadOf` substitution, or an
  /// override set with [setInstancePushUrl].
  String? get pushUrl => remotePushurl(_handle);

  /// Fetch refspecs configured on this remote.
  List<String> get fetchRefspecs => remoteFetchRefspecs(_handle);

  /// Push refspecs configured on this remote.
  List<String> get pushRefspecs => remotePushRefspecs(_handle);

  /// Number of refspecs configured on this remote.
  int get refspecCount => remoteRefspecCount(_handle);

  /// Tag auto-follow setting for this remote.
  RemoteAutotag get autotag => RemoteAutotag.fromValue(remoteAutotag(_handle));

  /// Ref-prune setting for this remote, read from
  /// `remote.<name>.prune` or `fetch.prune`.
  bool get pruneEnabled => remotePruneRefs(_handle);

  /// Whether the underlying transport is connected.
  bool get isConnected => remoteConnected(_handle);

  /// Opens a connection to the remote.
  ///
  /// The transport is selected by URL; [direction] picks between
  /// `git-upload-pack` ([Direction.fetch]) and `git-receive-pack`
  /// ([Direction.push]) on the server side.
  ///
  /// Must be called before [ls] or [defaultBranch] will respond.
  void connect(
    Direction direction, {
    ProxyOptions? proxy,
    RemoteCallbacks? callbacks,
  }) => remoteConnect(
    _handle,
    direction.value,
    proxy: proxy?._record,
    callbacks: callbacks?._record,
  );

  /// Closes the open connection, if any.
  void disconnect() => remoteDisconnect(_handle);

  /// Cancels the in-flight operation.
  ///
  /// At certain checkpoints the network code observes cancellation
  /// and stops the operation.
  void stop() => remoteStop(_handle);

  /// Name of the remote's default branch.
  ///
  /// When the server does not advertise this directly, the same
  /// guess git performs is used: if multiple branches point at the
  /// same commit, the first one wins and `master` is preferred.
  ///
  /// Must be called after [connect].
  ///
  /// Throws [NotFoundException] when the remote has no references,
  /// or none point at HEAD's commit.
  String defaultBranch() => remoteDefaultBranch(_handle);

  /// References advertised by the server.
  ///
  /// The list becomes available as soon as [connect] is called and
  /// remains valid after [disconnect], until the next [connect].
  List<RemoteHead> ls() {
    return [for (final r in remoteLs(_handle)) RemoteHead._(r)];
  }

  /// Downloads new data and updates tips.
  ///
  /// Connects if not already connected, negotiates missing objects,
  /// downloads and indexes the packfile, then updates the
  /// remote-tracking branches and `FETCH_HEAD`.
  ///
  /// [refspecs] overrides the configured fetch refspecs when
  /// non-empty. [reflogMessage] replaces the default
  /// `fetch` / `fetch <name>` message written to each updated
  /// ref's reflog. Passing [options] when already connected
  /// discards the existing connection's options.
  void fetch({
    List<String> refspecs = const [],
    FetchOptions? options,
    String? reflogMessage,
  }) => remoteFetch(
    _handle,
    refspecs: refspecs,
    options: options?._record,
    reflogMessage: reflogMessage,
  );

  /// Performs a push.
  ///
  /// [refspecs] overrides the configured push refspecs when
  /// non-empty. Passing [options] when already connected discards
  /// the existing connection's options.
  void push({List<String> refspecs = const [], PushOptions? options}) =>
      remotePush(_handle, refspecs: refspecs, options: options?._record);

  /// Creates a packfile for [refspecs] and sends it to the server.
  ///
  /// Connects if necessary, negotiates which objects are missing,
  /// and uploads the packfile. Unlike [push], no remote-tracking
  /// refs are updated.
  void upload({List<String> refspecs = const [], PushOptions? options}) =>
      remoteUpload(_handle, refspecs: refspecs, options: options?._record);

  /// Updates the tips to the new state after a [download].
  ///
  /// [reflogMessage] replaces the default reflog entry; it is
  /// ignored for push. [downloadTags] must match the value passed
  /// to [download].
  void updateTips({
    int updateFlags = 1,
    RemoteAutotag downloadTags = RemoteAutotag.auto,
    String? reflogMessage,
  }) => remoteUpdateTips(
    _handle,
    updateFlags: updateFlags,
    downloadTags: downloadTags.value,
    reflogMessage: reflogMessage,
  );

  /// Prunes tracking refs that are no longer present on the remote.
  void prune() => remotePrune(_handle);

  /// Downloads and indexes the packfile for [refspecs] without
  /// updating any refs.
  ///
  /// [refspecs] overrides the configured fetch refspecs when
  /// non-empty. Use [updateTips] afterwards to install the
  /// downloaded objects as remote-tracking refs.
  void download([List<String> refspecs = const []]) =>
      remoteDownload(_handle, refspecs);

  /// Path of the repository that owns this remote, or null when the
  /// remote is detached.
  ///
  /// libgit2 loans the repository handle back to the remote, so the
  /// full [Repository] cannot be rewrapped safely. Re-open the repo
  /// with [Repository.open] if a disposable handle is needed.
  String? get ownerPath {
    final addr = remoteOwner(_handle);
    if (addr == 0) return null;
    return repositoryPath(addr);
  }

  /// Overrides the fetch URL for this instance only.
  ///
  /// The URL in the configuration is ignored and left unchanged.
  void setInstanceUrl(String url) => remoteSetInstanceUrl(_handle, url);

  /// Overrides the push URL for this instance only.
  ///
  /// The URL in the configuration is ignored and left unchanged.
  void setInstancePushUrl(String url) => remoteSetInstancePushUrl(_handle, url);

  /// Transfer counters filled in by the last fetch, or null when no
  /// transfer has run.
  TransferProgressRecord? get stats => remoteStats(_handle);

  /// Releases the native remote.
  ///
  /// Also disconnects from the server if still connected.
  void dispose() {
    _finalizer.detach(this);
    remoteFree(_handle);
  }
}

/// Remote management on [Repository].
extension RepositoryRemote on Repository {
  /// Names of every persisted remote on this repository.
  List<String> remoteNames() => remoteList(_handle);

  /// Deletes the persisted remote named [name].
  ///
  /// All remote-tracking branches and configuration settings for
  /// the remote are removed.
  void deleteRemote(String name) => remoteDelete(_handle, name);

  /// Renames the persisted remote [from] to [to].
  ///
  /// All remote-tracking branches and configuration settings for
  /// the remote are updated. Already-loaded [Remote] instances keep
  /// their existing name and refspec list.
  ///
  /// Returns the refspecs that could not be automatically migrated
  /// because they were non-default.
  ///
  /// Throws [InvalidValueException] when [to] is malformed, or
  /// [ExistsException] when a remote with [to] already exists.
  List<String> renameRemote(String from, String to) =>
      remoteRename(_handle, from, to);

  /// Sets the fetch URL for the persisted remote named [name].
  ///
  /// Assumes a single-URL remote; in-memory [Remote] instances are
  /// not affected.
  void setRemoteUrl(String name, String url) =>
      remoteSetUrl(_handle, name, url);

  /// Sets the push URL for the persisted remote named [name].
  ///
  /// Assumes a single-URL remote; in-memory [Remote] instances are
  /// not affected.
  void setRemotePushUrl(String name, String url) =>
      remoteSetPushurl(_handle, name, url);

  /// Appends [refspec] to the fetch refspecs of the persisted
  /// remote named [name].
  ///
  /// In-memory [Remote] instances are not affected.
  ///
  /// Throws [InvalidValueException] when [refspec] is malformed.
  void addRemoteFetch(String name, String refspec) =>
      remoteAddFetch(_handle, name, refspec);

  /// Appends [refspec] to the push refspecs of the persisted remote
  /// named [name].
  ///
  /// In-memory [Remote] instances are not affected.
  ///
  /// Throws [InvalidValueException] when [refspec] is malformed.
  void addRemotePush(String name, String refspec) =>
      remoteAddPush(_handle, name, refspec);

  /// Sets the tag-following rule for the persisted remote named
  /// [name].
  ///
  /// The change is written to configuration; in-memory [Remote]
  /// instances are not affected.
  void setRemoteAutotag(String name, RemoteAutotag rule) =>
      remoteSetAutotag(_handle, name, rule.value);
}

/// A reference advertised by a remote, as returned by [Remote.ls].
@immutable
final class RemoteHead {
  /// Whether the server reports this ref is stored locally.
  final bool local;

  /// OID advertised by the server.
  final Oid oid;

  /// Local OID at this ref, or the zero OID when unknown.
  final Oid localOid;

  /// Full ref name (e.g. `refs/heads/main`).
  final String name;

  /// Target of a symbolic ref when the server sent a symref
  /// mapping, or null for a regular ref.
  final String? symrefTarget;

  const RemoteHead._raw({
    required this.local,
    required this.oid,
    required this.localOid,
    required this.name,
    required this.symrefTarget,
  });

  factory RemoteHead._(RemoteHeadRecord r) => RemoteHead._raw(
    local: r.local,
    oid: Oid._(r.oid),
    localOid: Oid._(r.loid),
    name: r.name,
    symrefTarget: r.symrefTarget,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteHead &&
          local == other.local &&
          oid == other.oid &&
          localOid == other.localOid &&
          name == other.name &&
          symrefTarget == other.symrefTarget);

  @override
  int get hashCode => Object.hash(local, oid, localOid, name, symrefTarget);
}

/// Options controlling a [Remote.fetch].
@immutable
final class FetchOptions {
  /// Whether the fetch prunes remote-tracking branches whose
  /// upstream no longer exists.
  final FetchPrune prune;

  /// Rule selecting which tags are downloaded along with the
  /// objects.
  final RemoteAutotag downloadTags;

  /// Shallow-fetch depth; `0` or negative requests full history.
  final int depth;

  /// Whether to update `FETCH_HEAD` to point at the fetched tip.
  final bool updateFetchhead;

  /// Extra HTTP headers sent with the request.
  final List<String> customHeaders;

  /// Proxy routing for the outbound connection.
  final ProxyOptions? proxy;

  /// Callbacks fired during the fetch.
  final RemoteCallbacks? callbacks;

  const FetchOptions({
    this.prune = FetchPrune.pruneUnspecified,
    this.downloadTags = RemoteAutotag.unspecified,
    this.depth = 0,
    this.updateFetchhead = true,
    this.customHeaders = const [],
    this.proxy,
    this.callbacks,
  });

  FetchOptionsRecord get _record => (
    prune: prune.value,
    downloadTags: downloadTags.value,
    depth: depth,
    updateFetchhead: updateFetchhead,
    customHeaders: customHeaders,
    proxy: proxy?._record,
    callbacks: callbacks?._record,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FetchOptions &&
          prune == other.prune &&
          downloadTags == other.downloadTags &&
          depth == other.depth &&
          updateFetchhead == other.updateFetchhead &&
          _listEq(customHeaders, other.customHeaders) &&
          proxy == other.proxy &&
          callbacks == other.callbacks);

  @override
  int get hashCode => Object.hash(
    prune,
    downloadTags,
    depth,
    updateFetchhead,
    Object.hashAll(customHeaders),
    proxy,
    callbacks,
  );
}

/// Options controlling a [Remote.push].
@immutable
final class PushOptions {
  /// Number of packbuilder worker threads. `0` auto-detects.
  final int pbParallelism;

  /// Extra HTTP headers sent with the request.
  final List<String> customHeaders;

  /// Push options forwarded to the server, as with `git push
  /// --push-option`.
  final List<String> remotePushOptions;

  /// Proxy routing for the outbound connection.
  final ProxyOptions? proxy;

  /// Callbacks fired during the push.
  final RemoteCallbacks? callbacks;

  const PushOptions({
    this.pbParallelism = 1,
    this.customHeaders = const [],
    this.remotePushOptions = const [],
    this.proxy,
    this.callbacks,
  });

  PushOptionsRecord get _record => (
    pbParallelism: pbParallelism,
    customHeaders: customHeaders,
    remotePushOptions: remotePushOptions,
    proxy: proxy?._record,
    callbacks: callbacks?._record,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PushOptions &&
          pbParallelism == other.pbParallelism &&
          _listEq(customHeaders, other.customHeaders) &&
          _listEq(remotePushOptions, other.remotePushOptions) &&
          proxy == other.proxy &&
          callbacks == other.callbacks);

  @override
  int get hashCode => Object.hash(
    pbParallelism,
    Object.hashAll(customHeaders),
    Object.hashAll(remotePushOptions),
    proxy,
    callbacks,
  );
}

/// Callbacks fired while a remote operation is in progress.
///
/// Every slot is optional; unset slots fall through to the default
/// behavior. See [certificateCheck] for the TLS/SSH verification
/// hook and [credentials] for the authentication hook.
@immutable
final class RemoteCallbacks {
  /// Fires on each certificate the transport cannot validate on
  /// its own.
  final CertificateCheck? certificateCheck;

  /// Fires when the remote requires authentication.
  ///
  /// The returned [Credential] is taken over by the transport;
  /// returning null falls through to the default flow. Ignored when
  /// [builtinUserpass] is set.
  final CredentialAcquire? credentials;

  /// Installs the stock username/password credential acquirer
  /// natively, bypassing the Dart callback trampoline.
  ///
  /// Prefer this over a hand-rolled [credentials] closure when the
  /// credential is a fixed username/password pair: the native
  /// acquirer is invoked directly with no Dart hop per challenge.
  final ({String username, String password})? builtinUserpass;

  /// Fires for each line the remote emits on the progress
  /// side-band (e.g. `remote: Counting objects…`).
  final SidebandProgress? sidebandProgress;

  /// Fires periodically during a fetch with current indexer
  /// progress.
  final TransferProgressCallback? transferProgress;

  /// Fires periodically during a push with object and byte
  /// counters.
  final PushTransferProgress? pushTransferProgress;

  /// Fires for every remote-tracking ref a fetch updates locally.
  final UpdateRefs? updateRefs;

  const RemoteCallbacks({
    this.certificateCheck,
    this.credentials,
    this.builtinUserpass,
    this.sidebandProgress,
    this.transferProgress,
    this.pushTransferProgress,
    this.updateRefs,
  });

  RemoteCallbacksRecord get _record => (
    builtinUserpass: builtinUserpass,
    certificateCheck: certificateCheck == null
        ? null
        : (address, valid, host) =>
              certificateCheck!(Cert._fromAddress(address), valid, host),
    credentials: credentials == null
        ? null
        : (url, username, allowed) {
            final cred = credentials!(url, username, _decodeCredTypes(allowed));
            if (cred == null) return 0;
            cred._handOffToLibgit2();
            return cred._handle;
          },
    sidebandProgress: sidebandProgress,
    transferProgress: transferProgress == null
        ? null
        : (stats) => transferProgress!(
            IndexerProgress._(
              totalObjects: stats.totalObjects,
              indexedObjects: stats.indexedObjects,
              receivedObjects: stats.receivedObjects,
              localObjects: stats.localObjects,
              totalDeltas: stats.totalDeltas,
              indexedDeltas: stats.indexedDeltas,
              receivedBytes: stats.receivedBytes,
            ),
          ),
    pushTransferProgress: pushTransferProgress,
    updateRefs: updateRefs == null
        ? null
        : (refname, oldId, newId) =>
              updateRefs!(refname, Oid._(oldId), Oid._(newId)),
  );
}

Set<CredentialType> _decodeCredTypes(int bits) => {
  for (final v in CredentialType.values)
    if ((bits & v.value) != 0) v,
};
