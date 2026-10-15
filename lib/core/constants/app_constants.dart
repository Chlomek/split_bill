/// Core application-wide constants and business rules.
class AppConstants {
  AppConstants._();

  /// Maximum number of active groups allowed on the Free tier.
  static const int maxFreeGroups = 2;

  /// Monthly quota for high-precision AI receipt scans for Free users.
  static const int freeMonthlyAiScans = 5;

  /// Default currency code.
  static const String defaultCurrency = 'CZK';

  /// Supported currencies for Split Bill.
  static const List<String> supportedCurrencies = ['CZK', 'EUR', 'USD'];

  /// Entitlement ID configured in RevenueCat for premium status.
  static const String premiumEntitlementId = 'premium';
}
