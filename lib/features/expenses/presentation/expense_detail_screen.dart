import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/config/theme.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/ui/receipt_widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/presentation/group_visuals.dart';
import '../../receipt_scan/presentation/assign_items_screen.dart';
import '../domain/expense.dart';
import '../domain/expense_item.dart';

/// One expense: its receipt lines (when it came from a scan), who had what,
/// and who owes how much.
class ExpenseDetailScreen extends ConsumerWidget {
  final String groupId;
  final String expenseId;

  const ExpenseDetailScreen({
    super.key,
    required this.groupId,
    required this.expenseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(groupDetailProvider(groupId)).valueOrNull;
    final expense = d?.expenses.where((e) => e.id == expenseId).firstOrNull;
    if (d == null || expense == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: d == null
              ? const CircularProgressIndicator()
              : const Text('Výdaj už neexistuje.'),
        ),
      );
    }

    final items = d.itemsOf(expense.id);
    final splits = d.splitsOf(expense.id)
      ..sort((a, b) {
        if (a.memberId == expense.paidByMemberId) return -1;
        if (b.memberId == expense.paidByMemberId) return 1;
        return b.amountOwed.compareTo(a.amountOwed);
      });
    final payerIsMe = expense.paidByMemberId == d.me?.id;
    final itemsTotal = items.fold<double>(0, (s, i) => s + i.lineTotal);
    final difference = expense.totalAmount - itemsTotal;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Zpět do skupiny',
                    onPressed: () => context.pop(),
                    icon: const Icon(LucideIcons.chevronLeft, size: 24),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${d.group.name} · '
                          '${DateFormat('d. M. yyyy, H:mm').format(expense.createdAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                children: [
                  Slip(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(text: 'Platil(a): '),
                                    TextSpan(
                                      text: payerIsMe
                                          ? 'ty'
                                          : d.memberName(
                                              expense.paidByMemberId,
                                            ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                            Text(
                              switch (expense.source) {
                                'ai' => 'přečteno AI',
                                'device' => 'přečteno v telefonu',
                                _ => 'zadáno ručně',
                              },
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const DashedRule(),
                        const SizedBox(height: 10),
                        if (items.isNotEmpty) ...[
                          for (final item in items) ...[
                            _ItemLine(item: item, detail: d),
                            const SizedBox(height: 10),
                          ],
                          const DashedRule(),
                          const SizedBox(height: 10),
                          _sumRow('Položky', itemsTotal),
                          if (difference.abs() > 0.004) ...[
                            const SizedBox(height: 6),
                            _sumRow(
                              difference > 0 ? 'Spropitné' : 'Sleva',
                              difference,
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Expanded(
                              child: Text(
                                'Celkem',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              CurrencyFormatter.compact(expense.totalAmount),
                              style: AppFonts.money(size: 20),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionTitle('Kdo kolik'),
                  PaperCard(
                    child: Column(
                      children: [
                        for (final (i, split) in splits.indexed)
                          Container(
                            constraints: const BoxConstraints(minHeight: 52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: i == 0
                                  ? null
                                  : const Border(
                                      top: BorderSide(
                                        color: AppColors.hairline,
                                      ),
                                    ),
                            ),
                            child: _shareRow(
                              d,
                              expense,
                              split.memberId,
                              split.amountOwed,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  AppButton(
                    label: 'Smazat',
                    kind: AppButtonKind.danger,
                    onPressed: () => _delete(context, ref, expense),
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        label: 'Upravit rozdělení',
                        kind: AppButtonKind.dark,
                        onPressed: () => context.push(
                          RouteNames.assignItems(groupId),
                          extra: AssignItemsArgs(expenseId: expense.id),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sumRow(String label, double amount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
        Text(
          CurrencyFormatter.compact(amount),
          style: AppFonts.money(
            size: 13,
            weight: FontWeight.w400,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }

  Widget _shareRow(
    GroupDetail d,
    Expense expense,
    String memberId,
    double amount,
  ) {
    final isPayer = memberId == expense.paidByMemberId;
    final payerIsMe = expense.paidByMemberId == d.me?.id;
    final isMe = memberId == d.me?.id;
    final String note;
    if (isPayer) {
      note = isMe ? 'tvůj díl, už zaplaceno' : 'platil(a), už zaplaceno';
    } else if (payerIsMe) {
      note = 'ti pošle';
    } else if (isMe) {
      note = 'pošleš: ${d.memberName(expense.paidByMemberId)}';
    } else {
      note = 'pošle: ${displayName(d, expense.paidByMemberId)}';
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName(d, memberId),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                note,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        Text(
          isPayer || !payerIsMe
              ? CurrencyFormatter.compact(amount)
              : '+${CurrencyFormatter.compact(amount)}',
          style: AppFonts.money(
            size: 14,
            color: isPayer
                ? AppColors.muted
                : (payerIsMe ? AppColors.emerald : AppColors.ink),
          ),
        ),
      ],
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) async {
    final confirmed = await showPaperSheet<bool>(
      context,
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Smazat výdaj?', showClose: false),
          const SizedBox(height: 8),
          Text(
            'Výdaj „${expense.title}“ se odebere a zůstatky se přepočítají.',
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
                  label: 'Smazat',
                  kind: AppButtonKind.danger,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final router = GoRouter.of(context);
    await ref.read(groupActionsProvider).deleteExpense(expense.id);
    router.pop();
  }
}

class _ItemLine extends StatelessWidget {
  final ExpenseItem item;
  final GroupDetail detail;

  const _ItemLine({required this.item, required this.detail});

  @override
  Widget build(BuildContext context) {
    final members = detail.members.map((m) => m.id).toList();
    final takers = members.where((m) => (item.pieces[m] ?? 0) > 0).toList();
    String who;
    if (item.everyone) {
      who = 'Všichni rovným dílem';
    } else if (takers.isEmpty) {
      who = item.restToEveryone ? 'Všichni rovným dílem' : '';
    } else if (item.quantity <= 1) {
      final names = takers.map((m) => displayName(detail, m)).toList();
      who = names.length == 2 ? '${names.join(' a ')} napůl' : names.join(', ');
    } else {
      who = takers
          .map((m) => '${displayName(detail, m)} ${item.pieces[m]}×')
          .join(' · ');
      if (item.restToEveryone) who += ' · zbytek všem';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LeaderRow(
          label: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (item.quantity > 1)
                  TextSpan(
                    text: '  ${item.quantity} ks',
                    style: AppFonts.money(
                      size: 12,
                      weight: FontWeight.w400,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
            style: const TextStyle(fontSize: 14),
          ),
          amount: CurrencyFormatter.compact(item.lineTotal),
          amountStyle: AppFonts.money(size: 14),
        ),
        if (who.isNotEmpty || item.discount > 0.005)
          Text(
            [
              if (who.isNotEmpty) who,
              if (item.discount > 0.005)
                'sleva −${CurrencyFormatter.compact(item.discount)}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
      ],
    );
  }
}
