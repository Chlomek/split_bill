import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/config/theme.dart';
import '../../../core/ui/receipt_widgets.dart';
import '../../../core/utils/iban_validator.dart';
import '../../groups/application/group_providers.dart';
import '../data/profile_repository.dart';

/// "Kam ti mají přijít peníze?" sheet. Returns the saved IBAN, or null when
/// the user chose "Teď ne".
///
/// [context] text explains why it is asked (e.g. "Pepa ti dluží 900 Kč.").
Future<String?> showIbanSetupSheet(
  BuildContext context, {
  String? reason,
  String saveLabel = 'Uložit',
}) {
  return showPaperSheet<String>(
    context,
    (_) => _IbanSetupSheet(reason: reason, saveLabel: saveLabel),
  );
}

class _IbanSetupSheet extends ConsumerStatefulWidget {
  final String? reason;
  final String saveLabel;

  const _IbanSetupSheet({required this.reason, required this.saveLabel});

  @override
  ConsumerState<_IbanSetupSheet> createState() => _IbanSetupSheetState();
}

class _IbanSetupSheetState extends ConsumerState<_IbanSetupSheet> {
  final _iban = TextEditingController();
  final _account = TextEditingController();
  int _tab = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref.read(ibanProvider.future).then((value) {
      if (!mounted || value == null || value.isEmpty) return;
      setState(() {
        _iban.text = IbanValidator.pretty(value);
        _account.text = IbanValidator.toCzechAccount(value) ?? '';
      });
    });
  }

  @override
  void dispose() {
    _iban.dispose();
    _account.dispose();
    super.dispose();
  }

  String? get _result {
    if (_tab == 0) {
      final value = IbanValidator.normalize(_iban.text);
      return IbanValidator.isValid(value) ? value : null;
    }
    return IbanValidator.fromCzechAccount(_account.text);
  }

  Future<void> _save() async {
    final iban = _result;
    if (iban == null || _saving) return;
    setState(() => _saving = true);
    await ref.read(profileRepositoryProvider).setIban(iban);
    ref.invalidate(ibanProvider);
    if (mounted) Navigator.of(context).pop(iban);
  }

  @override
  Widget build(BuildContext context) {
    final normalized = IbanValidator.normalize(_iban.text);
    final ibanHint = normalized.isEmpty || normalized.startsWith('CZ')
        ? 'Český IBAN začíná CZ a má 24 znaků'
        : 'Zahraniční IBAN, zkontroluj ho';
    final accountTyped = _account.text.trim().isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Kam ti mají přijít peníze?'),
          const SizedBox(height: 4),
          Text(
            '${widget.reason == null ? '' : '${widget.reason} '}'
            'Aby ti mohli zaplatit přes QR, potřebuješ zadat svůj účet. '
            'Stačí to jednou.',
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.mutedStrong,
            ),
          ),
          const SizedBox(height: 18),
          SegmentTabs(
            labels: const ['IBAN', 'Číslo účtu / banka'],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 18),
          if (_tab == 0) ...[
            const FieldLabel('IBAN'),
            TextField(
              controller: _iban,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              style: AppFonts.money(
                size: 16,
                weight: FontWeight.w400,
              ).copyWith(letterSpacing: 0.4),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'CZ65 0800 0000 1920 0014 5399',
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    ibanHint,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mutedStrong,
                    ),
                  ),
                ),
                if (normalized.startsWith('CZ'))
                  Text(
                    '${normalized.length} / ${IbanValidator.czLength}',
                    style: AppFonts.money(
                      size: 13,
                      color: AppColors.mutedStrong,
                    ),
                  ),
              ],
            ),
          ] else ...[
            const FieldLabel('Číslo účtu / kód banky'),
            TextField(
              controller: _account,
              autocorrect: false,
              keyboardType: TextInputType.visiblePassword,
              style: AppFonts.money(size: 16, weight: FontWeight.w400),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: '19-2000145399/0800'),
            ),
            const SizedBox(height: 6),
            Text(
              accountTyped && _result == null
                  ? 'Číslo účtu nesedí, zkontroluj ho i kód banky'
                  : (_result != null
                        ? 'IBAN: ${IbanValidator.pretty(_result!)}'
                        : 'Předčíslí je nepovinné'),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedStrong,
              ),
            ),
          ],
          const SizedBox(height: 18),
          PaperCard(
            radius: 14,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.lock, size: 20, color: AppColors.emerald),
                SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Zůstane jen v tomto telefonu',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text:
                              ' v šifrovaném úložišti a na server se '
                              'neposílá. Ostatní ho uvidí, jen když jim sám(a) '
                              'ukážeš QR kód nebo platební údaje.',
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.body,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: widget.saveLabel,
            onPressed: _result != null && !_saving ? _save : null,
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.ink,
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text(
              'Teď ne',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
