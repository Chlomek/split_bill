import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill/core/utils/debt_simplifier.dart';

void main() {
  group('DebtSimplifier', () {
    test('correctly simplifies 3-member balances from specification wireframe', () {
      // Pepa owes 400 (-400)
      // Franta is balanced (0)
      // Kája is owed 200 (+200)
      // Barča is owed 200 (+200)
      final netBalances = {
        'Pepa': -400.0,
        'Franta': 0.0,
        'Kája': 200.0,
        'Barča': 200.0,
      };

      final transactions = DebtSimplifier.simplifyDebts(netBalances);

      expect(transactions.length, 2);
      expect(transactions[0].fromMemberId, 'Pepa');
      expect(transactions[0].amount, 200.0);
      expect(transactions[1].fromMemberId, 'Pepa');
      expect(transactions[1].amount, 200.0);
    });

    test('handles empty or all-zero balances', () {
      final transactions = DebtSimplifier.simplifyDebts({
        'Pepa': 0.0,
        'Franta': 0.0,
      });

      expect(transactions, isEmpty);
    });
  });
}
