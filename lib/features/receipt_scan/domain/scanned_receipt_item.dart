import 'package:uuid/uuid.dart';

/// Represents a single line item parsed from a receipt.
class ScannedReceiptItem {
  final String id;
  final String name;
  final double price;
  final int quantity;

  /// IDs of group members assigned to pay for this item.
  final List<String> assignedMemberIds;

  ScannedReceiptItem({
    String? id,
    required this.name,
    required this.price,
    this.quantity = 1,
    List<String>? assignedMemberIds,
  })  : id = id ?? const Uuid().v4(),
        assignedMemberIds = assignedMemberIds ?? [];

  ScannedReceiptItem copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    List<String>? assignedMemberIds,
  }) {
    return ScannedReceiptItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      assignedMemberIds: assignedMemberIds ?? List.from(this.assignedMemberIds),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'assigned_member_ids': assignedMemberIds,
    };
  }

  factory ScannedReceiptItem.fromJson(Map<String, dynamic> json) {
    return ScannedReceiptItem(
      id: json['id'] as String?,
      name: (json['name'] ?? json['title'] ?? 'Item') as String,
      price: ((json['price'] ?? json['amount'] ?? 0) as num).toDouble(),
      quantity: ((json['quantity'] ?? json['qty'] ?? 1) as num).toInt(),
      assignedMemberIds: (json['assigned_member_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
