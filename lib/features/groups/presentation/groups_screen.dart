import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/config/theme.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/ui/receipt_widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/text_formatter.dart';
import '../../auth/presentation/onboarding_view.dart';
import '../../auth/presentation/profile_sheet.dart';
import '../application/group_providers.dart';
import 'create_group_sheet.dart';
import 'group_visuals.dart';

/// First screen: what to settle today, and all groups with the user's
/// balance in each. On first launch it shows the guest onboarding instead.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return profile.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Nepodařilo se načíst data: $error')),
      ),
      data: (user) =>
          user == null ? const OnboardingView() : const _GroupsView(),
    );
  }
}

class _GroupsView extends ConsumerWidget {
  const _GroupsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupListProvider);
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: groupsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Nepodařilo se načíst skupiny: $error')),
          data: (groups) => Column(
            children: [
              _Header(name: profile?.name ?? ''),
              Expanded(
                child: groups.isEmpty
                    ? const _EmptyState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        children: [
                          _TodaySlip(groups: groups),
                          const SizedBox(height: 26),
                          SectionTitle(
                            'Skupiny',
                            trailing: Text(
                              TextFormatter.plural(
                                groups.length,
                                'skupina',
                                'skupiny',
                                'skupin',
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          for (final group in groups) ...[
                            _GroupCard(detail: group),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
              ),
              _BottomActions(empty: groups.isEmpty),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;

  const _Header({required this.name});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Moje skupiny',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Profil a IBAN',
            child: Material(
              color: AppColors.slip,
              shape: const StadiumBorder(
                side: BorderSide(color: AppColors.outline),
              ),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => showProfileSheet(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InitialsAvatar(
                        name: name.isEmpty ? 'Ty' : name,
                        tint: AppColors.mint,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Profil',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Dnes vyřešit": every open debt that involves the user, across groups.
class _TodaySlip extends StatelessWidget {
  final List<GroupDetail> groups;

  const _TodaySlip({required this.groups});

  @override
  Widget build(BuildContext context) {
    final rows = <_TodoRow>[];
    for (final g in groups) {
      for (final debt in g.myDebts) {
        final incoming = debt.toMemberId == g.me!.id;
        final other = incoming ? debt.fromMemberId : debt.toMemberId;
        final virtual = g.member(other)?.isVirtual ?? false;
        rows.add(
          _TodoRow(
            groupId: g.group.id,
            who: g.memberName(other),
            verb: incoming ? 'ti dluží' : 'dostane od tebe',
            amount: incoming ? debt.amount : -debt.amount,
            note:
                '${g.group.name} · '
                '${incoming ? (virtual ? 'bez aplikace' : 'ukázat QR') : 'pošli platbu'}',
          ),
        );
      }
    }
    rows.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
    final total = groups.fold<double>(0, (s, g) => s + g.myBalance);

    return Slip(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Expanded(
                child: Text(
                  'Dnes vyřešit',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                DateFormat('d. M. yyyy').format(DateTime.now()),
                style: AppFonts.money(
                  size: 11,
                  weight: FontWeight.w400,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Nikdo nikomu nic nedluží.',
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
            )
          else
            for (final row in rows.take(5)) row,
          const SizedBox(height: 8),
          const DashedRule(),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  total > 0.005
                      ? 'Celkem k dobru'
                      : (total < -0.005 ? 'Celkem dlužíš' : 'Vyrovnáno'),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
              Text(
                CurrencyFormatter.compact(total, signed: true),
                style: AppFonts.money(
                  size: 22,
                  color: AppTheme.balanceColor(total),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  final String groupId;
  final String who;
  final String verb;
  final double amount;
  final String note;

  const _TodoRow({
    required this.groupId,
    required this.who,
    required this.verb,
    required this.amount,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(RouteNames.groupDetail(groupId)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LeaderRow(
                label: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: who,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: ' $verb',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                amount: CurrencyFormatter.compact(amount, signed: true),
                amountStyle: AppFonts.money(
                  size: 14,
                  color: AppTheme.balanceColor(amount),
                ),
              ),
              Text(
                note,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final GroupDetail detail;

  const _GroupCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final balance = detail.myBalance;
    final label = balance > 0.005
        ? 'Dluží ti'
        : (balance < -0.005 ? 'Dlužíš' : 'Vyrovnáno');

    return Material(
      color: AppColors.slip,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(RouteNames.groupDetail(detail.group.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: detail.group.type.tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(detail.group.type.icon, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${TextFormatter.people(detail.members.length)} · '
                      '${TextFormatter.expenses(detail.expenses.length)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    CurrencyFormatter.compact(balance, signed: true),
                    style: AppFonts.money(
                      color: AppTheme.balanceColor(balance),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// First launch: a tilted sample receipt and a short explanation.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final mono = AppFonts.money(size: 14, weight: FontWeight.w400);
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 36, 32, 16),
      children: [
        Transform.rotate(
          angle: -0.026,
          child: Slip(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'TAKHLE TO BUDE VYPADAT',
                  textAlign: TextAlign.center,
                  style: AppFonts.money(
                    size: 12,
                    weight: FontWeight.w400,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                LeaderRow(
                  label: const Text('Pivo ×3'),
                  amount: 'Ty + Pepa',
                  amountStyle: mono,
                ),
                const SizedBox(height: 8),
                LeaderRow(
                  label: const Text('Pizza'),
                  amount: 'Kája',
                  amountStyle: mono,
                ),
                const SizedBox(height: 10),
                const DashedRule(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pepa ti pošle',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '+142 Kč',
                      style: AppFonts.money(size: 14, color: AppColors.emerald),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 36),
        const Text(
          'Zatím žádná skupina',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Založ skupinu pro výlet, byt nebo dnešní večer v hospodě. '
          'Vyfoť účtenku a hned uvidíte, kdo komu kolik pošle.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppColors.mutedStrong,
          ),
        ),
      ],
    );
  }
}

class _BottomActions extends ConsumerWidget {
  final bool empty;

  const _BottomActions({required this.empty});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: empty ? 'Vytvořit první skupinu' : 'Vytvořit skupinu',
            icon: empty ? null : LucideIcons.plus,
            onPressed: () => showCreateGroupSheet(context),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Připojit se · QR nebo kód',
            kind: AppButtonKind.ghost,
            height: 48,
            icon: LucideIcons.qrCode,
            onPressed: () => _showJoinInfo(context),
          ),
        ],
      ),
    );
  }

  void _showJoinInfo(BuildContext context) {
    showPaperSheet<void>(
      context,
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Připojit se ke skupině'),
          const SizedBox(height: 8),
          const Text(
            'Skupiny jsou zatím uložené jen v tomto telefonu. Připojit se '
            'ke skupině někoho jiného půjde, až přibude online '
            'synchronizace. Do té doby tě může přidat jako člena bez '
            'aplikace.',
            style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.body),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Rozumím',
            kind: AppButtonKind.dark,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
