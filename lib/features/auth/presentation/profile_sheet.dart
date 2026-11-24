import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/config/theme.dart';
import '../../../core/ui/receipt_widgets.dart';
import '../../../core/utils/iban_validator.dart';
import '../../groups/application/group_providers.dart';
import 'iban_setup_sheet.dart';

/// Opens the profile sheet: display name and the account for QR payments.
Future<void> showProfileSheet(BuildContext context) {
  return showPaperSheet<void>(context, (_) => const _ProfileSheet());
}

class _ProfileSheet extends ConsumerStatefulWidget {
  const _ProfileSheet();

  @override
  ConsumerState<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends ConsumerState<_ProfileSheet> {
  final _name = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref.read(profileProvider.future).then((profile) {
      if (!mounted) return;
      setState(() {
        _name.text = profile?.name ?? '';
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await ref.read(groupActionsProvider).saveProfile(name: name);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final iban = ref.watch(ibanProvider).valueOrNull;
    final hasIban = iban != null && iban.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader(title: 'Profil'),
        const SizedBox(height: 8),
        const FieldLabel('Jméno'),
        TextField(
          controller: _name,
          enabled: _loaded,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Takhle tě uvidí ostatní',
          ),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Účet pro QR platby'),
        Material(
          color: AppColors.slip,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.outline),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => showIbanSetupSheet(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasIban ? IbanValidator.pretty(iban) : 'Zatím nezadán',
                      style: hasIban
                          ? AppFonts.money(size: 15, weight: FontWeight.w500)
                          : const TextStyle(
                              fontSize: 15,
                              color: AppColors.muted,
                            ),
                    ),
                  ),
                  Text(
                    hasIban ? 'Změnit' : 'Zadat',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.emeraldDark,
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: AppColors.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: 'Uložit',
          onPressed: _loaded && !_saving && _name.text.trim().isNotEmpty
              ? _save
              : null,
        ),
      ],
    );
  }
}
