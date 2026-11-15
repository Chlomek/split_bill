/// Route paths used across Split Bill navigation.
class RouteNames {
  RouteNames._();

  static const String home = '/';
  static const String invite = '/invite/:code';
  static const String paywall = '/paywall';

  static String groupDetail(String groupId) => '/group/$groupId';
  static String scanReceipt(String groupId) => '/group/$groupId/scan';
  static String assignItems(String groupId) => '/group/$groupId/assign-items';
}
