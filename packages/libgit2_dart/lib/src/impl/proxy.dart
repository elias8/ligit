part of 'api.dart';

/// The type of proxy to use.
typedef ProxyType = Proxy;

/// Options describing how an outbound connection reaches a proxy.
///
/// Pass to [Remote.connect], [FetchOptions.proxy], or
/// [PushOptions.proxy] to route a fetch or push through a proxy.
///
/// ```dart
/// const opts = ProxyOptions.specified('http://proxy.corp:8080');
/// remote.fetch(options: FetchOptions(proxy: opts));
/// ```
@immutable
final class ProxyOptions {
  /// How the proxy is selected.
  final ProxyType type;

  /// The URL of the proxy, or null when [type] is [ProxyType.none]
  /// or [ProxyType.auto].
  final String? url;

  /// Do not attempt to connect through a proxy.
  ///
  /// When libgit2 is built against libcurl, libcurl itself may still
  /// pick up a proxy from the environment.
  const ProxyOptions.none() : type = ProxyType.none, url = null;

  /// Auto-detect the proxy from the git configuration.
  const ProxyOptions.auto() : type = ProxyType.auto, url = null;

  /// Connect via the given [url].
  const ProxyOptions.specified(this.url) : type = ProxyType.specified;

  ProxyOptionsRecord get _record => (type: type.value, url: url);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProxyOptions && type == other.type && url == other.url);

  @override
  int get hashCode => Object.hash(type, url);
}
