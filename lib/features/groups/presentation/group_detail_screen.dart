import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/config/theme.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/services/export_service.dart';
import '../../../core/ui/receipt_widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/text_formatter.dart';
import '../../auth/presentation/iban_setup_sheet.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/presentation/add_expense_sheet.dart';
import '../../settlements/domain/settlement.dart';
import '../../settlements/domain/settlement_debt.dart';
import '../application/group_providers.dart';
import '../domain/group_member.dart';
import 'create_group_sheet.dart';
import 'group_visuals.dart';

enum _GroupMenuAction { rename, delete }

/// The hub of one group: who should pay whom (the person being paid shows a
/// QR and confirms the money arrived), member balances, and the history.
class GroupDetailScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(groupDetailProvider(groupId));

    return detailAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Nepodařilo se načíst skupinu: $error')),
      ),
      data: (detail) {
        if (detail == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Tato skupina už neexistuje.')),
          );
        }
        return _GroupDetailView(detail: detail);
      },
    );
  }
}

class _GroupDetailView extends ConsumerStatefulWidget {
  final GroupDetail detail;

  const _GroupDetailView({required this.detail});

  @override
  ConsumerState<_GroupDetailView> createState() => _GroupDetailViewState();
}

class _GroupDetailViewState extends ConsumerState<_GroupDetailView> {
  /// Debt whose "Přišly peníze?" confirmation is open (from-to key).
  String? _confirming;
  bool _showAllHistory = false;

  GroupDetail get d => widget.detail;
  String get _groupId => d.group.id;

  static String _key(SettlementDebt debt) =>
      '${debt.fromMemberId}>${debt.toMemberId}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _settlementSlip(context),
                  const SizedBox(height: 24),
                  _members(context),
                  const SizedBox(height: 24),
                  _history(context),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(context),
    );
  }

  // ---------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Zpět na skupiny',
            onPressed: () => context.pop(),
            icon: const Icon(LucideIcons.chevronLeft, size: 24),
          ),
          Expanded(
            child: Text(
              d.group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => shareInvite(d.group),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.ink,
              minimumSize: const Size(44, 44),
            ),
            icon: const Icon(LucideIcons.userPlus, size: 18),
            label: const Text(
              'Pozvat',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          PopupMenuButton<_GroupMenuAction>(
            tooltip: 'Další možnosti',
            icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
            color: AppColors.slip,
            onSelected: (action) => _onMenu(context, action),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _GroupMenuAction.rename,
                child: Text('Přejmenovat skupinu'),
              ),
              PopupMenuItem(
                value: _GroupMenuAction.delete,
                child: Text('Smazat skupinu'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Vyrovnání
  // ---------------------------------------------------------------------

  Widget _settlementSlip(BuildContext context) {
    final meId = d.me?.id;
    final paidToMe =
        meId != null &&
        d.owedToMe.isEmpty &&
        d.settlements.any((s) => s.toMemberId == meId);

    return Slip(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Expanded(
                child: Text(
                  'Vyrovnání',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              if (d.debts.isNotEmpty)
                Text(
                  TextFormatter.plural(
                    d.debts.length,
                    'platba',
                    'platby',
                    'plateb',
                  ),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (d.debts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Vše je vyrovnáno, nikdo nikomu nic nedluží.',
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
            ),
          for (var i = 0; i < d.debts.length; i++)
            _debtRow(context, d.debts[i], first: i == 0),
          if (paidToMe) ...[
            const SizedBox(height: 8),
            const DashedRule(),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(LucideIcons.check, size: 18, color: AppColors.emeraldDark),
                SizedBox(width: 8),
                Text(
                  'Tobě už všichni zaplatili',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emeraldDark,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _debtRow(
    BuildContext context,
    SettlementDebt debt, {
    required bool first,
  }) {
    final meId = d.me?.id;
    final incoming = debt.toMemberId == meId;
    final outgoing = debt.fromMemberId == meId;
    final from = d.memberName(debt.fromMemberId);
    final to = d.memberName(debt.toMemberId);
    final confirming = _confirming == _key(debt);

    final label = incoming
        ? TextSpan(
            children: [
              TextSpan(
                text: from,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const TextSpan(
                text: ' ti dluží',
                style: TextStyle(color: AppColors.muted),
              ),
            ],
          )
        : outgoing
        ? TextSpan(
            children: [
              const TextSpan(
                text: 'Dlužíš ',
                style: TextStyle(color: AppColors.muted),
              ),
              TextSpan(
                text: to,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          )
        : TextSpan(
            children: [
              TextSpan(
                text: from,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const TextSpan(
                text: ' → ',
                style: TextStyle(color: AppColors.muted),
              ),
              TextSpan(
                text: to,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: first
            ? null
            : const Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LeaderRow(
            label: Text.rich(
              label,
              style: const TextStyle(fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
            amount: CurrencyFormatter.compact(debt.amount),
            amountStyle: AppFonts.money(
              color: incoming
                  ? AppColors.emerald
                  : (outgoing ? AppColors.red : AppColors.ink),
            ),
          ),
          if (incoming && !confirming) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Ukázat QR',
                    icon: LucideIcons.qrCode,
                    kind: AppButtonKind.outline,
                    height: 44,
                    onPressed: () => _openQr(context, debt),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Přišly peníze?',
                    kind: AppButtonKind.outline,
                    height: 44,
                    onPressed: () => setState(() => _confirming = _key(debt)),
                  ),
                ),
              ],
            ),
          ],
          if (confirming) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Zkontroluj v bance, že ti $from poslal(a) ',
                        ),
                        TextSpan(
                          text: CurrencyFormatter.compact(debt.amount),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: '. Zůstatky se pak přepočítají.'),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Ano, přišly',
                          height: 44,
                          onPressed: () => _markPaid(context, debt),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppButton(
                          label: 'Ještě ne',
                          kind: AppButtonKind.ghost,
                          height: 44,
                          onPressed: () => setState(() => _confirming = null),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openQr(BuildContext context, SettlementDebt debt) async {
    final router = GoRouter.of(context);
    var iban = await ref.read(ibanProvider.future);
    if (!context.mounted) return;
    if (iban == null || iban.isEmpty) {
      iban = await showIbanSetupSheet(
        context,
        reason:
            '${d.memberName(debt.fromMemberId)} ti dluží '
            '${CurrencyFormatter.compact(debt.amount)}.',
        saveLabel: 'Uložit a ukázat QR',
      );
      if (iban == null) return;
    }
    router.push(
      RouteNames.qrPayment(_groupId, fromMemberId: debt.fromMemberId),
    );
  }

  Future<void> _markPaid(BuildContext context, SettlementDebt debt) async {
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(groupActionsProvider);
    setState(() => _confirming = null);
    final settlement = await actions.addSettlement(
      groupId: _groupId,
      fromMemberId: debt.fromMemberId,
      toMemberId: debt.toMemberId,
      amount: debt.amount,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${d.memberName(debt.fromMemberId)} · '
          '${CurrencyFormatter.compact(debt.amount)} označeno jako zaplacené',
        ),
        action: SnackBarAction(
          label: 'Zpět',
          onPressed: () => actions.deleteSettlement(settlement.id),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Členové
  // ---------------------------------------------------------------------

  Widget _members(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Členové',
          trailing: Text(
            'celkem ${CurrencyFormatter.compact(d.totalSpent)}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        PaperCard(
          child: Column(
            children: [
              for (var i = 0; i < d.members.length; i++)
                _memberRow(context, d.members[i], first: i == 0),
              InkWell(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                onTap: () => _addMember(context),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.hairline)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        LucideIcons.plus,
                        size: 18,
                        color: AppColors.emerald,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Přidat člena bez aplikace',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.emerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _memberRow(
    BuildContext context,
    GroupMember member, {
    required bool first,
  }) {
    final isMe = member.id == d.me?.id;
    final balance = d.balances[member.id] ?? 0;
    final String status;
    if (isMe) {
      status = balance > 0.005
          ? 'Dostaneš celkem'
          : (balance < -0.005 ? 'Dlužíš celkem' : 'Vyrovnáno');
    } else {
      status = balance > 0.005
          ? 'dostane'
          : (balance < -0.005 ? 'dluží' : 'vyrovnáno');
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        border: first
            ? null
            : const Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          InitialsAvatar(
            name: isMe ? 'Ty' : member.displayName,
            tint: memberTint(d, member.id),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? 'Ty' : member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.isVirtual ? 'bez aplikace · $status' : status,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    if (member.isVirtual)
                      Flexible(
                        child: InkWell(
                          onTap: () => shareInvite(d.group),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: Text(
                              '· pozvat',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.emeraldDark,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            isMe
                ? CurrencyFormatter.compact(balance, signed: true)
                : CurrencyFormatter.compact(balance.abs()),
            style: AppFonts.money(
              size: 14,
              color: isMe ? AppTheme.balanceColor(balance) : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addMember(BuildContext context) async {
    final name = await _promptText(
      context,
      title: 'Přidat člena bez aplikace',
      hint: 'Jméno, třeba Honza',
      confirmLabel: 'Přidat',
    );
    if (name == null) return;
    await ref.read(groupActionsProvider).addVirtualMember(_groupId, name);
  }

  // ---------------------------------------------------------------------
  // Historie
  // ---------------------------------------------------------------------

  Widget _history(BuildContext context) {
    final entries = <Object>[...d.expenses, ...d.settlements]
      ..sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
    final visible = _showAllHistory ? entries : entries.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Historie výdajů',
          trailing: entries.isEmpty
              ? null
              : TextButton.icon(
                  onPressed: _exportCsv,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(LucideIcons.download, size: 16),
                  label: const Text(
                    'Export CSV',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
        ),
        if (entries.isEmpty)
          const PaperCard(
            radius: 14,
            padding: EdgeInsets.all(14),
            child: Text(
              'Zatím žádné výdaje. Vyfoť účtenku nebo zadej výdaj ručně.',
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
          ),
        for (final entry in visible) ...[
          entry is Expense
              ? _expenseRow(context, entry)
              : _settlementRow(context, entry as Settlement),
          const SizedBox(height: 8),
        ],
        if (!_showAllHistory && entries.length > 3)
          TextButton(
            onPressed: () => setState(() => _showAllHistory = true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.emeraldDark,
              minimumSize: const Size.fromHeight(44),
            ),
            child: Text(
              'Zobrazit všech ${entries.length}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  Widget _historyTile({
    required String title,
    required String meta,
    required String amount,
    required VoidCallback onTap,
    bool muted = false,
  }) {
    return Material(
      color: muted ? AppColors.doneFill : AppColors.slip,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(amount, style: AppFonts.money(size: 14)),
              const SizedBox(width: 4),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: AppColors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _expenseRow(BuildContext context, Expense expense) {
    final payer = expense.paidByMemberId == d.me?.id
        ? 'ty'
        : d.memberName(expense.paidByMemberId);
    return _historyTile(
      title: expense.title,
      meta: 'Platil(a): $payer · ${TextFormatter.dateTime(expense.createdAt)}',
      amount: CurrencyFormatter.compact(expense.totalAmount),
      onTap: () => context.push(RouteNames.expenseDetail(_groupId, expense.id)),
    );
  }

  Widget _settlementRow(BuildContext context, Settlement settlement) {
    return _historyTile(
      title:
          '${displayName(d, settlement.fromMemberId)} → '
          '${displayName(d, settlement.toMemberId)}',
      meta: 'Vyrovnání · ${TextFormatter.dateTime(settlement.createdAt)}',
      amount: CurrencyFormatter.compact(settlement.amount),
      muted: true,
      onTap: () => _confirmDeleteSettlement(context, settlement),
    );
  }

  static DateTime _dateOf(Object entry) =>
      entry is Expense ? entry.createdAt : (entry as Settlement).createdAt;

  Future<void> _confirmDeleteSettlement(
    BuildContext context,
    Settlement settlement,
  ) async {
    final confirmed = await _confirm(
      context,
      title: 'Smazat vyrovnání?',
      message:
          'Platba ${CurrencyFormatter.compact(settlement.amount)} se '
          'odebere a dluh se vrátí do přehledu.',
      confirmLabel: 'Smazat',
    );
    if (confirmed) {
      await ref.read(groupActionsProvider).deleteSettlement(settlement.id);
    }
  }

  Future<void> _exportCsv() async {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final rows = <List<dynamic>>[
      ['Datum', 'Typ', 'Název', 'Platil', 'Komu / za koho', 'Částka', 'Měna'],
    ];
    for (final expense in d.expenses) {
      for (final split in d.splitsOf(expense.id)) {
        rows.add([
          dateFormat.format(expense.createdAt),
          'Výdaj',
          expense.title,
          d.memberName(expense.paidByMemberId),
          d.memberName(split.memberId),
          split.amountOwed.toStringAsFixed(2),
          'CZK',
        ]);
      }
    }
    for (final s in d.settlements) {
      rows.add([
        dateFormat.format(s.createdAt),
        'Vyrovnání',
        '',
        d.memberName(s.fromMemberId),
        d.memberName(s.toMemberId),
        s.amount.toStringAsFixed(2),
        'CZK',
      ]);
    }
    await ExportService.exportAndShareExpensesCsv(
      groupName: d.group.name,
      rows: rows,
    );
  }

  // ---------------------------------------------------------------------
  // Bottom bar and menu
  // ---------------------------------------------------------------------

  Widget _bottomBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Vyfotit účtenku',
                  icon: LucideIcons.camera,
                  fontSize: 15,
                  horizontalPadding: 10,
                  onPressed: () =>
                      context.push(RouteNames.scanReceipt(_groupId)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Zadat ručně',
                  icon: LucideIcons.pencil,
                  fontSize: 15,
                  horizontalPadding: 10,
                  kind: AppButtonKind.outline,
                  onPressed: () => showAddExpenseSheet(context, _groupId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, _GroupMenuAction action) async {
    switch (action) {
      case _GroupMenuAction.rename:
        final name = await _promptText(
          context,
          title: 'Přejmenovat skupinu',
          hint: 'Název skupiny',
          initialValue: d.group.name,
          confirmLabel: 'Uložit',
        );
        if (name != null) {
          await ref.read(groupActionsProvider).renameGroup(_groupId, name);
        }
      case _GroupMenuAction.delete:
        final confirmed = await _confirm(
          context,
          title: 'Smazat skupinu?',
          message:
              'Skupina „${d.group.name}“ se smaže včetně všech výdajů a '
              'vyrovnání. Tuto akci nelze vrátit.',
          confirmLabel: 'Smazat',
        );
        if (!confirmed) return;
        await ref.read(groupActionsProvider).deleteGroup(_groupId);
        if (context.mounted) context.go(RouteNames.home);
    }
  }

  Future<String?> _promptText(
    BuildContext context, {
    required String title,
    required String hint,
    required String confirmLabel,
    String? initialValue,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showPaperSheet<String>(
      context,
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: title),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (v) =>
                Navigator.of(context).pop(v.trim().isEmpty ? null : v.trim()),
            decoration: InputDecoration(hintText: hint),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: confirmLabel,
            onPressed: () {
              final v = controller.text.trim();
              Navigator.of(context).pop(v.isEmpty ? null : v);
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showPaperSheet<bool>(
      context,
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: title, showClose: false),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.body,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Zrušit',
                  kind: AppButtonKind.ghost,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: confirmLabel,
                  kind: AppButtonKind.danger,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
