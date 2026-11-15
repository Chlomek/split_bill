import '../../features/receipt_scan/domain/scanned_receipt_item.dart';

/// Turns an expense into per-member shares.
///
/// All arithmetic is done in minor units (haléře / cents) so the shares
/// always add up exactly to the expense total, with no floating point drift.
class SplitCalculator {
  SplitCalculator._();

  static int toMinor(double amount) => (amount * 100).round();

  static double fromMinor(int minor) => minor / 100.0;

  /// Splits [total] evenly between [memberIds]. Leftover minor units go to
  /// the first members in the list, one each.
  static Map<String, double> equalSplit(double total, List<String> memberIds) {
    final ids = memberIds.toSet().toList();
    if (ids.isEmpty) {
      throw ArgumentError('At least one member is required for a split.');
    }
    return _toAmounts(_divide(toMinor(total), ids));
  }

  /// Splits receipt [items] between the members assigned to each item.
  ///
  /// When [scannedTotal] differs from the sum of the items (tip, service
  /// charge, rounding), the difference is distributed proportionally to each
  /// member's subtotal. Every item must have at least one assigned member.
  static Map<String, double> splitItems({
    required List<ScannedReceiptItem> items,
    double? scannedTotal,
  }) {
    final subtotals = <String, int>{};

    for (final item in items) {
      final assignees = item.assignedMemberIds.toSet().toList();
      if (assignees.isEmpty) {
        throw ArgumentError('Item "${item.name}" has no assigned member.');
      }
      final itemTotal = toMinor(item.price * item.quantity);
      _divide(itemTotal, assignees).forEach((memberId, share) {
        subtotals[memberId] = (subtotals[memberId] ?? 0) + share;
      });
    }

    if (subtotals.isEmpty) return {};

    final itemsTotal = subtotals.values.fold<int>(0, (sum, v) => sum + v);
    final target = scannedTotal != null ? toMinor(scannedTotal) : itemsTotal;
    final difference = target - itemsTotal;

    if (difference != 0) {
      _distributeDifference(subtotals, difference, itemsTotal);
    }

    return _toAmounts(subtotals);
  }

  /// Divides [total] into equal integer parts; the remainder is handed out
  /// one unit at a time from the start of [ids].
  static Map<String, int> _divide(int total, List<String> ids) {
    final base = (total / ids.length).floor();
    final remainder = total - base * ids.length;
    return {
      for (var i = 0; i < ids.length; i++) ids[i]: base + (i < remainder ? 1 : 0),
    };
  }

  static void _distributeDifference(
    Map<String, int> subtotals,
    int difference,
    int itemsTotal,
  ) {
    final ids = subtotals.keys.toList();

    if (itemsTotal <= 0) {
      // No meaningful proportions to follow, share the difference evenly.
      _divide(difference, ids).forEach((id, part) {
        subtotals[id] = subtotals[id]! + part;
      });
      return;
    }

    final parts = <String, int>{
      for (final id in ids)
        id: (difference * subtotals[id]! / itemsTotal).floor(),
    };
    var leftover = difference - parts.values.fold<int>(0, (sum, v) => sum + v);

    // Hand the remaining units to the largest shares first.
    final bySize = [...ids]
      ..sort((a, b) => subtotals[b]!.compareTo(subtotals[a]!));
    for (var i = 0; leftover > 0; i = (i + 1) % bySize.length) {
      parts[bySize[i]] = parts[bySize[i]]! + 1;
      leftover--;
    }

    for (final id in ids) {
      subtotals[id] = subtotals[id]! + parts[id]!;
    }
  }

  static Map<String, double> _toAmounts(Map<String, int> minor) =>
      minor.map((id, value) => MapEntry(id, fromMinor(value)));
}
