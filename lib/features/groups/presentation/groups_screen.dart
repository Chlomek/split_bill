import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/config/theme.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/text_formatter.dart';
import '../../auth/presentation/onboarding_view.dart';
import '../../auth/presentation/profile_sheet.dart';
import '../application/group_providers.dart';

/// First screen of the app: all groups of the user with the user's balance in
/// each of them. On first launch it shows the guest onboarding instead.
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return profile.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: Center(child: Text('Nepodařilo se načíst data: $error'))),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje skupiny'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.user),
            tooltip: 'Můj profil a IBAN',
            onPressed: () => showProfileSheet(context),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Nepodařilo se načíst skupiny: $error')),
        data: (groups) {
          final totalBalance = groups.fold<double>(
            0.0,
            (sum, g) => sum + (g.me != null ? g.balances[g.me!.id] ?? 0 : 0),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TotalBalanceCard(totalBalance: totalBalance),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Vaše skupiny',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: const Text('Nová skupina'),
                    onPressed: () => _showCreateGroupDialog(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (groups.isEmpty)
                const _EmptyGroups()
              else
                ...groups.map(
                  (group) => _GroupCard(
                    detail: group,
                    onTap: () =>
                        context.push(RouteNames.groupDetail(group.group.id)),
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(LucideIcons.link),
                label: const Text('Připojit se ke skupině kódem'),
                onPressed: () => _showJoinInfoDialog(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreateGroupDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nová skupina'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (value) => Navigator.of(context).pop(value),
          decoration: const InputDecoration(
            labelText: 'Název skupiny',
            hintText: 'Např. Hory 2026, Spolubydlící',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Vytvořit'),
          ),
        ],
      ),
    );

    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;

    final group = await ref.read(groupActionsProvider).createGroup(trimmed);
    if (context.mounted) context.push(RouteNames.groupDetail(group.id));
  }

  void _showJoinInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Připojení kódem'),
        content: const Text(
          'Skupiny jsou zatím uložené jen v tomto zařízení. Připojení ke '
          'skupině někoho jiného bude fungovat, jakmile přibude online '
          'synchronizace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Rozumím'),
          ),
        ],
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(LucideIcons.users, size: 40, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Zatím nemáte žádnou skupinu',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'Vytvořte první a přidejte do ní přátele.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _TotalBalanceCard extends StatelessWidget {
  final double totalBalance;

  const _TotalBalanceCard({required this.totalBalance});

  @override
  Widget build(BuildContext context) {
    final isPositive = totalBalance > 0.005;
    final isNegative = totalBalance < -0.005;

    final String statusText = isPositive
        ? 'Celkově vám přátelé dluží'
        : (isNegative
            ? 'Celkově dlužíte přátelům'
            : 'Všechny vaše účty jsou vyrovnané');

    final List<Color> gradient = isPositive
        ? const [Color(0xFF10B981), Color(0xFF059669)]
        : (isNegative
            ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
            : const [Color(0xFF4B5563), Color(0xFF374151)]);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                statusText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(LucideIcons.wallet, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(totalBalance.abs()),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final GroupDetail detail;
  final VoidCallback onTap;

  const _GroupCard({required this.detail, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = detail.group.name;
    final balance = detail.me != null ? detail.balances[detail.me!.id] ?? 0.0 : 0.0;
    final balanceColor = AppTheme.balanceColor(balance);
    final String balanceLabel = balance > 0.005
        ? 'Dluží vám'
        : (balance < -0.005 ? 'Dlužíte' : 'Vyrovnáno');
    final activity = detail.lastActivity ?? detail.group.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name.characters.first.toUpperCase() : 'S',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${TextFormatter.memberCount(detail.members.length)} • '
                      '${TextFormatter.relativeDate(activity)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    balanceLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: balanceColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(balance.abs()),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: balanceColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
