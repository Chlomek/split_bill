import 'package:intl/intl.dart';

/// Helper for standard currency and number formatting across Split Bill.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formats an amount with currency symbol or code.
  static String format(double amount, {String currency = 'CZK', String locale = 'cs_CZ'}) {
    final format = NumberFormat.currency(
      locale: locale,
      name: currency,
      symbol: currency == 'CZK' ? 'Kč' : null,
      decimalDigits: 2,
    );
    return format.format(amount);
  }
}
