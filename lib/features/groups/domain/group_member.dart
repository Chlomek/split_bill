/// Model matching the "group_members" table in Supabase.
/// Supports both registered users and virtual friends (unregistered attendees).
class GroupMember {
  final String id;
  final String groupId;
  final String? userId;
  final String displayName;
  final bool isVirtual;

  const GroupMember({
    required this.id,
    required this.groupId,
    this.userId,
    required this.displayName,
    this.isVirtual = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'user_id': userId,
      'display_name': displayName,
      'is_virtual': isVirtual,
    };
  }

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      userId: json['user_id'] as String?,
      displayName: json['display_name'] as String? ?? 'Member',
      isVirtual: json['is_virtual'] as bool? ?? false,
    );
  }
}
