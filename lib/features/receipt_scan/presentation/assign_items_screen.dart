import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/config/theme.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/split_calculator.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/domain/group_member.dart';
import '../domain/receipt_scan_result.dart';
import '../domain/scanned_receipt_item.dart';

/// Screen corresponding to Sketch 3 in the design specification:
/// assigning receipt items to group members, handling tips/discrepancies,
/// selecting who paid, and saving the result as an expense of the group.
class AssignItemsScreen extends ConsumerStatefulWidget {
  final String groupId;
  final ReceiptScanResult? scanResult;

  const AssignItemsScreen({super.key, required this.groupId, this.scanResult});

  @override
  ConsumerState<AssignItemsScreen> createState() => _AssignItemsScreenState();
}

class _AssignItemsScreenState extends ConsumerState<AssignItemsScreen> {
  late List<ScannedReceiptItem> _items;
  double? _scannedTotal;
  String? _paidBy;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _scannedTotal = widget.scanResult?.totalAmount;
    _items = List.of(widget.scanResult?.items ?? const <ScannedReceiptItem>[]);
  }

  double get _itemsTotal =>
      _items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  double get _discrepancy =>
      _scannedTotal == null ? 0.0 : _scannedTotal! - _itemsTotal;

  bool get _allAssigned =>
      _items.isNotEmpty && _items.every((i) => i.assignedMemberIds.isNotEmpty);

  void _toggleMember(int index, String memberId) {
    setState(() {
      final assigned = List<String>.of(_items[index].assignedMemberIds);
      assigned.contains(memberId)
          ? assigned.remove(memberId)
          : assigned.add(memberId);
      _items[index] = _items[index].copyWith(assignedMemberIds: assigned);
    });
  }

  void _assignAll(int index, List<GroupMember> members) {
    setState(() {
      final everyone = members.map((m) => m.id).toList();
      final alreadyAll =
          _items[index].assignedMemberIds.length == everyone.length;
      _items[index] = _items[index]
          .copyWith(assignedMemberIds: alreadyAll ? <String>[] : everyone);
    });
  }

  /// Dialog for adding a new item or editing an existing one.
  Future<void> _showItemDialog({int? index}) async {
    final existing = index != null ? _items[index] : null;
    final nameController = TextEditingController(text: existing?.name);
    final priceController = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '',
    );
    final quantityController =
        TextEditingController(text: '${existing?.quantity ?? 1}');

    final result = await showDialog<ScannedReceiptItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Přidat položku' : 'Upravit položku'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Název položky',
                hintText: 'Např. Káva, Dezert',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Cena za kus (Kč)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Počet',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
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
              final price = CurrencyFormatter.tryParse(priceController.text);
              final quantity = int.tryParse(quantityController.text.trim()) ?? 1;
              if (name.isEmpty || price == null || price == 0 || quantity < 1) {
                return;
              }
              Navigator.of(context).pop(
                existing != null
                    ? existing.copyWith(
                        name: name,
                        price: price,
                        quantity: quantity,
                        // A hand-edited price no longer matches the scanned
                        // discount, so drop the note.
                        discount: price == existing.price &&
                                quantity == existing.quantity
                            ? existing.discount
                            : 0,
                      )
                    : ScannedReceiptItem(
                        name: name,
                        price: price,
                        quantity: quantity,
                      ),
              );
            },
            child: Text(existing == null ? 'Přidat' : 'Uložit'),
          ),
        ],
      ),
    );

    if (result == null) return;
    setState(() {
      if (index != null) {
        _items[index] = result;
      } else {
        _items.add(result);
      }
    });
  }

  Future<void> _confirm() async {
    final paidBy = _paidBy;
    if (paidBy == null || !_allAssigned || _saving) return;
    setState(() => _saving = true);

    final shares = SplitCalculator.splitItems(
      items: _items,
      scannedTotal: _scannedTotal,
    );
    final merchant = widget.scanResult?.merchantName?.trim() ?? '';

    await ref.read(groupActionsProvider).addExpense(
          groupId: widget.groupId,
          title: merchant.isNotEmpty ? merchant : 'Účtenka',
          paidByMemberId: paidBy,
          shares: shares,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Výdaj uložen a dluhy přepočítány.')),
    );
    // Back to the group, dropping the scan and assign screens from the stack.
    context.go(RouteNames.groupDetail(widget.groupId));
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(groupDetailProvider(widget.groupId));
    final detail = detailAsync.valueOrNull;

    if (detail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Přiřazení položek')),
        body: Center(
          child: detailAsync.isLoading
              ? const CircularProgressIndicator()
              : const Text('Skupina nebyla nalezena.'),
        ),
      );
    }

    final members = detail.members;
    _paidBy ??= detail.me?.id ?? (members.isNotEmpty ? members.first.id : null);
    final finalTotal = _scannedTotal ?? _itemsTotal;
    final unassignedCount =
        _items.where((i) => i.assignedMemberIds.isEmpty).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Přiřazení položek'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'Přidat položku ručně',
            onPressed: () => _showItemDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_discrepancy.abs() > 0.005)
            _DiscrepancyBanner(
              discrepancy: _discrepancy,
              onIgnore: () => setState(() => _scannedTotal = null),
            ),
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Žádné položky. Přidejte položku tlačítkem + nahoře.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _items.length,
                    itemBuilder: (context, index) => _ItemCard(
                      item: _items[index],
                      members: members,
                      onToggle: (memberId) => _toggleMember(index, memberId),
                      onAssignAll: () => _assignAll(index, members),
                      onEdit: () => _showItemDialog(index: index),
                      onRemove: () => setState(() => _items.removeAt(index)),
                    ),
                  ),
          ),

          // Footer: payer selection, total and confirm button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Kdo platil: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _paidBy,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: members
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m.id,
                                  child: Text(
                                    m.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (id) => setState(() => _paidBy = id),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Celkem',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            CurrencyFormatter.format(finalTotal),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (unassignedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Zbývá přiřadit položek: $unassignedCount',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(LucideIcons.check),
                      label: const Text('Potvrdit a rozpočítat'),
                      onPressed: _allAssigned && _paidBy != null && !_saving
                          ? _confirm
                          : null,
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

class _DiscrepancyBanner extends StatelessWidget {
  final double discrepancy;
  final VoidCallback onIgnore;

  const _DiscrepancyBanner({required this.discrepancy, required this.onIgnore});

  @override
  Widget build(BuildContext context) {
    final String message = discrepancy < 0
        ? 'Celková částka je o ${CurrencyFormatter.format(-discrepancy)} nižší '
            'než součet položek (sleva na celý nákup). Sleva se rozdělí '
            'poměrně mezi všechny.'
        : 'Celková částka je o ${CurrencyFormatter.format(discrepancy)} vyšší '
            'než součet položek (dýško, servis, zaokrouhlení). Rozdíl se '
            'rozdělí poměrně mezi všechny.';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
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
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
          TextButton(
            onPressed: onIgnore,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF92400E),
            ),
            child: const Text('Nezapočítat'),
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final ScannedReceiptItem item;
  final List<GroupMember> members;
  final ValueChanged<String> onToggle;
  final VoidCallback onAssignAll;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ItemCard({
    required this.item,
    required this.members,
    required this.onToggle,
    required this.onAssignAll,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final total = item.price * item.quantity;
    final assignedCount = item.assignedMemberIds.length;
    final everyoneAssigned =
        members.isNotEmpty && assignedCount == members.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.quantity > 1
                        ? '${item.name} (${item.quantity}×)'
                        : item.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  CurrencyFormatter.format(total),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: Colors.grey,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Upravit položku',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  color: Colors.grey,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Smazat položku',
                  onPressed: onRemove,
                ),
              ],
            ),
            Text(
              assignedCount > 0
                  ? '${CurrencyFormatter.format(total / assignedCount)} / osoba'
                  : 'Vyberte, kdo si položku dal:',
              style: TextStyle(
                fontSize: 12,
                color: assignedCount > 0 ? AppTheme.primaryColor : Colors.grey,
                fontWeight:
                    assignedCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (item.discount > 0.005)
              Text(
                'Včetně slevy −${CurrencyFormatter.format(item.discount)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...members.map(
                  (member) => FilterChip(
                    label: Text(member.displayName),
                    selected: item.assignedMemberIds.contains(member.id),
                    onSelected: (_) => onToggle(member.id),
                  ),
                ),
                if (members.length > 1)
                  ActionChip(
                    label: Text(everyoneAssigned ? 'Nikdo' : 'Všichni'),
                    onPressed: onAssignAll,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
