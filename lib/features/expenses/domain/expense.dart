/// Model matching the "expenses" table in Supabase.
class Expense {
  final String id;
  final String groupId;
  final String paidByMemberId;
  final double totalAmount;
  final String title;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.groupId,
    required this.paidByMemberId,
    required this.totalAmount,
    required this.title,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'paid_by_member_id': paidByMemberId,
      'total_amount': totalAmount,
      'title': title,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      paidByMemberId: json['paid_by_member_id'] as String,
      totalAmount: ((json['total_amount'] ?? 0) as num).toDouble(),
      title: json['title'] as String? ?? 'Expense',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
