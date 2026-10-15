import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/utils/currency_formatter.dart';

/// First screen of the app: Group Selection Screen.
/// Displays user's total balance across all groups, cards for each group
/// showing the user's specific balance in that group, and group creation.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample groups with user's specific balance in each group
    final groups = [
      _GroupItemData(
        id: '1',
        name: 'Páteční večeře',
        memberCount: 3,
        userBalance: 200.0, // user is owed 200 CZK
        lastActivity: 'Dnes, 14:20',
      ),
      _GroupItemData(
        id: '2',
        name: 'Dovolená Chorvatsko',
        memberCount: 5,
        userBalance: -450.0, // user owes 450 CZK
        lastActivity: 'Včera',
      ),
      _GroupItemData(
        id: '3',
        name: 'Kancelář - Káva a svačiny',
        memberCount: 4,
        userBalance: 0.0, // balanced
        lastActivity: 'Před 3 dny',
      ),
    ];

    final double totalBalance =
        groups.fold(0.0, (sum, g) => sum + g.userBalance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje skupiny'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.user),
            tooltip: 'Můj profil & IBAN',
            onPressed: () => _showProfileDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Total Balance Overview Card
          _TotalBalanceCard(totalBalance: totalBalance),
          const SizedBox(height: 24),

          // Section Header with Add & Join actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Vaše aktivní skupiny',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Nová skupina'),
                onPressed: () => _showCreateGroupDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Group Cards List
          ...groups.map(
            (group) => _GroupCard(
              group: group,
              onTap: () {
                context.push('/group/${group.id}');
              },
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
            onPressed: () => _showJoinCodeDialog(context),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nová skupina'),
        content: TextField(
          controller: controller,
          autofocus: true,
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
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Vytvořit'),
          ),
        ],
      ),
    );
  }

  void _showJoinCodeDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zadejte kód pozvánky'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Kód pozvánky',
            hintText: 'Např. VECERE2026',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Připojit se'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profil a platby',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Vaše jméno (zobrazované v účtech)',
                hintText: 'Kája',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Váš IBAN (pro příjem plateb přes QR)',
                hintText: 'CZ6508000000192000145399',
                helperText: 'Uloženo pouze bezpečně v tomto zařízení',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Uložit změny'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalBalanceCard extends StatelessWidget {
  final double totalBalance;

  const _TotalBalanceCard({required this.totalBalance});

  @override
  Widget build(BuildContext context) {
    final isPositive = totalBalance > 0.01;
    final isNegative = totalBalance < -0.01;
    final isZero = !isPositive && !isNegative;

    final Color badgeColor = isZero
        ? Colors.grey
        : (isPositive ? const Color(0xFF10B981) : Colors.redAccent);

    final String statusText = isZero
        ? 'Všechny vaše účty jsou vyrovnané'
        : (isPositive ? 'Celkově vám přátelé dluží' : 'Celkově dlužíte přátelům');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [const Color(0xFF10B981), const Color(0xFF059669)]
              : (isNegative
                  ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                  : [const Color(0xFF4B5563), const Color(0xFF374151)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withAlpha(60),
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
  final _GroupItemData group;
  final VoidCallback onTap;

  const _GroupCard({
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = group.userBalance > 0.01;
    final isNegative = group.userBalance < -0.01;
    final isZero = !isPositive && !isNegative;

    final Color balanceColor = isZero
        ? Colors.grey
        : (isPositive ? const Color(0xFF10B981) : Colors.redAccent);

    final String balanceLabel = isZero
        ? 'Vyrovnáno'
        : (isPositive ? 'Dluží vám' : 'Dlužíte');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Group avatar icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    group.name.isNotEmpty ? group.name[0] : 'G',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Group title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(LucideIcons.users, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${group.memberCount} členové • ${group.lastActivity}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Prominent balance for current user in this group
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
                    CurrencyFormatter.format(group.userBalance.abs()),
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

class _GroupItemData {
  final String id;
  final String name;
  final int memberCount;
  final double userBalance;
  final String lastActivity;

  _GroupItemData({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.userBalance,
    required this.lastActivity,
  });
}
