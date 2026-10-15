/// Model matching the "expense_splits" table in Supabase.
class ExpenseSplit {
  final String id;
  final String expenseId;
  final String memberId;
  final double amountOwed;

  const ExpenseSplit({
    required this.id,
    required this.expenseId,
    required this.memberId,
    required this.amountOwed,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expense_id': expenseId,
      'member_id': memberId,
      'amount_owed': amountOwed,
    };
  }

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) {
    return ExpenseSplit(
      id: json['id'] as String,
      expenseId: json['expense_id'] as String,
      memberId: json['member_id'] as String,
      amountOwed: ((json['amount_owed'] ?? 0) as num).toDouble(),
    );
  }
}
