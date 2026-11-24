import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/theme.dart';
import '../../../core/services/qr_payment_service.dart';
import '../../../core/ui/receipt_widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/iban_validator.dart';
import '../../auth/presentation/iban_setup_sheet.dart';
import '../../groups/application/group_providers.dart';
import '../domain/settlement.dart';
import '../domain/settlement_debt.dart';

enum _Step { idle, asking, done }

/// Full-screen QR payment shown by the person being paid. Walks through
/// everyone who owes them, one after another.
class QrPaymentScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String? fromMemberId;

  const QrPaymentScreen({super.key, required this.groupId, this.fromMemberId});

  @override
  ConsumerState<QrPaymentScreen> createState() => _QrPaymentScreenState();
}

class _QrPaymentScreenState extends ConsumerState<QrPaymentScreen> {
  /// Debts owed to the user when the screen opened; settling one does not
  /// reshuffle the queue.
  List<SettlementDebt>? _queue;
  int _index = 0;
  _Step _step = _Step.idle;
  Settlement? _recorded;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(groupDetailProvider(widget.groupId)).valueOrNull;
    final iban = ref.watch(ibanProvider).valueOrNull;

    if (detail != null && _queue == null) {
      final queue = detail.owedToMe;
      final start = queue.indexWhere(
        (d) => d.fromMemberId == widget.fromMemberId,
      );
      _queue = queue;
      _index = start < 0 ? 0 : start;
    }
    final queue = _queue ?? const <SettlementDebt>[];
    final debt = _index < queue.length ? queue[_index] : null;

    return Theme(
      data: Theme.of(
        context,
      ).copyWith(scaffoldBackgroundColor: AppColors.night),
      child: Scaffold(
        body: SafeArea(
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: AppColors.nightText),
            child: Column(
              children: [
                _header(context, detail, queue),
                Expanded(
                  child: detail == null
                      ? const Center(child: CircularProgressIndicator())
                      : debt == null
                      ? _nothingOwed(context)
                      : iban == null || iban.isEmpty
                      ? _noIban(context, detail, debt)
                      : _body(detail, debt, iban),
                ),
                if (detail != null &&
                    debt != null &&
                    iban != null &&
                    iban.isNotEmpty)
                  _footer(context, detail, debt, queue, iban),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    GroupDetail? detail,
    List<SettlementDebt> queue,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Zavřít',
            onPressed: () => context.pop(),
            icon: const Icon(LucideIcons.x, color: AppColors.nightText),
          ),
          Expanded(
            child: Text(
              detail == null
                  ? ''
                  : '${detail.group.name}'
                        '${queue.length > 1 ? ' · ${_index + 1} z ${queue.length}' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.nightMuted,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _nothingOwed(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Nikdo ti teď nic nedluží.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Zpět do skupiny',
            onDark: true,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }

  Widget _noIban(
    BuildContext context,
    GroupDetail detail,
    SettlementDebt debt,
  ) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pro QR platbu potřebuješ zadat svůj účet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Zadat účet',
            onDark: true,
            onPressed: () => showIbanSetupSheet(
              context,
              reason:
                  '${detail.memberName(debt.fromMemberId)} ti dluží '
                  '${CurrencyFormatter.compact(debt.amount)}.',
              saveLabel: 'Uložit a ukázat QR',
            ),
          ),
        ],
      ),
    );
  }

  String _message(GroupDetail detail, SettlementDebt debt) =>
      '${detail.group.name} · ${detail.memberName(debt.fromMemberId)}';

  Widget _body(GroupDetail detail, SettlementDebt debt, String iban) {
    final who = detail.memberName(debt.fromMemberId);
    final payload = QrPaymentService.generateSpayd(
      iban: iban,
      amount: debt.amount,
      currency: debt.currency,
      message: _message(detail, debt),
    );
    final fields = <(String, String)>[
      if (IbanValidator.toCzechAccount(iban) != null)
        ('Účet', IbanValidator.toCzechAccount(iban)!),
      ('IBAN', IbanValidator.pretty(iban)),
      ('Částka', CurrencyFormatter.format(debt.amount)),
      ('Zpráva', _message(detail, debt)),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      children: [
        Slip(
          darkShadow: true,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: AppColors.ink),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        '$who ti dluží',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.compact(debt.amount),
                      style: AppFonts.money(size: 26),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const DashedRule(),
                const SizedBox(height: 12),
                Semantics(
                  label:
                      'QR kód pro platbu '
                      '${CurrencyFormatter.compact(debt.amount)} od $who na '
                      'tvůj účet',
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      size: 230,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: AppColors.ink,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'QR Platba · ${debt.currency}',
                  style: AppFonts.money(
                    size: 12,
                    weight: FontWeight.w400,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Ukaž kód, ať ho $who naskenuje v bankovní aplikaci. Zesil jas '
          'displeje, ať se načte napoprvé.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppColors.nightMuted,
          ),
        ),
        const SizedBox(height: 14),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.nightPanel,
              borderRadius: BorderRadius.circular(14),
            ),
            child: ExpansionTile(
              title: const Text(
                'Platba ručně, bez QR',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nightText,
                ),
              ),
              iconColor: AppColors.nightText,
              collapsedIconColor: AppColors.nightText,
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              children: [
                for (final (label, value) in fields)
                  Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFF3A3934))),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.nightMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            value,
                            style: AppFonts.money(
                              size: 13,
                              weight: FontWeight.w400,
                              color: AppColors.nightText,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: value));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$label zkopírováno.')),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.nightText,
                            side: const BorderSide(
                              color: AppColors.nightOutline,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Kopírovat',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _footer(
    BuildContext context,
    GroupDetail detail,
    SettlementDebt debt,
    List<SettlementDebt> queue,
    String iban,
  ) {
    final who = detail.memberName(debt.fromMemberId);
    final next = _index + 1 < queue.length ? queue[_index + 1] : null;

    Widget content;
    switch (_step) {
      case _Step.idle:
        content = Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Přišly peníze?',
                kind: AppButtonKind.ghost,
                onDark: true,
                onPressed: () => setState(() => _step = _Step.asking),
              ),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: 'Sdílet',
              icon: LucideIcons.share2,
              kind: AppButtonKind.ghost,
              onDark: true,
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text:
                      'Platba pro Split Bill: ${CurrencyFormatter.format(debt.amount)}\n'
                      '${IbanValidator.toCzechAccount(iban) != null ? 'Účet: ${IbanValidator.toCzechAccount(iban)}\n' : ''}'
                      'IBAN: ${IbanValidator.pretty(iban)}\n'
                      'Zpráva: ${_message(detail, debt)}',
                ),
              ),
            ),
          ],
        );
      case _Step.asking:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Zkontroluj v bance, že ti $who poslal(a) '
              '${CurrencyFormatter.compact(debt.amount)}.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Ano, přišly',
                    onDark: true,
                    onPressed: () => _confirm(debt),
                  ),
                ),
                const SizedBox(width: 8),
                AppButton(
                  label: 'Ještě ne',
                  kind: AppButtonKind.ghost,
                  onDark: true,
                  onPressed: () => setState(() => _step = _Step.idle),
                ),
              ],
            ),
          ],
        );
      case _Step.done:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.check,
                  size: 18,
                  color: AppColors.mintBright,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$who: vyrovnáno.',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: _undo,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.mintBright,
                  ),
                  child: const Text(
                    'Vrátit',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (next != null)
              AppButton(
                label: 'Další: ${detail.memberName(next.fromMemberId)}',
                onDark: true,
                trailing: Text(
                  CurrencyFormatter.compact(next.amount),
                  style: AppFonts.money(size: 15, color: AppColors.mintInk),
                ),
                onPressed: () => setState(() {
                  _index++;
                  _step = _Step.idle;
                  _recorded = null;
                }),
              )
            else
              AppButton(
                label: 'Všichni ti zaplatili · Hotovo',
                onDark: true,
                onPressed: () => context.pop(),
              ),
          ],
        );
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.nightLine)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: content,
    );
  }

  Future<void> _confirm(SettlementDebt debt) async {
    final settlement = await ref
        .read(groupActionsProvider)
        .addSettlement(
          groupId: widget.groupId,
          fromMemberId: debt.fromMemberId,
          toMemberId: debt.toMemberId,
          amount: debt.amount,
        );
    if (mounted) {
      setState(() {
        _recorded = settlement;
        _step = _Step.done;
      });
    }
  }

  Future<void> _undo() async {
    final recorded = _recorded;
    if (recorded != null) {
      await ref.read(groupActionsProvider).deleteSettlement(recorded.id);
    }
    if (mounted) {
      setState(() {
        _recorded = null;
        _step = _Step.idle;
      });
    }
  }
}
