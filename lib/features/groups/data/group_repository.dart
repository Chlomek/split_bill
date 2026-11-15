import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/storage/local_store.dart';
import '../../auth/domain/user_profile.dart';
import '../domain/group.dart';
import '../domain/group_member.dart';

/// Storage contract for groups and their members. The UI only talks to this
/// interface, so the local implementation can later be replaced by Supabase.
abstract class GroupRepository {
  Future<List<Group>> getGroups();

  Future<Group?> getGroup(String groupId);

  /// Creates a group and adds [creator] as its first member.
  Future<Group> createGroup({required String name, required UserProfile creator});

  Future<void> renameGroup(String groupId, String name);

  /// Deletes the group with all its members, expenses and settlements.
  Future<void> deleteGroup(String groupId);

  Future<List<GroupMember>> getMembers(String groupId);

  /// Adds a member who has no account yet (`is_virtual = true`).
  Future<GroupMember> addVirtualMember({
    required String groupId,
    required String displayName,
  });

  /// Updates the display name of every membership owned by [userId].
  Future<void> renameUserMembers(String userId, String displayName);
}

class LocalGroupRepository implements GroupRepository {
  final LocalStore _store;
  final Uuid _uuid = const Uuid();

  LocalGroupRepository(this._store);

  @override
  Future<List<Group>> getGroups() async => List.unmodifiable(_store.groups);

  @override
  Future<Group?> getGroup(String groupId) async {
    for (final group in _store.groups) {
      if (group.id == groupId) return group;
    }
    return null;
  }

  @override
  Future<Group> createGroup({
    required String name,
    required UserProfile creator,
  }) async {
    final group = Group(
      id: _uuid.v4(),
      name: name,
      inviteCode: _generateInviteCode(),
      createdBy: creator.id,
      createdAt: DateTime.now(),
    );
    _store.groups.add(group);
    _store.members.add(
      GroupMember(
        id: _uuid.v4(),
        groupId: group.id,
        userId: creator.id,
        displayName: creator.name,
      ),
    );
    await _store.save();
    return group;
  }

  @override
  Future<void> renameGroup(String groupId, String name) async {
    final index = _store.groups.indexWhere((g) => g.id == groupId);
    if (index < 0) return;
    final old = _store.groups[index];
    _store.groups[index] = Group(
      id: old.id,
      name: name,
      inviteCode: old.inviteCode,
      createdBy: old.createdBy,
      createdAt: old.createdAt,
    );
    await _store.save();
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    final expenseIds = _store.expenses
        .where((e) => e.groupId == groupId)
        .map((e) => e.id)
        .toSet();
    _store.splits.removeWhere((s) => expenseIds.contains(s.expenseId));
    _store.expenses.removeWhere((e) => e.groupId == groupId);
    _store.settlements.removeWhere((s) => s.groupId == groupId);
    _store.members.removeWhere((m) => m.groupId == groupId);
    _store.groups.removeWhere((g) => g.id == groupId);
    await _store.save();
  }

  @override
  Future<List<GroupMember>> getMembers(String groupId) async =>
      _store.members.where((m) => m.groupId == groupId).toList();

  @override
  Future<GroupMember> addVirtualMember({
    required String groupId,
    required String displayName,
  }) async {
    final member = GroupMember(
      id: _uuid.v4(),
      groupId: groupId,
      displayName: displayName,
      isVirtual: true,
    );
    _store.members.add(member);
    await _store.save();
    return member;
  }

  @override
  Future<void> renameUserMembers(String userId, String displayName) async {
    for (var i = 0; i < _store.members.length; i++) {
      final member = _store.members[i];
      if (member.userId != userId) continue;
      _store.members[i] = GroupMember(
        id: member.id,
        groupId: member.groupId,
        userId: member.userId,
        displayName: displayName,
        isVirtual: member.isVirtual,
      );
    }
    await _store.save();
  }

  /// Short code without look-alike characters (0/O, 1/I).
  String _generateInviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(8, (_) => alphabet[random.nextInt(alphabet.length)])
        .join();
  }
}

final groupRepositoryProvider = Provider<GroupRepository>(
  (ref) => LocalGroupRepository(ref.watch(localStoreProvider)),
);
