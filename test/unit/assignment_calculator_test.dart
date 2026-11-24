import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill/core/utils/assignment_calculator.dart';

const members = ['ty', 'pepa', 'kaja'];

ReceiptLine line(String id, int qty, double total) =>
    ReceiptLine(id: id, name: id, quantity: qty, lineTotal: total);

int sum(Map<String, int> m) => m.values.fold(0, (s, v) => s + v);

void main() {
  group('splitLine', () {
    test('one tap is one piece on a multi-piece line', () {
      final r = AssignmentCalculator.splitLine(
        line('beer', 6, 330),
        const LineAssignment(pieces: {'ty': 2, 'pepa': 3}),
        members,
      );
      expect(r.cost['ty'], 11000);
      expect(r.cost['pepa'], 16500);
      expect(r.open, 5500);
      expect(r.openPieces, 1);
      expect(r.proportional, isFalse);
    });

    test(
      'a single-piece line is shared evenly between everyone who tapped',
      () {
        final r = AssignmentCalculator.splitLine(
          line('cheese', 1, 189),
          const LineAssignment(pieces: {'ty': 1, 'kaja': 1}),
          members,
        );
        expect(r.cost['ty'], 9450);
        expect(r.cost['kaja'], 9450);
        expect(r.open, 0);
      },
    );

    test('more taps than pieces switches to a proportional split', () {
      final r = AssignmentCalculator.splitLine(
        line('fries', 2, 118),
        const LineAssignment(pieces: {'ty': 2, 'pepa': 1}),
        members,
      );
      expect(r.proportional, isTrue);
      expect(r.open, 0);
      expect(r.cost['ty']! + r.cost['pepa']!, closeTo(11800, 0.001));
    });

    test('rest to everyone spreads unclaimed pieces over all members', () {
      final r = AssignmentCalculator.splitLine(
        line('kofola', 3, 150),
        const LineAssignment(pieces: {'ty': 1}, restToEveryone: true),
        members,
      );
      expect(r.open, 0);
      expect(r.cost['ty'], closeTo(5000 + 10000 / 3, 0.001));
      expect(r.cost['pepa'], closeTo(10000 / 3, 0.001));
    });

    test('everyone mode ignores taps', () {
      final r = AssignmentCalculator.splitLine(
        line('bread', 1, 90),
        const LineAssignment(everyone: true, pieces: {'ty': 1}),
        members,
      );
      expect(r.cost.values.every((v) => v == 3000), isTrue);
    });
  });

  group('calculate', () {
    test('a tip is shared in proportion and shares add up to the total', () {
      final result = AssignmentCalculator.calculate(
        lines: [line('a', 1, 300), line('b', 1, 100)],
        assignments: {
          'a': const LineAssignment(pieces: {'ty': 1}),
          'b': const LineAssignment(pieces: {'pepa': 1}),
        },
        members: members,
        receiptTotal: 440,
      );
      expect(result.isComplete, isTrue);
      expect(result.shares, {'ty': 33000, 'pepa': 11000});
      expect(result.differenceMinor, 4000);
      expect(result.differenceShares, {'ty': 3000, 'pepa': 1000});
      expect(result.sharesInCrowns, {'ty': 330.0, 'pepa': 110.0});
    });

    test('a whole-purchase discount lowers everyone proportionally', () {
      final result = AssignmentCalculator.calculate(
        lines: [line('a', 1, 100), line('b', 1, 100)],
        assignments: {
          'a': const LineAssignment(pieces: {'ty': 1}),
          'b': const LineAssignment(pieces: {'kaja': 1}),
        },
        members: members,
        receiptTotal: 180,
      );
      expect(result.shares, {'ty': 9000, 'kaja': 9000});
      expect(result.differenceMinor, -2000);
    });

    test('rounding never loses or invents a haler', () {
      final result = AssignmentCalculator.calculate(
        lines: [line('a', 3, 100), line('b', 1, 33.33)],
        assignments: {
          'a': const LineAssignment(pieces: {'ty': 1, 'pepa': 1, 'kaja': 1}),
          'b': const LineAssignment(everyone: true),
        },
        members: members,
        receiptTotal: 140,
      );
      expect(sum(result.shares), 14000);
      expect(result.openMinor, 0);
    });

    test('reports open lines and keeps the open amount in the total', () {
      final result = AssignmentCalculator.calculate(
        lines: [line('a', 2, 100), line('b', 1, 50), line('c', 1, 0)],
        assignments: {
          'a': const LineAssignment(pieces: {'ty': 1}),
        },
        members: members,
      );
      expect(result.isComplete, isFalse);
      expect(result.openLineIds, ['a', 'b', 'c']);
      expect(result.openMinor, 10000);
      expect(sum(result.shares) + result.openMinor, result.grandMinor);
    });
  });
}
