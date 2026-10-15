import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/utils/currency_formatter.dart';
import '../domain/receipt_scan_result.dart';
import '../domain/scanned_receipt_item.dart';

/// Screen corresponding to Sketch 3 in the design specification:
/// Assigning receipt items to specific group members, handling tips/discrepancies,
/// and selecting who paid.
class AssignItemsScreen extends StatefulWidget {
  final ReceiptScanResult? scanResult;

  const AssignItemsScreen({super.key, this.scanResult});

  @override
  State<AssignItemsScreen> createState() => _AssignItemsScreenState();
}

class _AssignItemsScreenState extends State<AssignItemsScreen> {
  late List<ScannedReceiptItem> _items;
  final List<String> _members = ['Pepa', 'Honza (bez účtu)', 'Franta', 'Kája (Vy)'];
  String _paidBy = 'Franta';
  double? _scannedTotal;

  @override
  void initState() {
    super.initState();
    _scannedTotal = widget.scanResult?.totalAmount;
    _items = widget.scanResult?.items.isNotEmpty == true
        ? List.from(widget.scanResult!.items)
        : [
            ScannedReceiptItem(name: 'Pizza Margherita', price: 190.0, assignedMemberIds: ['Pepa']),
            ScannedReceiptItem(name: 'Plzeňské pivo 12°', price: 60.0, quantity: 2, assignedMemberIds: ['Franta', 'Kája (Vy)']),
            ScannedReceiptItem(name: 'Domácí limonáda', price: 65.0, assignedMemberIds: ['Honza (bez účtu)']),
          ];
  }

  double get _itemsTotal =>
      _items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  double get _discrepancy {
    if (_scannedTotal == null) return 0.0;
    return _scannedTotal! - _itemsTotal;
  }

  void _toggleMemberAssignment(ScannedReceiptItem item, String memberName) {
    setState(() {
      final assigned = List<String>.from(item.assignedMemberIds);
      if (assigned.contains(memberName)) {
        assigned.remove(memberName);
      } else {
        assigned.add(memberName);
      }
      final index = _items.indexOf(item);
      _items[index] = item.copyWith(assignedMemberIds: assigned);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Přidat položku ručně'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Název položky',
                hintText: 'Např. Káva, Dezert',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cena (Kč)',
                hintText: '85',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0;
              if (name.isNotEmpty && price > 0) {
                setState(() {
                  _items.add(ScannedReceiptItem(name: name, price: price));
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('Přidat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final finalTotal = _scannedTotal ?? _itemsTotal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Přiřazení položek'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Přidat položku ručně',
            onPressed: _showAddItemDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Discrepancy / Tips Notice
          if (_discrepancy.abs() > 0.01)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.lightbulb, size: 20, color: Color(0xFFB45309)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Zjištěn rozdíl / dýško (${_discrepancy > 0 ? "+" : ""}${CurrencyFormatter.format(_discrepancy)}): automaticky rozpočteno poměrně mezi všechny.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text('Žádné položky na účtence. Přidejte položku pomocí tlačítka + nahoře.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final assignedCount = item.assignedMemberIds.length;
                      final perPerson = assignedCount > 0
                          ? (item.price * item.quantity) / assignedCount
                          : (item.price * item.quantity);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.quantity > 1
                                          ? '${item.name} (${item.quantity}x)'
                                          : item.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(item.price * item.quantity),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.x, size: 16, color: Colors.grey),
                                    onPressed: () => _removeItem(index),
                                    tooltip: 'Smazat položku',
                                  ),
                                ],
                              ),
                              Text(
                                assignedCount > 0
                                    ? '${CurrencyFormatter.format(perPerson)} / osoba ($assignedCount vybráno)'
                                    : 'Vyberte, kdo konzumoval:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: assignedCount > 0
                                      ? const Color(0xFF10B981)
                                      : Colors.grey,
                                  fontWeight: assignedCount > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _members.map((member) {
                                  final isAssigned = item.assignedMemberIds.contains(member);
                                  return FilterChip(
                                    label: Text(
                                      member,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isAssigned ? FontWeight.bold : FontWeight.normal,
                                        color: isAssigned ? const Color(0xFF047857) : Colors.black87,
                                      ),
                                    ),
                                    selected: isAssigned,
                                    selectedColor: const Color(0xFF10B981).withAlpha(40),
                                    checkmarkColor: const Color(0xFF10B981),
                                    onSelected: (_) => _toggleMemberAssignment(item, member),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Footer: Payer Selection & Confirm Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Kdo platil: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          DropdownButton<String>(
                            value: _paidBy,
                            underline: const SizedBox(),
                            items: _members.map((m) {
                              return DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _paidBy = val);
                            },
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Celkem', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            CurrencyFormatter.format(finalTotal),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(LucideIcons.check),
                      label: const Text('Potvrdit a rozpočítat dluh'),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Účtenka byla úspěšně zpracována a dluhy rozpočítány!'),
                          ),
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
