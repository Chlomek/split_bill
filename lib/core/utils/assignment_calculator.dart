import 'split_calculator.dart';

/// How one receipt line is split, as built on the person-first assignment
/// screen: pick a person, tap the lines they had.
class LineAssignment {
  /// Split evenly between all members ("Všichni" mode).
  final bool everyone;

  /// Pieces nobody claimed are split evenly between all members.
  final bool restToEveryone;

  /// Member ID to the number of taps. For a multi-piece line one tap is one
  /// piece; for a single-piece line any tap means "had a share".
  final Map<String, int> pieces;

  const LineAssignment({
    this.everyone = false,
    this.restToEveryone = false,
    this.pieces = const {},
  });

  static const LineAssignment none = LineAssignment();

  int get taps => pieces.values.fold(0, (sum, n) => sum + n);

  bool get isEmpty => !everyone && !restToEveryone && taps == 0;

  /// Members with at least one tap, in [memberOrder].
  List<String> takers(List<String> memberOrder) =>
      memberOrder.where((id) => (pieces[id] ?? 0) > 0).toList();

  int piecesOf(String memberId) => pieces[memberId] ?? 0;

  LineAssignment withPieces(String memberId, int count) {
    final next = Map<String, int>.of(pieces);
    if (count <= 0) {
      next.remove(memberId);
    } else {
      next[memberId] = count;
    }
    return LineAssignment(
      everyone: everyone,
      restToEveryone: restToEveryone,
      pieces: next,
    );
  }

  LineAssignment copyWith({bool? everyone, bool? restToEveryone}) =>
      LineAssignment(
        everyone: everyone ?? this.everyone,
        restToEveryone: restToEveryone ?? this.restToEveryone,
        pieces: pieces,
      );
}

/// A receipt line as the calculator needs it.
class ReceiptLine {
  final String id;
  final String name;
  final int quantity;

  /// Amount for the whole line (all pieces).
  final double lineTotal;

  const ReceiptLine({
    required this.id,
    required this.name,
    required this.quantity,
    required this.lineTotal,
  });

  int get pieces => quantity < 1 ? 1 : quantity;
  int get totalMinor => SplitCalculator.toMinor(lineTotal);
  bool get hasPrice => totalMinor > 0;
}

/// The result of splitting one line, before tip or discount.
class LineSplit {
  /// Member ID to cost in minor units (not rounded yet).
  final Map<String, double> cost;

  /// Unassigned amount in minor units.
  final double open;

  /// Unassigned pieces (multi-piece lines only).
  final int openPieces;

  /// More taps than pieces: the line is split in proportion to taps.
  final bool proportional;

  const LineSplit({
    required this.cost,
    required this.open,
    required this.openPieces,
    required this.proportional,
  });
}

/// Totals of a whole receipt.
class AssignmentResult {
  /// Member ID to final share in minor units, including that member's part
  /// of any tip or whole-purchase discount. Rounded so that the shares plus
  /// [openMinor] add up exactly to [grandMinor].
  final Map<String, int> shares;

  /// Amount nobody has been assigned yet, in minor units.
  final int openMinor;

  /// Sum of all lines, in minor units.
  final int itemsMinor;

  /// What was actually paid (receipt total), in minor units.
  final int grandMinor;

  /// Member ID to their part of the difference between [grandMinor] and
  /// [itemsMinor], in minor units (for display).
  final Map<String, int> differenceShares;

  /// Per line, keyed by [ReceiptLine.id].
  final Map<String, LineSplit> lines;

  /// Lines that still have something unassigned or no price, in order.
  final List<String> openLineIds;

  const AssignmentResult({
    required this.shares,
    required this.openMinor,
    required this.itemsMinor,
    required this.grandMinor,
    required this.differenceShares,
    required this.lines,
    required this.openLineIds,
  });

  /// Positive for a tip or service charge, negative for a discount.
  int get differenceMinor => grandMinor - itemsMinor;

  bool get isComplete => openLineIds.isEmpty && lines.isNotEmpty;

  /// Shares in crowns, for storing the expense.
  Map<String, double> get sharesInCrowns => {
    for (final entry in shares.entries)
      if (entry.value > 0) entry.key: SplitCalculator.fromMinor(entry.value),
  };
}

class AssignmentCalculator {
  AssignmentCalculator._();

  /// Splits one line between [members] according to [a].
  static LineSplit splitLine(
    ReceiptLine line,
    LineAssignment a,
    List<String> members,
  ) {
    final cost = {for (final m in members) m: 0.0};
    final total = line.totalMinor.toDouble();
    final qty = line.pieces;
    final n = members.length;

    void everyoneEqually(double amount) {
      if (n == 0) return;
      for (final m in members) {
        cost[m] = cost[m]! + amount / n;
      }
    }

    if (a.everyone) {
      everyoneEqually(total);
      return LineSplit(cost: cost, open: 0, openPieces: 0, proportional: false);
    }

    final takers = a.takers(members);
    final taps = takers.fold<int>(0, (s, m) => s + a.piecesOf(m));

    if (qty == 1) {
      if (takers.isEmpty) {
        if (a.restToEveryone) {
          everyoneEqually(total);
          return LineSplit(
            cost: cost,
            open: 0,
            openPieces: 0,
            proportional: false,
          );
        }
        return LineSplit(
          cost: cost,
          open: total,
          openPieces: 1,
          proportional: false,
        );
      }
      for (final m in takers) {
        cost[m] = total / takers.length;
      }
      return LineSplit(cost: cost, open: 0, openPieces: 0, proportional: false);
    }

    if (taps > qty) {
      for (final m in takers) {
        cost[m] = total * a.piecesOf(m) / taps;
      }
      return LineSplit(cost: cost, open: 0, openPieces: 0, proportional: true);
    }

    final unit = total / qty;
    for (final m in takers) {
      cost[m] = a.piecesOf(m) * unit;
    }
    final rest = (qty - taps) * unit;
    if (rest > 0 && a.restToEveryone) {
      everyoneEqually(rest);
      return LineSplit(cost: cost, open: 0, openPieces: 0, proportional: false);
    }
    return LineSplit(
      cost: cost,
      open: rest,
      openPieces: qty - taps,
      proportional: false,
    );
  }

  /// Splits the whole receipt. [receiptTotal] is what was paid; when it
  /// differs from the sum of the lines (tip, service, discount) the
  /// difference is shared in proportion to what each person had.
  static AssignmentResult calculate({
    required List<ReceiptLine> lines,
    required Map<String, LineAssignment> assignments,
    required List<String> members,
    double? receiptTotal,
  }) {
    final itemsMinor = lines.fold<int>(0, (s, l) => s + l.totalMinor);
    final grandMinor = receiptTotal != null
        ? SplitCalculator.toMinor(receiptTotal)
        : itemsMinor;
    final k = itemsMinor > 0 ? grandMinor / itemsMinor : 1.0;

    final base = {for (final m in members) m: 0.0};
    var openBase = 0.0;
    final splits = <String, LineSplit>{};
    final openLines = <String>[];

    for (final line in lines) {
      final split = splitLine(
        line,
        assignments[line.id] ?? LineAssignment.none,
        members,
      );
      splits[line.id] = split;
      split.cost.forEach((m, c) => base[m] = base[m]! + c);
      openBase += split.open;
      if (split.open > 0.001 || !line.hasPrice) openLines.add(line.id);
    }

    // Largest-remainder rounding over members plus the open amount, so the
    // rounded figures always add up to the receipt total.
    final keys = [...members, '__open'];
    final exact = [for (final m in members) base[m]! * k, openBase * k];
    final floors = exact.map((v) => (v + 1e-9).floor()).toList();
    var left = grandMinor - floors.fold<int>(0, (s, v) => s + v);
    final order = List.generate(keys.length, (i) => i)
      ..sort((a, b) => (exact[b] - floors[b]).compareTo(exact[a] - floors[a]));
    for (final i in order) {
      if (left <= 0) break;
      if (exact[i] > 0) {
        floors[i] += 1;
        left -= 1;
      }
    }
    // Nothing to attach a leftover to (e.g. no priced lines): keep it open.
    if (left > 0) floors[keys.length - 1] += left;

    final shares = <String, int>{
      for (var i = 0; i < members.length; i++)
        if (floors[i] > 0) members[i]: floors[i],
    };

    final difference = grandMinor - itemsMinor;
    final differenceShares = <String, int>{
      if (difference != 0 && itemsMinor > 0)
        for (final m in members)
          if (base[m]! > 0) m: (difference * base[m]! / itemsMinor).round(),
    };

    return AssignmentResult(
      shares: shares,
      openMinor: floors.last,
      itemsMinor: itemsMinor,
      grandMinor: grandMinor,
      differenceShares: differenceShares,
      lines: splits,
      openLineIds: openLines,
    );
  }
}
