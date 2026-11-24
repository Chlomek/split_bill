import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/config/theme.dart';
import '../application/group_providers.dart';
import '../domain/group.dart';

/// Icon, tint and label of each group type.
extension GroupTypeVisuals on GroupType {
  IconData get icon => switch (this) {
    GroupType.trip => LucideIcons.mountain,
    GroupType.home => LucideIcons.house,
    GroupType.night => LucideIcons.wine,
    GroupType.other => LucideIcons.ellipsis,
  };

  Color get tint => switch (this) {
    GroupType.trip => const Color(0xFFE2EDE3),
    GroupType.home => const Color(0xFFE8E2F0),
    GroupType.night => const Color(0xFFF3DCC8),
    GroupType.other => const Color(0xFFE4E0D6),
  };

  String get label => switch (this) {
    GroupType.trip => 'Výlet',
    GroupType.home => 'Byt',
    GroupType.night => 'Večer',
    GroupType.other => 'Jiné',
  };
}

/// Avatar tint of a member: mint for the current user, grey for members
/// without the app, otherwise by position in the group.
Color memberTint(GroupDetail detail, String memberId) {
  if (memberId == detail.me?.id) return AppColors.mint;
  final member = detail.member(memberId);
  if (member?.isVirtual ?? false) return const Color(0xFFE4E0D6);
  final index = detail.members.indexWhere((m) => m.id == memberId);
  return AppColors.avatarTints[(index < 0 ? 0 : index) %
      AppColors.avatarTints.length];
}

/// Display name, with the current user shown as "Ty".
String displayName(GroupDetail detail, String memberId) =>
    memberId == detail.me?.id ? 'Ty' : detail.memberName(memberId);
