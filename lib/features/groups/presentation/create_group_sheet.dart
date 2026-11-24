import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/env.dart';
import '../../../core/config/theme.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/ui/receipt_widgets.dart';
import '../application/group_providers.dart';
import '../domain/group.dart';
import 'group_visuals.dart';

/// Opens the "Nová skupina" sheet.
Future<void> showCreateGroupSheet(BuildContext context) {
  return showPaperSheet<void>(context, (_) => const _CreateGroupSheet());
}

/// "K7P29QXA" -> "K7P 29Q XA" for reading aloud.
String formatInviteCode(String code) {
  final buffer = StringBuffer();
  for (var i = 0; i < code.length; i++) {
    if (i > 0 && i % 3 == 0) buffer.write(' ');
    buffer.write(code[i]);
  }
  return buffer.toString();
}

/// Shares the group's invite link through the system share sheet.
Future<void> shareInvite(Group group) {
  final link = DeepLinkService(
    appDomain: Env.appDomain,
  ).buildInviteUniversalLink(group.inviteCode);
  return Share.share(
    'Přidej se do skupiny „${group.name}“ ve Split Bill: $link '
    '(kód ${group.inviteCode})',
  );
}

class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet();

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _name = TextEditingController();
  final _draft = TextEditingController();
  final List<String> _members = [];
  GroupType _type = GroupType.trip;
  Group? _created;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _draft.dispose();
    super.dispose();
  }

  void _addMember() {
    final value = _draft.text.trim();
    if (value.isNotEmpty && !_members.contains(value)) {
      setState(() => _members.add(value));
    }
    _draft.clear();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    if (_draft.text.trim().isNotEmpty) _addMember();
    setState(() => _saving = true);
    final group = await ref
        .read(groupActionsProvider)
        .createGroup(name, type: _type, otherMembers: _members);
    if (mounted) setState(() => _created = group);
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: created?.name ?? 'Nová skupina'),
          const SizedBox(height: 8),
          if (created == null) ..._form() else ..._done(created),
        ],
      ),
    );
  }

  List<Widget> _form() {
    final canCreate = _name.text.trim().isNotEmpty && !_saving;
    return [
      const FieldLabel('Název'),
      TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(hintText: 'Např. Chata Krkonoše'),
      ),
      const SizedBox(height: 16),
      const FieldLabel('Na co je'),
      Row(
        children: [
          for (final type in GroupType.values) ...[
            if (type != GroupType.values.first) const SizedBox(width: 6),
            Expanded(
              child: _TypeTile(
                type: type,
                selected: type == _type,
                onTap: () => setState(() => _type = type),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 16),
      const FieldLabel('Kdo bude ve skupině'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const ShapeDecoration(
              color: AppColors.ink,
              shape: StadiumBorder(),
            ),
            child: const Center(
              widthFactor: 1,
              child: Text(
                'Ty',
                style: TextStyle(
                  color: AppColors.slip,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          for (final member in _members)
            Container(
              height: 40,
              padding: const EdgeInsets.only(left: 14, right: 2),
              decoration: const ShapeDecoration(
                color: AppColors.slip,
                shape: StadiumBorder(
                  side: BorderSide(color: AppColors.outline),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    member,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    tooltip: 'Odebrat $member',
                    iconSize: 14,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _members.remove(member)),
                    icon: const Icon(
                      LucideIcons.x,
                      color: AppColors.mutedStrong,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _draft,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _addMember(),
              decoration: const InputDecoration(
                hintText: 'Jméno, třeba Pepa',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            label: 'Přidat',
            kind: AppButtonKind.outline,
            height: 48,
            onPressed: _addMember,
          ),
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        'Stačí jména. Kdo aplikaci má, připojí se pozvánkou a svůj profil '
        'převezme.',
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      const SizedBox(height: 18),
      AppButton(
        label: 'Vytvořit skupinu',
        onPressed: canCreate ? _create : null,
      ),
    ];
  }

  List<Widget> _done(Group group) {
    return [
      const Text(
        'Skupina je připravená. Pošli ostatním pozvánku.',
        style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.body),
      ),
      const SizedBox(height: 14),
      PaperCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kód pozvánky',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatInviteCode(group.inviteCode),
                    style: AppFonts.money(size: 24).copyWith(letterSpacing: 2),
                  ),
                ],
              ),
            ),
            AppButton(
              label: 'Kopírovat',
              kind: AppButtonKind.ghost,
              height: 44,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: group.inviteCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kód zkopírován.')),
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'Sdílet pozvánku',
              kind: AppButtonKind.outline,
              onPressed: () => shareInvite(group),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppButton(
              label: 'Otevřít skupinu',
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.push(RouteNames.groupDetail(group.id));
              },
            ),
          ),
        ],
      ),
    ];
  }
}

class _TypeTile extends StatelessWidget {
  final GroupType type;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.slip : AppColors.ink;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.ink : AppColors.slip,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? AppColors.ink : AppColors.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(type.icon, size: 20, color: fg),
                const SizedBox(height: 4),
                Text(
                  type.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
