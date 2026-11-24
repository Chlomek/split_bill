import 'package:intl/intl.dart';

/// Helper for standard currency and number formatting across Split Bill.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formats an amount with currency symbol or code.
  static String format(
    double amount, {
    String currency = 'CZK',
    String locale = 'cs_CZ',
  }) {
    final format = NumberFormat.currency(
      locale: locale,
      name: currency,
      symbol: currency == 'CZK' ? 'Kč' : null,
      decimalDigits: 2,
    );
    return format.format(amount);
  }

  /// Short form used in the design: "1 284 Kč", or "84,60 Kč" when the
  /// amount has hellers. With [signed], positive amounts get "+" and
  /// negative ones a real minus sign ("−450 Kč").
  static String compact(double amount, {bool signed = false}) {
    final rounded = (amount * 100).round() / 100;
    final whole = rounded == rounded.roundToDouble();
    final number = NumberFormat.decimalPatternDigits(
      locale: 'cs_CZ',
      decimalDigits: whole ? 0 : 2,
    ).format(rounded.abs());
    final sign = !signed || rounded == 0
        ? (rounded < 0 ? '−' : '')
        : (rounded > 0 ? '+' : '−');
    return '$sign$number Kč';
  }

  /// Parses user input such as "1 250,50" or "85"; returns null if invalid.
  static double? tryParse(String input) {
    final cleaned = input.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}
