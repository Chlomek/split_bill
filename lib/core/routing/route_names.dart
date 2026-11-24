/// Route paths used across Split Bill navigation.
class RouteNames {
  RouteNames._();

  static const String home = '/';
  static const String invite = '/invite/:code';
  static const String paywall = '/paywall';

  static String groupDetail(String groupId) => '/group/$groupId';
  static String scanReceipt(String groupId) => '/group/$groupId/scan';
  static String assignItems(String groupId) => '/group/$groupId/assign-items';
  static String expenseDetail(String groupId, String expenseId) =>
      '/group/$groupId/expense/$expenseId';

  /// QR payment screen, starting with the debt of [fromMemberId].
  static String qrPayment(String groupId, {String? fromMemberId}) =>
      '/group/$groupId/qr'
      '${fromMemberId == null ? '' : '?from=$fromMemberId'}';
}
