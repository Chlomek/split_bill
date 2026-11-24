import 'package:intl/intl.dart';

/// Small Czech text helpers shared by the screens.
class TextFormatter {
  TextFormatter._();

  /// "Dnes", "Včera" or a short numeric date.
  static String relativeDate(DateTime date, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final days = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(date.year, date.month, date.day)).inDays;
    if (days == 0) return 'Dnes';
    if (days == 1) return 'Včera';
    return DateFormat('d. M. yyyy').format(date);
  }

  /// Czech plural: [one] for 1, [few] for 2-4, [many] otherwise.
  static String plural(int count, String one, String few, String many) {
    if (count == 1) return '1 $one';
    if (count >= 2 && count <= 4) return '$count $few';
    return '$count $many';
  }

  /// "1 člověk", "3 lidé", "5 lidí".
  static String people(int count) => plural(count, 'člověk', 'lidé', 'lidí');

  /// "1 výdaj", "3 výdaje", "5 výdajů".
  static String expenses(int count) =>
      plural(count, 'výdaj', 'výdaje', 'výdajů');

  /// "Dnes 21:14", "Včera 18:02" or "12. 11. 2026".
  static String dateTime(DateTime date, {DateTime? now}) {
    final day = relativeDate(date, now: now);
    if (day == 'Dnes' || day == 'Včera') {
      return '$day ${DateFormat('H:mm').format(date)}';
    }
    return day;
  }

  /// "1 člen", "3 členové", "5 členů".
  static String memberCount(int count) {
    if (count == 1) return '1 člen';
    if (count >= 2 && count <= 4) return '$count členové';
    return '$count členů';
  }
}
