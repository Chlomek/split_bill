import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/utils/currency_formatter.dart';

/// Main screen displaying the group overview, member balances (e.g., Pepa -400, Kája +200),
/// and the scan receipt action button.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Bill'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Group Switcher Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(LucideIcons.users, color: Color(0xFF10B981)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Páteční večeře',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '3 členové',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(LucideIcons.share2, size: 18),
                    label: const Text('Pozvat'),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Přehled zůstatků',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Member balances list (as drafted in design doc: Pepa -400, Franta 0, Kája +200)
          _MemberBalanceTile(
            name: 'Pepa',
            balance: -400.0,
          ),
          _MemberBalanceTile(
            name: 'Franta',
            balance: 0.0,
          ),
          _MemberBalanceTile(
            name: 'Kája',
            balance: 200.0,
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
}

class _MemberBalanceTile extends StatelessWidget {
  final String name;
  final double balance;

  const _MemberBalanceTile({
    required this.name,
    required this.balance,
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
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
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
