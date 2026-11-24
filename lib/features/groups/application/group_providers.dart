import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/balance_calculator.dart';
import '../../../core/utils/debt_simplifier.dart';
import '../../auth/data/profile_repository.dart';
import '../../auth/domain/user_profile.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/domain/expense_item.dart';
import '../../expenses/domain/expense_split.dart';
import '../../settlements/data/settlement_repository.dart';
import '../../settlements/domain/settlement.dart';
import '../../settlements/domain/settlement_debt.dart';
import '../data/group_repository.dart';
import '../domain/group.dart';
import '../domain/group_member.dart';

/// The person using this device; null until onboarding is finished.
final profileProvider = FutureProvider<UserProfile?>(
  (ref) => ref.watch(profileRepositoryProvider).getProfile(),
);

/// IBAN stored on this device only.
final ibanProvider = FutureProvider<String?>(
  (ref) => ref.watch(profileRepositoryProvider).getIban(),
);

/// Everything the group detail screen needs, with balances already computed.
class GroupDetail {
  final Group group;
  final List<GroupMember> members;
  final List<Expense> expenses;
  final List<ExpenseSplit> splits;
  final List<ExpenseItem> items;
  final List<Settlement> settlements;

  /// Member ID -> net balance (positive = is owed, negative = owes).
  final Map<String, double> balances;

  /// Minimal list of payments that settles the whole group.
  final List<SettlementDebt> debts;

  /// The membership of the current user in this group, if any.
  final GroupMember? me;

  const GroupDetail({
    required this.group,
    required this.members,
    required this.expenses,
    required this.splits,
    required this.items,
    required this.settlements,
    required this.balances,
    required this.debts,
    required this.me,
  });

  double get totalSpent => expenses.fold(0.0, (sum, e) => sum + e.totalAmount);

  List<ExpenseItem> itemsOf(String expenseId) =>
      items.where((i) => i.expenseId == expenseId).toList();

  List<ExpenseSplit> splitsOf(String expenseId) =>
      splits.where((s) => s.expenseId == expenseId).toList();

  GroupMember? member(String memberId) {
    for (final m in members) {
      if (m.id == memberId) return m;
    }
    return null;
  }

  /// Simplified debts in which the current user pays or is paid.
  List<SettlementDebt> get myDebts => me == null
      ? const []
      : debts
            .where((d) => d.fromMemberId == me!.id || d.toMemberId == me!.id)
            .toList();

  /// Simplified debts paid to the current user, largest first.
  List<SettlementDebt> get owedToMe => me == null
      ? const []
      : (debts.where((d) => d.toMemberId == me!.id).toList()
          ..sort((a, b) => b.amount.compareTo(a.amount)));

  double get myBalance => me == null ? 0 : balances[me!.id] ?? 0;

  String memberName(String memberId) {
    for (final member in members) {
      if (member.id == memberId) return member.displayName;
    }
    return 'Neznámý člen';
  }

  DateTime? get lastActivity {
    final dates = [
      ...expenses.map((e) => e.createdAt),
      ...settlements.map((s) => s.createdAt),
    ];
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

final groupDetailProvider = FutureProvider.family<GroupDetail?, String>((
  ref,
  groupId,
) async {
  final group = await ref.watch(groupRepositoryProvider).getGroup(groupId);
  if (group == null) return null;

  final members = await ref.watch(groupRepositoryProvider).getMembers(groupId);
  final expenses = await ref
      .watch(expenseRepositoryProvider)
      .getExpenses(groupId);
  final splits = await ref.watch(expenseRepositoryProvider).getSplits(groupId);
  final items = await ref.watch(expenseRepositoryProvider).getItems(groupId);
  final settlements = await ref
      .watch(settlementRepositoryProvider)
      .getSettlements(groupId);
  final profile = await ref.watch(profileProvider.future);

  final balances = BalanceCalculator.netBalances(
    memberIds: members.map((m) => m.id),
    expenses: expenses,
    splits: splits,
    settlements: settlements,
  );

  GroupMember? me;
  if (profile != null) {
    for (final member in members) {
      if (member.userId == profile.id) me = member;
    }
  }

  return GroupDetail(
    group: group,
    members: members,
    expenses: expenses,
    splits: splits,
    items: items,
    settlements: settlements,
    balances: balances,
    debts: DebtSimplifier.simplifyDebts(balances),
    me: me,
  );
});

/// All groups, newest activity first, for the home screen.
final groupListProvider = FutureProvider<List<GroupDetail>>((ref) async {
  final groups = await ref.watch(groupRepositoryProvider).getGroups();
  final details = <GroupDetail>[];
  for (final group in groups) {
    final detail = await ref.watch(groupDetailProvider(group.id).future);
    if (detail != null) details.add(detail);
  }
  details.sort((a, b) {
    final aDate = a.lastActivity ?? a.group.createdAt;
    final bDate = b.lastActivity ?? b.group.createdAt;
    return bDate.compareTo(aDate);
  });
  return details;
});

/// All write operations of the app. Each one refreshes the affected providers
/// so every screen shows the new state.
class GroupActions {
  final Ref _ref;
  final Uuid _uuid = const Uuid();

  GroupActions(this._ref);

  void _refresh() {
    _ref.invalidate(groupDetailProvider);
    _ref.invalidate(groupListProvider);
  }

  /// Saves the display name and (device-only) IBAN of the current user.
  Future<void> saveProfile({required String name, String? iban}) async {
    final repo = _ref.read(profileRepositoryProvider);
    final profile = await repo.saveName(name);
    await _ref
        .read(groupRepositoryProvider)
        .renameUserMembers(profile.id, name);
    if (iban != null) {
      await repo.setIban(iban);
      _ref.invalidate(ibanProvider);
    }
    _ref.invalidate(profileProvider);
    _refresh();
  }

  /// Creates a group with the current user and, optionally, members
  /// without the app ([otherMembers], by name).
  Future<Group> createGroup(
    String name, {
    GroupType type = GroupType.other,
    List<String> otherMembers = const [],
  }) async {
    final profile = await _ref.read(profileProvider.future);
    if (profile == null) {
      throw StateError('A profile is required before creating a group.');
    }
    final repo = _ref.read(groupRepositoryProvider);
    final group = await repo.createGroup(
      name: name,
      creator: profile,
      type: type,
    );
    for (final member in otherMembers) {
      await repo.addVirtualMember(groupId: group.id, displayName: member);
    }
    _refresh();
    return group;
  }

  Future<void> renameGroup(String groupId, String name) async {
    await _ref.read(groupRepositoryProvider).renameGroup(groupId, name);
    _refresh();
  }

  Future<void> deleteGroup(String groupId) async {
    await _ref.read(groupRepositoryProvider).deleteGroup(groupId);
    _refresh();
  }

  Future<void> addVirtualMember(String groupId, String displayName) async {
    await _ref
        .read(groupRepositoryProvider)
        .addVirtualMember(groupId: groupId, displayName: displayName);
    _refresh();
  }

  /// Stores an expense; [shares] maps member ID to the amount that member
  /// owes. Pass [expenseId] to replace an existing expense (its date is
  /// kept), and [items] to keep the receipt lines with it.
  Future<void> addExpense({
    required String groupId,
    required String title,
    required String paidByMemberId,
    required Map<String, double> shares,
    String? expenseId,
    DateTime? createdAt,
    String? source,
    List<ExpenseItem> Function(String expenseId)? items,
  }) async {
    final expense = Expense(
      id: expenseId ?? _uuid.v4(),
      groupId: groupId,
      paidByMemberId: paidByMemberId,
      totalAmount: shares.values.fold(0.0, (sum, v) => sum + v),
      title: title,
      createdAt: createdAt ?? DateTime.now(),
      source: source,
    );
    final splits = [
      for (final entry in shares.entries)
        ExpenseSplit(
          id: _uuid.v4(),
          expenseId: expense.id,
          memberId: entry.key,
          amountOwed: entry.value,
        ),
    ];
    await _ref
        .read(expenseRepositoryProvider)
        .saveExpense(
          expense,
          splits,
          items: items?.call(expense.id) ?? const [],
        );
    _refresh();
  }

  Future<void> deleteExpense(String expenseId) async {
    await _ref.read(expenseRepositoryProvider).deleteExpense(expenseId);
    _refresh();
  }

  /// Records that [fromMemberId] paid [amount] to [toMemberId].
  Future<Settlement> addSettlement({
    required String groupId,
    required String fromMemberId,
    required String toMemberId,
    required double amount,
  }) async {
    final settlement = Settlement(
      id: _uuid.v4(),
      groupId: groupId,
      fromMemberId: fromMemberId,
      toMemberId: toMemberId,
      amount: amount,
      createdAt: DateTime.now(),
    );
    await _ref.read(settlementRepositoryProvider).addSettlement(settlement);
    _refresh();
    return settlement;
  }

  Future<void> deleteSettlement(String settlementId) async {
    await _ref
        .read(settlementRepositoryProvider)
        .deleteSettlement(settlementId);
    _refresh();
  }
}

final groupActionsProvider = Provider<GroupActions>((ref) => GroupActions(ref));
