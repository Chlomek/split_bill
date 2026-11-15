import 'package:intl/intl.dart';

/// Small Czech text helpers shared by the screens.
class TextFormatter {
  TextFormatter._();

  /// "Dnes", "Včera" or a short numeric date.
  static String relativeDate(DateTime date, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final days = DateTime(today.year, today.month, today.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (days == 0) return 'Dnes';
    if (days == 1) return 'Včera';
    return DateFormat('d. M. yyyy').format(date);
  }

  /// "1 člen", "3 členové", "5 členů".
  static String memberCount(int count) {
    if (count == 1) return '1 člen';
    if (count >= 2 && count <= 4) return '$count členové';
    return '$count členů';
  }
}
