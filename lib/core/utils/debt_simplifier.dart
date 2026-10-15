import '../../features/settlements/domain/settlement_debt.dart';

/// Client-side implementation and fallback of the Debt Simplification algorithm
/// (Min-Cash Flow / Greedy debt reduction).
class DebtSimplifier {
  DebtSimplifier._();

  /// Given a map of memberId to net balance (positive = is owed money, negative = owes money),
  /// calculates the minimal list of direct transactions needed to settle all debts.
  static List<SettlementDebt> simplifyDebts(Map<String, double> netBalances) {
    final List<MapEntry<String, double>> debtors = [];
    final List<MapEntry<String, double>> creditors = [];

    // Separate into debtors (owes) and creditors (is owed)
    netBalances.forEach((memberId, balance) {
      // Round to 2 decimal places to avoid floating point precision artifacts
      final rounded = double.parse(balance.toStringAsFixed(2));
      if (rounded < -0.01) {
        debtors.add(MapEntry(memberId, -rounded)); // store positive debt amount
      } else if (rounded > 0.01) {
        creditors.add(MapEntry(memberId, rounded));
      }
    });

    final List<SettlementDebt> transactions = [];

    int dIndex = 0;
    int cIndex = 0;

    while (dIndex < debtors.length && cIndex < creditors.length) {
      final debtor = debtors[dIndex];
      final creditor = creditors[cIndex];

      final minAmount = debtor.value < creditor.value ? debtor.value : creditor.value;
      final roundedMin = double.parse(minAmount.toStringAsFixed(2));

      if (roundedMin > 0.01) {
        transactions.add(
          SettlementDebt(
            fromMemberId: debtor.key,
            toMemberId: creditor.key,
            amount: roundedMin,
          ),
        );
      }

      debtors[dIndex] = MapEntry(debtor.key, debtor.value - minAmount);
      creditors[cIndex] = MapEntry(creditor.key, creditor.value - minAmount);

      if (debtors[dIndex].value < 0.01) {
        dIndex++;
      }
      if (creditors[cIndex].value < 0.01) {
        cIndex++;
      }
    }

    return transactions;
  }
}
