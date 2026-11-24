/// One line of a scanned receipt that was saved with its expense, together
/// with how it was split. Kept so the expense can be shown line by line and
/// its split edited later.
class ExpenseItem {
  final String id;
  final String expenseId;
  final String name;
  final int quantity;

  /// Amount for the whole line (all pieces), after any item discount.
  final double lineTotal;

  /// Item discount already included in [lineTotal] (informational).
  final double discount;

  /// Split evenly between all members of the group.
  final bool everyone;

  /// Pieces nobody claimed are split evenly between all members.
  final bool restToEveryone;

  /// Member ID to the number of pieces (or taps) that member had.
  final Map<String, int> pieces;

  const ExpenseItem({
    required this.id,
    required this.expenseId,
    required this.name,
    required this.quantity,
    required this.lineTotal,
    this.discount = 0,
    this.everyone = false,
    this.restToEveryone = false,
    this.pieces = const {},
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'expense_id': expenseId,
    'name': name,
    'quantity': quantity,
    'line_total': lineTotal,
    'discount': discount,
    'everyone': everyone,
    'rest_to_everyone': restToEveryone,
    'pieces': pieces,
  };

  factory ExpenseItem.fromJson(Map<String, dynamic> json) => ExpenseItem(
    id: json['id'] as String,
    expenseId: json['expense_id'] as String,
    name: json['name'] as String? ?? 'Položka',
    quantity: ((json['quantity'] ?? 1) as num).toInt(),
    lineTotal: ((json['line_total'] ?? 0) as num).toDouble(),
    discount: ((json['discount'] ?? 0) as num).toDouble(),
    everyone: json['everyone'] as bool? ?? false,
    restToEveryone: json['rest_to_everyone'] as bool? ?? false,
    pieces: (json['pieces'] as Map<String, dynamic>? ?? const {}).map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    ),
  );
}
