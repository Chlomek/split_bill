import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill/core/utils/split_calculator.dart';
import 'package:split_bill/features/receipt_scan/domain/scanned_receipt_item.dart';

double _sum(Map<String, double> shares) =>
    SplitCalculator.fromMinor(
      shares.values.fold<int>(0, (s, v) => s + SplitCalculator.toMinor(v)),
    );

void main() {
  group('SplitCalculator.equalSplit', () {
    test('splits evenly when divisible', () {
      final shares = SplitCalculator.equalSplit(300, ['a', 'b', 'c']);
      expect(shares, {'a': 100.0, 'b': 100.0, 'c': 100.0});
    });

    test('hands leftover hallers to the first members and keeps the total', () {
      final shares = SplitCalculator.equalSplit(100, ['a', 'b', 'c']);
      expect(shares, {'a': 33.34, 'b': 33.33, 'c': 33.33});
      expect(_sum(shares), 100.0);
    });

    test('throws without members', () {
      expect(() => SplitCalculator.equalSplit(100, []), throwsArgumentError);
    });
  });

  group('SplitCalculator.splitItems', () {
    test('divides each item between its assigned members', () {
      final shares = SplitCalculator.splitItems(
        items: [
          ScannedReceiptItem(name: 'Pizza', price: 190, assignedMemberIds: ['a']),
          ScannedReceiptItem(
            name: 'Pivo',
            price: 60,
            quantity: 2,
            assignedMemberIds: ['b', 'c'],
          ),
          ScannedReceiptItem(name: 'Mléko', price: 20, assignedMemberIds: ['a', 'c']),
        ],
      );
      expect(shares, {'a': 200.0, 'b': 60.0, 'c': 70.0});
    });

    test('distributes a tip proportionally to each subtotal', () {
      final shares = SplitCalculator.splitItems(
        items: [
          ScannedReceiptItem(name: 'A', price: 300, assignedMemberIds: ['a']),
          ScannedReceiptItem(name: 'B', price: 100, assignedMemberIds: ['b']),
        ],
        scannedTotal: 440,
      );
      expect(shares, {'a': 330.0, 'b': 110.0});
    });

    test('shares always add up exactly to the scanned total', () {
      final shares = SplitCalculator.splitItems(
        items: [
          ScannedReceiptItem(name: 'A', price: 33.33, assignedMemberIds: ['a', 'b', 'c']),
          ScannedReceiptItem(name: 'B', price: 19.90, assignedMemberIds: ['b']),
          ScannedReceiptItem(name: 'C', price: 7.10, assignedMemberIds: ['a', 'c']),
        ],
        scannedTotal: 65,
      );
      expect(_sum(shares), 65.0);
    });

    test('handles a total lower than the items (discount)', () {
      final shares = SplitCalculator.splitItems(
        items: [
          ScannedReceiptItem(name: 'A', price: 100, assignedMemberIds: ['a']),
          ScannedReceiptItem(name: 'B', price: 100, assignedMemberIds: ['b']),
        ],
        scannedTotal: 180,
      );
      expect(shares, {'a': 90.0, 'b': 90.0});
    });

    test('throws when an item has nobody assigned', () {
      expect(
        () => SplitCalculator.splitItems(
          items: [ScannedReceiptItem(name: 'A', price: 10)],
        ),
        throwsArgumentError,
      );
    });
  });
}
