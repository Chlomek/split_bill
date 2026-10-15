import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/utils/currency_formatter.dart';
import '../domain/receipt_scan_result.dart';
import '../domain/scanned_receipt_item.dart';

/// Screen corresponding to Sketch 3 in the design doc:
/// Assigning receipt items to specific group members and choosing who paid.
class AssignItemsScreen extends StatefulWidget {
  final ReceiptScanResult? scanResult;

  const AssignItemsScreen({super.key, this.scanResult});

  @override
  State<AssignItemsScreen> createState() => _AssignItemsScreenState();
}

class _AssignItemsScreenState extends State<AssignItemsScreen> {
  late List<ScannedReceiptItem> _items;
  final List<String> _members = ['Pepa', 'Franta', 'Kája'];
  String _paidBy = 'Franta';

  @override
  void initState() {
    super.initState();
    _items = widget.scanResult?.items.isNotEmpty == true
        ? List.from(widget.scanResult!.items)
        : [
            ScannedReceiptItem(name: 'Mléko', price: 20.0, assignedMemberIds: ['Pepa', 'Kája']),
            ScannedReceiptItem(name: 'Chléb', price: 20.0, assignedMemberIds: ['Franta']),
          ];
  }

  double get _totalAmount =>
      _items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Přiřazení položek'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Přidat položku ručně',
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
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
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(item.price),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Vyberte, kdo konzumoval:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: _members.map((member) {
                            final isAssigned =
                                item.assignedMemberIds.contains(member);
                            return FilterChip(
                              label: Text(member),
                              selected: isAssigned,
                              selectedColor: const Color(0xFF10B981).withAlpha(40),
                              checkmarkColor: const Color(0xFF10B981),
                              onSelected: (_) =>
                                  _toggleMemberAssignment(item, member),
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

          // Payer & Total Confirmation Section (Sketch 3 footer)
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
                          const Text('Kdo platil: ', style: TextStyle(fontWeight: FontWeight.w600)),
                          DropdownButton<String>(
                            value: _paidBy,
                            underline: const SizedBox(),
                            items: _members.map((m) {
                              return DropdownMenuItem(value: m, child: Text(m));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _paidBy = val);
                            },
                          ),
                        ],
                      ),
                      Text(
                        'Celkem: ${CurrencyFormatter.format(_totalAmount)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
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
