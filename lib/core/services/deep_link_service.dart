/// Service for constructing and parsing group invitation deep links.
class DeepLinkService {
  final String appDomain;
  final String customScheme;

  const DeepLinkService({
    this.appDomain = 'splitbill.app',
    this.customScheme = 'splitbill',
  });

  /// Constructs an HTTPS Universal Link or App Link.
  String buildInviteUniversalLink(String inviteCode) {
    return 'https://$appDomain/invite/$inviteCode';
  }

  /// Constructs a custom URL scheme link.
  String buildInviteCustomSchemeLink(String inviteCode) {
    return '$customScheme://invite/$inviteCode';
  }

  /// Extracts the invite code from an incoming deep link URI.
  static String? extractInviteCode(Uri uri) {
    if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'invite') {
      if (uri.pathSegments.length > 1) {
        return uri.pathSegments[1];
      }
    }
    // Also check query parameter fallback ?invite=CODE
    return uri.queryParameters['invite'];
  }
}
