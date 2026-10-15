/// Represents a simplified direct settlement transaction between two group members.
class SettlementDebt {
  final String fromMemberId;
  final String toMemberId;
  final double amount;
  final String currency;

  const SettlementDebt({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    this.currency = 'CZK',
  });

  Map<String, dynamic> toJson() {
    return {
      'from_member_id': fromMemberId,
      'to_member_id': toMemberId,
      'amount': amount,
      'currency': currency,
    };
  }

  factory SettlementDebt.fromJson(Map<String, dynamic> json) {
    return SettlementDebt(
      fromMemberId: json['from_member_id'] as String,
      toMemberId: json['to_member_id'] as String,
      amount: ((json['amount'] ?? 0) as num).toDouble(),
      currency: (json['currency'] ?? 'CZK') as String,
    );
  }
}
