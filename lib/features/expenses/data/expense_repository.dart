import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_store.dart';
import '../domain/expense.dart';
import '../domain/expense_item.dart';
import '../domain/expense_split.dart';

/// Storage contract for expenses and their per-member splits.
abstract class ExpenseRepository {
  Future<List<Expense>> getExpenses(String groupId);

  /// All splits belonging to the expenses of [groupId].
  Future<List<ExpenseSplit>> getSplits(String groupId);

  /// Receipt lines saved with the expenses of [groupId].
  Future<List<ExpenseItem>> getItems(String groupId);

  /// Stores an expense together with its splits (and receipt lines) as one
  /// unit. An existing expense with the same ID is replaced.
  Future<void> saveExpense(
    Expense expense,
    List<ExpenseSplit> splits, {
    List<ExpenseItem> items = const [],
  });

  Future<void> deleteExpense(String expenseId);
}

class LocalExpenseRepository implements ExpenseRepository {
  final LocalStore _store;

  LocalExpenseRepository(this._store);

  @override
  Future<List<Expense>> getExpenses(String groupId) async =>
      _store.expenses.where((e) => e.groupId == groupId).toList();

  @override
  Future<List<ExpenseSplit>> getSplits(String groupId) async {
    final expenseIds = _store.expenses
        .where((e) => e.groupId == groupId)
        .map((e) => e.id)
        .toSet();
    return _store.splits
        .where((s) => expenseIds.contains(s.expenseId))
        .toList();
  }

  @override
  Future<List<ExpenseItem>> getItems(String groupId) async {
    final expenseIds = _store.expenses
        .where((e) => e.groupId == groupId)
        .map((e) => e.id)
        .toSet();
    return _store.expenseItems
        .where((i) => expenseIds.contains(i.expenseId))
        .toList();
  }

  @override
  Future<void> saveExpense(
    Expense expense,
    List<ExpenseSplit> splits, {
    List<ExpenseItem> items = const [],
  }) async {
    _removeExpense(expense.id);
    _store.expenses.add(expense);
    _store.splits.addAll(splits);
    _store.expenseItems.addAll(items);
    await _store.save();
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    _removeExpense(expenseId);
    await _store.save();
  }

  void _removeExpense(String expenseId) {
    _store.expenseItems.removeWhere((i) => i.expenseId == expenseId);
    _store.splits.removeWhere((s) => s.expenseId == expenseId);
    _store.expenses.removeWhere((e) => e.id == expenseId);
  }
}

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => LocalExpenseRepository(ref.watch(localStoreProvider)),
);
