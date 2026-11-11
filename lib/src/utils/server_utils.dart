class ServerUtils {
  static const String officialHostKeyword = 'api.asmr';
  static const String defaultRemoteHost = 'https://api.asmr-200.com';
  static const String defaultLocalHost = 'localhost:8888';

  /// 官方 API 域名，登录要 POST /api/auth/me 换 token。
  static const List<String> officialHosts = [
    'api.asmr-200.com',
    'api.asmr.one',
    'api.asmr-100.com',
    'api.asmr-300.com',
  ];

  /// 内置第三方 Kikoeru 站点。根域名就是 API，不带 api. 前缀。
  static const List<String> builtinSiteHosts = [
    'asmr.unikon.art',
    'asmr.emoe.top',
  ];

  /// 服务器地址下拉里的预置项：官方域名在前，第三方站点在后。
  static const List<String> preferredHosts = [
    ...officialHosts,
    ...builtinSiteHosts,
  ];

  /// 服务器类型。
  ///
  /// - normal：正常账号，POST /api/auth/me 换 token。
  /// - guestToken：只用 guest/guest 换 token。
  /// - noToken：接口不校验 token，POST 会被 Cloudflare 拦，本地建 guest 即可。
  static const List<String> guestTokenHosts = ['asmr.homes'];
  static const List<String> noTokenHosts = [
    'asmr.unikon.art',
    'asmr.emoe.top',
  ];

  enum HostKind { normal, guestToken, noToken }

  static HostKind hostKind(String? host) {
    if (host == null || host.isEmpty) {
      return HostKind.normal;
    }
    final lower = host.toLowerCase();
    if (noTokenHosts.any((h) => lower.contains(h))) {
      return HostKind.noToken;
    }
    if (guestTokenHosts.any((h) => lower.contains(h))) {
      return HostKind.guestToken;
    }
    return HostKind.normal;
  }

  /// 不发登录请求也能用的站点。POST 会被 Cloudflare 拦。
  static bool isNoTokenHost(String? host) =>
      hostKind(host) == HostKind.noToken;

  /// 需要 guests 自己换 token 的站点。
  static bool isGuestTokenHost(String? host) =>
      hostKind(host) == HostKind.guestToken;

  /// Checks if the provided host string corresponds to the official server.
  static bool isOfficialServer(String? host) {
    if (host == null || host.isEmpty) return false;
    return host.contains(officialHostKeyword);
  }
}
