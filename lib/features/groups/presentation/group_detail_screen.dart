import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/env.dart';
import '../../../core/config/theme.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/services/deep_link_service.dart';
import '../../../core/services/export_service.dart';
import '../../../core/services/qr_payment_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/text_formatter.dart';
import '../../auth/presentation/profile_sheet.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/presentation/add_expense_sheet.dart';
import '../../settlements/domain/settlement.dart';
import '../../settlements/domain/settlement_debt.dart';
import '../application/group_providers.dart';
import '../domain/group_member.dart';

enum _GroupMenuAction { export, rename, delete }

/// The hub of one group: who should pay whom (with QR payment and
/// "mark as paid"), balances of all members, and the history of expenses.
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

class _GroupDetailView extends ConsumerWidget {
  final GroupDetail detail;

  const _GroupDetailView({required this.detail});

  String get _groupId => detail.group.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = <Object>[...detail.expenses, ...detail.settlements]
      ..sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.group.name),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.userPlus),
            tooltip: 'Pozvat do skupiny',
            onPressed: () => _showInviteDialog(context),
          ),
          PopupMenuButton<_GroupMenuAction>(
            tooltip: 'Další možnosti',
            onSelected: (action) => _onMenuAction(context, ref, action),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _GroupMenuAction.export,
                child: Text('Exportovat do CSV'),
              ),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Settlement overview ---
          const _SectionTitle('Přehled vyrovnání'),
          if (detail.debts.isEmpty)
            const _InfoCard(
              icon: LucideIcons.check,
              text: 'Vše je vyrovnáno, nikdo nikomu nic nedluží.',
            )
          else
            ...detail.debts.map(
              (debt) => _DebtCard(
                debt: debt,
                fromName: detail.memberName(debt.fromMemberId),
                toName: detail.memberName(debt.toMemberId),
                onQr: () => _showQrPayment(context, ref, debt),
                onMarkPaid: () => _confirmMarkPaid(context, ref, debt),
              ),
            ),
          const SizedBox(height: 24),

          // --- Member balances ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionTitle('Zůstatky členů'),
              Text(
                TextFormatter.memberCount(detail.members.length),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          ...detail.members.map(
            (member) => _MemberBalanceTile(
              member: member,
              balance: detail.balances[member.id] ?? 0,
              isCurrentUser: member.id == detail.me?.id,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Přidat člena bez účtu'),
              onPressed: () => _showAddMemberDialog(context, ref),
            ),
          ),
          const SizedBox(height: 16),

          // --- History ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionTitle('Historie výdajů'),
              Text(
                'Celkem ${CurrencyFormatter.format(detail.totalSpent)}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          if (history.isEmpty)
            const _InfoCard(
              icon: LucideIcons.receipt,
              text: 'Zatím žádné výdaje. Vyfoťte účtenku nebo zadejte výdaj ručně.',
            )
          else
            ...history.map(
              (entry) => entry is Expense
                  ? _ExpenseTile(
                      expense: entry,
                      payerName: detail.memberName(entry.paidByMemberId),
                      onTap: () => _showExpenseDetail(context, ref, entry),
                    )
                  : _SettlementTile(
                      settlement: entry as Settlement,
                      fromName: detail.memberName(entry.fromMemberId),
                      toName: detail.memberName(entry.toMemberId),
                      onTap: () => _confirmDeleteSettlement(context, ref, entry),
                    ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Zadat ručně'),
                  onPressed: () => showAddExpenseSheet(context, _groupId),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(LucideIcons.camera),
                  label: const Text('Vyfotit účtenku'),
                  onPressed: () => context.push(RouteNames.scanReceipt(_groupId)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static DateTime _dateOf(Object entry) =>
      entry is Expense ? entry.createdAt : (entry as Settlement).createdAt;

  // ---------------------------------------------------------------------
  // Settlement actions
  // ---------------------------------------------------------------------

  Future<void> _showQrPayment(
    BuildContext context,
    WidgetRef ref,
    SettlementDebt debt,
  ) async {
    final creditorName = detail.memberName(debt.toMemberId);

    // The IBAN never leaves the creditor's phone, so only the creditor's own
    // device can build the payment code.
    if (debt.toMemberId != detail.me?.id) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('QR platba'),
          content: Text(
            'QR kód pro tuto platbu zobrazí $creditorName ve své aplikaci. '
            'IBAN příjemce zůstává uložený jen v jeho zařízení.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Rozumím'),
            ),
          ],
        ),
      );
      return;
    }

    final iban = await ref.read(ibanProvider.future);
    if (!context.mounted) return;

    if (iban == null || iban.isEmpty) {
      final openProfile = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chybí váš IBAN'),
          content: const Text(
            'Aby vám ostatní mohli zaplatit přes QR kód, uložte si nejdřív '
            'svůj IBAN v profilu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Zrušit'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Otevřít profil'),
            ),
          ],
        ),
      );
      if (openProfile == true && context.mounted) await showProfileSheet(context);
      return;
    }

    final payload = QrPaymentService.generateSpayd(
      iban: iban,
      amount: debt.amount,
      currency: debt.currency,
      message: 'Split Bill',
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${detail.memberName(debt.fromMemberId)} ➔ $creditorName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.format(debt.amount),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              width: 220,
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ukažte kód dlužníkovi, naskenuje ho ve své bankovní aplikaci.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zavřít'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmMarkPaid(
    BuildContext context,
    WidgetRef ref,
    SettlementDebt debt,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Označit za zaplacené?'),
        content: Text(
          '${detail.memberName(debt.fromMemberId)} zaplatil(a) '
          '${CurrencyFormatter.format(debt.amount)} členovi '
          '${detail.memberName(debt.toMemberId)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Zaplaceno'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(groupActionsProvider).addSettlement(
          groupId: _groupId,
          fromMemberId: debt.fromMemberId,
          toMemberId: debt.toMemberId,
          amount: debt.amount,
        );
  }

  Future<void> _confirmDeleteSettlement(
    BuildContext context,
    WidgetRef ref,
    Settlement settlement,
  ) async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Smazat vyrovnání?',
      message:
          'Platba ${CurrencyFormatter.format(settlement.amount)} se odebere a '
          'dluh se vrátí do přehledu.',
    );
    if (confirmed) {
      await ref.read(groupActionsProvider).deleteSettlement(settlement.id);
    }
  }

  // ---------------------------------------------------------------------
  // Members
  // ---------------------------------------------------------------------

  Future<void> _showAddMemberDialog(BuildContext context, WidgetRef ref) async {
    final name = await _promptText(
      context,
      title: 'Přidat člena bez účtu',
      label: 'Jméno',
      hint: 'Např. Honza',
      confirmLabel: 'Přidat',
    );
    if (name == null) return;
    await ref.read(groupActionsProvider).addVirtualMember(_groupId, name);
  }

  // ---------------------------------------------------------------------
  // Expenses
  // ---------------------------------------------------------------------

  Future<void> _showExpenseDetail(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) async {
    final splits =
        detail.splits.where((s) => s.expenseId == expense.id).toList();

    final delete = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                expense.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('d. M. yyyy').format(expense.createdAt)} • '
                'Platil(a): ${detail.memberName(expense.paidByMemberId)} • '
                '${CurrencyFormatter.format(expense.totalAmount)}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text('Podíly', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...splits.map(
                (split) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(detail.memberName(split.memberId)),
                      Text(CurrencyFormatter.format(split.amountOwed)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.negativeColor,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Smazat výdaj'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (delete != true || !context.mounted) return;
    final confirmed = await _confirmDelete(
      context,
      title: 'Smazat výdaj?',
      message: 'Výdaj „${expense.title}“ se odebere a zůstatky se přepočítají.',
    );
    if (confirmed) {
      await ref.read(groupActionsProvider).deleteExpense(expense.id);
    }
  }

  // ---------------------------------------------------------------------
  // Group actions
  // ---------------------------------------------------------------------

  void _showInviteDialog(BuildContext context) {
    final link = DeepLinkService(appDomain: Env.appDomain)
        .buildInviteUniversalLink(detail.group.inviteCode);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pozvat do skupiny'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kód pozvánky:'),
            const SizedBox(height: 4),
            SelectableText(
              detail.group.inviteCode,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Připojení přes odkaz začne fungovat s online synchronizací. '
              'Do té doby přidejte přátele jako členy bez účtu.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zavřít'),
          ),
          ElevatedButton.icon(
            icon: const Icon(LucideIcons.share2, size: 16),
            label: const Text('Sdílet odkaz'),
            onPressed: () {
              Navigator.of(context).pop();
              Share.share(
                'Přidej se do skupiny „${detail.group.name}“ ve Split Bill: $link',
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _onMenuAction(
    BuildContext context,
    WidgetRef ref,
    _GroupMenuAction action,
  ) async {
    switch (action) {
      case _GroupMenuAction.export:
        await _exportCsv();
      case _GroupMenuAction.rename:
        final name = await _promptText(
          context,
          title: 'Přejmenovat skupinu',
          label: 'Název skupiny',
          initialValue: detail.group.name,
          confirmLabel: 'Uložit',
        );
        if (name != null) {
          await ref.read(groupActionsProvider).renameGroup(_groupId, name);
        }
      case _GroupMenuAction.delete:
        final confirmed = await _confirmDelete(
          context,
          title: 'Smazat skupinu?',
          message:
              'Skupina „${detail.group.name}“ se smaže včetně všech výdajů a '
              'vyrovnání. Tuto akci nelze vrátit.',
        );
        if (!confirmed) return;
        await ref.read(groupActionsProvider).deleteGroup(_groupId);
        if (context.mounted) context.go(RouteNames.home);
    }
  }

  Future<void> _exportCsv() async {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final rows = <List<dynamic>>[
      ['Datum', 'Typ', 'Název', 'Platil', 'Komu / za koho', 'Částka', 'Měna'],
    ];

    for (final expense in detail.expenses) {
      for (final split
          in detail.splits.where((s) => s.expenseId == expense.id)) {
        rows.add([
          dateFormat.format(expense.createdAt),
          'Výdaj',
          expense.title,
          detail.memberName(expense.paidByMemberId),
          detail.memberName(split.memberId),
          split.amountOwed.toStringAsFixed(2),
          'CZK',
        ]);
      }
    }

    for (final settlement in detail.settlements) {
      rows.add([
        dateFormat.format(settlement.createdAt),
        'Vyrovnání',
        '',
        detail.memberName(settlement.fromMemberId),
        detail.memberName(settlement.toMemberId),
        settlement.amount.toStringAsFixed(2),
        'CZK',
      ]);
    }

    await ExportService.exportAndShareExpensesCsv(
      groupName: detail.group.name,
      rows: rows,
    );
  }

  // ---------------------------------------------------------------------
  // Dialog helpers
  // ---------------------------------------------------------------------

  /// Asks for a single line of text; returns null when cancelled or empty.
  Future<String?> _promptText(
    BuildContext context, {
    required String title,
    required String label,
    required String confirmLabel,
    String? hint,
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (value) => Navigator.of(context).pop(value),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<bool> _confirmDelete(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.negativeColor),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Smazat'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: const TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final SettlementDebt debt;
  final String fromName;
  final String toName;
  final VoidCallback onQr;
  final VoidCallback onMarkPaid;

  const _DebtCard({
    required this.debt,
    required this.fromName,
    required this.toName,
    required this.onQr,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$fromName ➔ $toName',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  CurrencyFormatter.format(debt.amount),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(LucideIcons.qrCode, size: 16),
                  label: const Text('QR platba'),
                  onPressed: onQr,
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: const Text('Zaplaceno'),
                  onPressed: onMarkPaid,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberBalanceTile extends StatelessWidget {
  final GroupMember member;
  final double balance;
  final bool isCurrentUser;

  const _MemberBalanceTile({
    required this.member,
    required this.balance,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.balanceColor(balance);
    final name = member.displayName;
    final String status = balance > 0.005
        ? 'Má dostat zpět'
        : (balance < -0.005 ? 'Dluží skupině' : 'Vyrovnáno');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Text(
            name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (isCurrentUser) const _Badge('Vy', AppTheme.primaryColor),
            if (member.isVirtual) const _Badge('bez účtu', Colors.grey),
          ],
        ),
        subtitle: Text(status, style: const TextStyle(fontSize: 12)),
        trailing: Text(
          CurrencyFormatter.format(balance),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final String payerName;
  final VoidCallback onTap;

  const _ExpenseTile({
    required this.expense,
    required this.payerName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withAlpha(30),
          child: const Icon(
            LucideIcons.receipt,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        title: Text(
          expense.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Platil(a): $payerName • ${TextFormatter.relativeDate(expense.createdAt)}',
        ),
        trailing: Text(
          CurrencyFormatter.format(expense.totalAmount),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  final Settlement settlement;
  final String fromName;
  final String toName;
  final VoidCallback onTap;

  const _SettlementTile({
    required this.settlement,
    required this.fromName,
    required this.toName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.withAlpha(40),
          child: const Icon(LucideIcons.arrowRightLeft, color: Colors.grey, size: 20),
        ),
        title: Text(
          '$fromName ➔ $toName',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Vyrovnání • ${TextFormatter.relativeDate(settlement.createdAt)}',
        ),
        trailing: Text(
          CurrencyFormatter.format(settlement.amount),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        onTap: onTap,
      ),
    );
  }
}
