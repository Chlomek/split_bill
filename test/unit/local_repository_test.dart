import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill/core/storage/local_store.dart';
import 'package:split_bill/features/auth/domain/user_profile.dart';
import 'package:split_bill/features/expenses/data/expense_repository.dart';
import 'package:split_bill/features/expenses/domain/expense.dart';
import 'package:split_bill/features/expenses/domain/expense_split.dart';
import 'package:split_bill/features/groups/data/group_repository.dart';
import 'package:split_bill/features/settlements/data/settlement_repository.dart';
import 'package:split_bill/features/settlements/domain/settlement.dart';

void main() {
  late SharedPreferences prefs;
  final creator = UserProfile(
    id: 'user-1',
    email: '',
    name: 'Kája',
    createdAt: DateTime(2026),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('creating a group adds the creator as its first member', () async {
    final repo = LocalGroupRepository(LocalStore(prefs));
    final group = await repo.createGroup(name: 'Hory', creator: creator);

    expect(group.inviteCode, hasLength(8));
    final members = await repo.getMembers(group.id);
    expect(members.single.userId, 'user-1');
    expect(members.single.displayName, 'Kája');
    expect(members.single.isVirtual, isFalse);
  });

  test('data survives a restart (new store on the same preferences)', () async {
    final store = LocalStore(prefs);
    final groups = LocalGroupRepository(store);
    final group = await groups.createGroup(name: 'Hory', creator: creator);
    final honza =
        await groups.addVirtualMember(groupId: group.id, displayName: 'Honza');
    final me = (await groups.getMembers(group.id)).first;

    await LocalExpenseRepository(store).saveExpense(
      Expense(
        id: 'e1',
        groupId: group.id,
        paidByMemberId: me.id,
        totalAmount: 300,
        title: 'Taxi',
        createdAt: DateTime(2026, 3, 1),
      ),
      [
        ExpenseSplit(id: 's1', expenseId: 'e1', memberId: me.id, amountOwed: 150),
        ExpenseSplit(id: 's2', expenseId: 'e1', memberId: honza.id, amountOwed: 150),
      ],
    );
    await LocalSettlementRepository(store).addSettlement(
      Settlement(
        id: 'p1',
        groupId: group.id,
        fromMemberId: honza.id,
        toMemberId: me.id,
        amount: 150,
        createdAt: DateTime(2026, 3, 2),
      ),
    );

    final reloaded = LocalStore(prefs);
    final reloadedGroups = LocalGroupRepository(reloaded);
    expect((await reloadedGroups.getGroups()).single.name, 'Hory');

    final members = await reloadedGroups.getMembers(group.id);
    expect(members, hasLength(2));
    expect(members.last.isVirtual, isTrue);
    expect(members.last.userId, isNull);

    final expenses = await LocalExpenseRepository(reloaded).getExpenses(group.id);
    expect(expenses.single.title, 'Taxi');
    expect(await LocalExpenseRepository(reloaded).getSplits(group.id), hasLength(2));
    expect(
      (await LocalSettlementRepository(reloaded).getSettlements(group.id))
          .single
          .amount,
      150,
    );
  });

  test('deleting a group removes everything that belongs to it', () async {
    final store = LocalStore(prefs);
    final groups = LocalGroupRepository(store);
    final group = await groups.createGroup(name: 'Hory', creator: creator);
    final other = await groups.createGroup(name: 'Byt', creator: creator);
    final me = (await groups.getMembers(group.id)).first;

    await LocalExpenseRepository(store).saveExpense(
      Expense(
        id: 'e1',
        groupId: group.id,
        paidByMemberId: me.id,
        totalAmount: 100,
        title: 'Oběd',
        createdAt: DateTime(2026),
      ),
      [ExpenseSplit(id: 's1', expenseId: 'e1', memberId: me.id, amountOwed: 100)],
    );

    await groups.deleteGroup(group.id);

    expect((await groups.getGroups()).single.id, other.id);
    expect(store.members.every((m) => m.groupId == other.id), isTrue);
    expect(store.expenses, isEmpty);
    expect(store.splits, isEmpty);
  });

  test('renaming the user updates their memberships', () async {
    final groups = LocalGroupRepository(LocalStore(prefs));
    final group = await groups.createGroup(name: 'Hory', creator: creator);
    await groups.addVirtualMember(groupId: group.id, displayName: 'Honza');

    await groups.renameUserMembers('user-1', 'Karel');

    final names = (await groups.getMembers(group.id)).map((m) => m.displayName);
    expect(names, ['Karel', 'Honza']);
  });
}
