import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill/core/utils/balance_calculator.dart';
import 'package:split_bill/core/utils/debt_simplifier.dart';
import 'package:split_bill/core/utils/iban_validator.dart';
import 'package:split_bill/features/expenses/domain/expense.dart';
import 'package:split_bill/features/expenses/domain/expense_split.dart';
import 'package:split_bill/features/settlements/domain/settlement.dart';

Expense _expense(String id, String paidBy, double total) => Expense(
      id: id,
      groupId: 'g',
      paidByMemberId: paidBy,
      totalAmount: total,
      title: id,
      createdAt: DateTime(2026),
    );

ExpenseSplit _split(String expenseId, String member, double amount) =>
    ExpenseSplit(
      id: '$expenseId-$member',
      expenseId: expenseId,
      memberId: member,
      amountOwed: amount,
    );

void main() {
  group('BalanceCalculator', () {
    final members = ['pepa', 'franta', 'kaja'];
    final expenses = [_expense('e1', 'kaja', 600)];
    final splits = [
      _split('e1', 'pepa', 400),
      _split('e1', 'franta', 0),
      _split('e1', 'kaja', 200),
    ];

    test('payer is credited the total, each split is debited', () {
      final balances = BalanceCalculator.netBalances(
        memberIds: members,
        expenses: expenses,
        splits: splits,
      );
      expect(balances, {'pepa': -400.0, 'franta': 0.0, 'kaja': 400.0});
    });

    test('a settlement reduces the debt and simplified debts follow', () {
      final settlement = Settlement(
        id: 's1',
        groupId: 'g',
        fromMemberId: 'pepa',
        toMemberId: 'kaja',
        amount: 150,
        createdAt: DateTime(2026),
      );
      final balances = BalanceCalculator.netBalances(
        memberIds: members,
        expenses: expenses,
        splits: splits,
        settlements: [settlement],
      );
      expect(balances, {'pepa': -250.0, 'franta': 0.0, 'kaja': 250.0});

      final debts = DebtSimplifier.simplifyDebts(balances);
      expect(debts, hasLength(1));
      expect(debts.single.fromMemberId, 'pepa');
      expect(debts.single.toMemberId, 'kaja');
      expect(debts.single.amount, 250.0);
    });

    test('balances of a group always sum to zero', () {
      final balances = BalanceCalculator.netBalances(
        memberIds: members,
        expenses: [..._expensesMixed],
        splits: [..._splitsMixed],
      );
      final sum = balances.values.fold(0.0, (s, v) => s + v);
      expect(sum.abs() < 0.001, isTrue);
    });

    test('ignores splits of expenses that are not in the list', () {
      final balances = BalanceCalculator.netBalances(
        memberIds: members,
        expenses: const [],
        splits: splits,
      );
      expect(balances.values.every((v) => v == 0), isTrue);
    });
  });

  group('IbanValidator', () {
    test('accepts a valid Czech IBAN with spaces and lowercase', () {
      expect(IbanValidator.isValid('cz65 0800 0000 1920 0014 5399'), isTrue);
    });

    test('rejects a wrong checksum and malformed input', () {
      expect(IbanValidator.isValid('CZ6508000000192000145398'), isFalse);
      expect(IbanValidator.isValid('123456'), isFalse);
      expect(IbanValidator.isValid(''), isFalse);
    });
  });
}

final _expensesMixed = [
  _expense('a', 'pepa', 100),
  _expense('b', 'kaja', 33.33),
];

final _splitsMixed = [
  _split('a', 'pepa', 33.34),
  _split('a', 'franta', 33.33),
  _split('a', 'kaja', 33.33),
  _split('b', 'pepa', 16.67),
  _split('b', 'franta', 16.66),
];
