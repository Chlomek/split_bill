import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/domain/user_profile.dart';
import '../../features/expenses/domain/expense.dart';
import '../../features/expenses/domain/expense_item.dart';
import '../../features/expenses/domain/expense_split.dart';
import '../../features/groups/domain/group.dart';
import '../../features/groups/domain/group_member.dart';
import '../../features/settlements/domain/settlement.dart';

/// On-device persistence for all app data: one versioned JSON document
/// stored in shared preferences. The local repositories read and mutate the
/// in-memory lists and call [save] afterwards.
class LocalStore {
  static const String storageKey = 'split_bill_data';
  static const int schemaVersion = 1;

  final SharedPreferences _prefs;

  UserProfile? profile;
  final List<Group> groups = [];
  final List<GroupMember> members = [];
  final List<Expense> expenses = [];
  final List<ExpenseSplit> splits = [];
  final List<ExpenseItem> expenseItems = [];
  final List<Settlement> settlements = [];

  LocalStore(this._prefs) {
    _load();
  }

  void _load() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return;

    final Map<String, dynamic> doc;
    try {
      doc = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // Unreadable document: start empty rather than crash on launch.
      return;
    }

    List<T> read<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final list = doc[key] as List<dynamic>? ?? const [];
      return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    }

    final profileJson = doc['profile'] as Map<String, dynamic>?;
    profile = profileJson != null ? UserProfile.fromJson(profileJson) : null;
    groups.addAll(read('groups', Group.fromJson));
    members.addAll(read('members', GroupMember.fromJson));
    expenses.addAll(read('expenses', Expense.fromJson));
    splits.addAll(read('splits', ExpenseSplit.fromJson));
    expenseItems.addAll(read('expense_items', ExpenseItem.fromJson));
    settlements.addAll(read('settlements', Settlement.fromJson));
  }

  Future<void> save() async {
    final doc = {
      'version': schemaVersion,
      'profile': profile?.toJson(),
      'groups': groups.map((e) => e.toJson()).toList(),
      'members': members.map((e) => e.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'splits': splits.map((e) => e.toJson()).toList(),
      'expense_items': expenseItems.map((e) => e.toJson()).toList(),
      'settlements': settlements.map((e) => e.toJson()).toList(),
    };
    await _prefs.setString(storageKey, jsonEncode(doc));
  }
}

/// Overridden in `main()` with the instance loaded before the app starts.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final localStoreProvider = Provider<LocalStore>(
  (ref) => LocalStore(ref.watch(sharedPreferencesProvider)),
);
