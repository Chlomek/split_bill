import '../../features/expenses/domain/expense.dart';
import '../../features/expenses/domain/expense_split.dart';
import '../../features/settlements/domain/settlement.dart';
import 'split_calculator.dart';

/// Computes each member's net balance in a group.
///
/// Positive balance = the member is owed money, negative = the member owes.
class BalanceCalculator {
  BalanceCalculator._();

  static Map<String, double> netBalances({
    required Iterable<String> memberIds,
    required Iterable<Expense> expenses,
    required Iterable<ExpenseSplit> splits,
    Iterable<Settlement> settlements = const [],
  }) {
    final balances = <String, int>{for (final id in memberIds) id: 0};
    void add(String id, int amount) =>
        balances[id] = (balances[id] ?? 0) + amount;

    final expenseIds = <String>{};
    for (final expense in expenses) {
      expenseIds.add(expense.id);
      add(expense.paidByMemberId, SplitCalculator.toMinor(expense.totalAmount));
    }

    for (final split in splits) {
      if (!expenseIds.contains(split.expenseId)) continue;
      add(split.memberId, -SplitCalculator.toMinor(split.amountOwed));
    }

    // A settlement is money handed from the debtor to the creditor.
    for (final settlement in settlements) {
      final amount = SplitCalculator.toMinor(settlement.amount);
      add(settlement.fromMemberId, amount);
      add(settlement.toMemberId, -amount);
    }

    return balances
        .map((id, value) => MapEntry(id, SplitCalculator.fromMinor(value)));
  }
}
