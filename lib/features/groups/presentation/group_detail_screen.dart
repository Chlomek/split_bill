import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/utils/currency_formatter.dart';

/// Screen displaying the specific group's details, all members' balances,
/// past expense history, and primary actions (Scan & Settle).
class GroupDetailScreen extends StatelessWidget {
  final String groupId;
  final String groupName;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    this.groupName = 'Páteční večeře',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.userPlus),
            tooltip: 'Pozvat do skupiny',
            onPressed: () {
              _showInviteDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings),
            tooltip: 'Nastavení skupiny',
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Total Group Spending Card
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Celkové útraty skupiny',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '1 850 Kč',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.receipt, color: Color(0xFF10B981)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Member Balances Header
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Zůstatky členů',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '3 členové',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Member balances list (matching Sketch 1 in design doc: Pepa -400, Franta 0, Kája +200)
          const _MemberBalanceTile(
            name: 'Pepa',
            balance: -400.0,
            isCurrentUser: false,
          ),
          const _MemberBalanceTile(
            name: 'Franta',
            balance: 0.0,
            isCurrentUser: false,
          ),
          const _MemberBalanceTile(
            name: 'Kája (Vy)',
            balance: 200.0,
            isCurrentUser: true,
          ),

          const SizedBox(height: 24),
          const Text(
            'Poslední účtenky',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Recent expenses sample
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE5E7EB),
                child: Icon(LucideIcons.coffee, color: Colors.black87, size: 20),
              ),
              title: const Text('Restaurace U Medvídka', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Platil: Franta • 3 položky'),
              trailing: const Text(
                '640 Kč',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onTap: () {},
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.arrowRightLeft),
                  label: const Text('Vyrovnání'),
                  onPressed: () => context.push(RouteNames.settlements),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(LucideIcons.camera),
                  label: const Text('Vyfotit'),
                  onPressed: () => context.push(RouteNames.scanReceipt),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pozvat do skupiny'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sdílejte odkaz nebo kód s přáteli:'),
            SizedBox(height: 12),
            SelectableText(
              'https://splitbill.app/invite/VECERE2026',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF10B981),
              ),
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
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _MemberBalanceTile extends StatelessWidget {
  final String name;
  final double balance;
  final bool isCurrentUser;

  const _MemberBalanceTile({
    required this.name,
    required this.balance,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = balance < 0;
    final isZero = balance == 0;
    final color = isZero
        ? Colors.grey
        : (isNegative ? Colors.redAccent : const Color(0xFF10B981));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Text(
            name.isNotEmpty ? name[0] : '?',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (isCurrentUser) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Vy',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          isZero
              ? 'Vyrovnáno'
              : (isNegative ? 'Dluží skupině' : 'Má dostat zpět'),
          style: const TextStyle(fontSize: 12),
        ),
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
