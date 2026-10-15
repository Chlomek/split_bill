import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/services/export_service.dart';
import '../../../core/services/qr_payment_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/debt_simplifier.dart';
import '../domain/settlement_debt.dart';

/// Screen presenting the debt summary, CSV export action,
/// and SPAYD QR payment generation.
class SettlementsScreen extends StatefulWidget {
  const SettlementsScreen({super.key});

  @override
  State<SettlementsScreen> createState() => _SettlementsScreenState();
}

class _SettlementsScreenState extends State<SettlementsScreen> {
  late List<SettlementDebt> _debts;

  @override
  void initState() {
    super.initState();
    // Sample balances: Pepa: -400, Franta: 0, Kája: +200, Barča: +200
    _debts = DebtSimplifier.simplifyDebts({
      'Pepa': -400.0,
      'Franta': 0.0,
      'Kája': 200.0,
      'Barča': 200.0,
    });
  }

  void _showQrPaymentDialog(SettlementDebt debt) {
    // Generate Czech SPAYD string (using standard demo IBAN)
    final spaydPayload = QrPaymentService.generateSpayd(
      iban: 'CZ6508000000192000145399',
      amount: debt.amount,
      currency: 'CZK',
      message: 'Vyrovnani Split Bill',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${debt.fromMemberId} ➔ ${debt.toMemberId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Částka: ${CurrencyFormatter.format(debt.amount)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              width: 200,
              child: QrImageView(
                data: spaydPayload,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Naskenujte v bankovní aplikaci (QR Platba)',
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

  Future<void> _exportCsv() async {
    final rows = [
      ['Dlužník', 'Věřitel', 'Částka', 'Měna'],
      ..._debts.map((d) => [d.fromMemberId, d.toMemberId, d.amount, d.currency]),
    ];

    await ExportService.exportAndShareExpensesCsv(
      groupName: 'Patecni_Vecere',
      rows: rows,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vyrovnání dluhů'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.download),
            tooltip: 'Exportovat do CSV',
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: _debts.isEmpty
          ? const Center(
              child: Text(
                'Všechny účty jsou vyrovnané! 🎉',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _debts.length,
              itemBuilder: (context, index) {
                final debt = _debts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF10B981),
                      child: Icon(LucideIcons.arrowRight, color: Colors.white, size: 18),
                    ),
                    title: Text(
                      '${debt.fromMemberId} dluží ${debt.toMemberId}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(CurrencyFormatter.format(debt.amount)),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(LucideIcons.qrCode, size: 16),
                      label: const Text('QR Platba'),
                      onPressed: () => _showQrPaymentDialog(debt),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
