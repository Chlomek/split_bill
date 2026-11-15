/// Model matching the "settlements" table: a recorded payment from a debtor
/// to a creditor inside a group (cash hand-over or bank transfer).
class Settlement {
  final String id;
  final String groupId;
  final String fromMemberId;
  final String toMemberId;
  final double amount;
  final DateTime createdAt;

  const Settlement({
    required this.id,
    required this.groupId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'from_member_id': fromMemberId,
      'to_member_id': toMemberId,
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Settlement.fromJson(Map<String, dynamic> json) {
    return Settlement(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      fromMemberId: json['from_member_id'] as String,
      toMemberId: json['to_member_id'] as String,
      amount: ((json['amount'] ?? 0) as num).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
