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

  /// Parses user input such as "1 250,50" or "85"; returns null if invalid.
  static double? tryParse(String input) {
    final cleaned = input.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}
