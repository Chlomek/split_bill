import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/split_calculator.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/domain/group_member.dart';

/// Opens the sheet for adding an expense without a receipt, or for recording
/// a direct payment between two members.
Future<void> showAddExpenseSheet(BuildContext context, String groupId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _AddExpenseSheet(groupId: groupId),
  );
}

enum _EntryMode { expense, settlement }

class _AddExpenseSheet extends ConsumerStatefulWidget {
  final String groupId;

  const _AddExpenseSheet({required this.groupId});

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  _EntryMode _mode = _EntryMode.expense;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  // Expense: who paid and who shares the cost.
  String? _paidBy;
  final Set<String> _participants = {};

  // Settlement: who handed money to whom.
  String? _from;
  String? _to;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _initDefaults(GroupDetail detail) {
    if (_initialized) return;
    _initialized = true;
    final members = detail.members;
    _paidBy = detail.me?.id ?? (members.isNotEmpty ? members.first.id : null);
    _participants.addAll(members.map((m) => m.id));
    _from = _paidBy;
    for (final member in members) {
      if (member.id != _from) {
        _to = member.id;
        break;
      }
    }
  }

  Future<void> _save() async {
    final amount = CurrencyFormatter.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Zadejte částku větší než nula.');
      return;
    }

    final actions = ref.read(groupActionsProvider);

    if (_mode == _EntryMode.expense) {
      final title = _titleController.text.trim();
      if (title.isEmpty) {
        setState(() => _error = 'Zadejte název výdaje.');
        return;
      }
      if (_paidBy == null || _participants.isEmpty) {
        setState(() => _error = 'Vyberte, mezi koho se výdaj dělí.');
        return;
      }
      setState(() => _saving = true);
      await actions.addExpense(
        groupId: widget.groupId,
        title: title,
        paidByMemberId: _paidBy!,
        shares: SplitCalculator.equalSplit(amount, _participants.toList()),
      );
    } else {
      if (_from == null || _to == null || _from == _to) {
        setState(() => _error = 'Vyberte dva různé členy.');
        return;
      }
      setState(() => _saving = true);
      await actions.addSettlement(
        groupId: widget.groupId,
        fromMemberId: _from!,
        toMemberId: _to!,
        amount: amount,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(groupDetailProvider(widget.groupId)).valueOrNull;
    if (detail == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    _initDefaults(detail);
    final members = detail.members;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<_EntryMode>(
                segments: const [
                  ButtonSegment(
                    value: _EntryMode.expense,
                    label: Text('Výdaj'),
                  ),
                  ButtonSegment(
                    value: _EntryMode.settlement,
                    label: Text('Předání peněz'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) => setState(() {
                  _mode = selection.first;
                  _error = null;
                }),
              ),
            ),
            const SizedBox(height: 16),
            if (_mode == _EntryMode.expense) ...[
              TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Název',
                  hintText: 'Např. Taxi z letiště',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Částka (Kč)',
                hintText: '300',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_mode == _EntryMode.expense) ...[
              _MemberDropdown(
                label: 'Kdo platil',
                members: members,
                value: _paidBy,
                onChanged: (id) => setState(() => _paidBy = id),
              ),
              const SizedBox(height: 16),
              const Text(
                'Rozdělit rovným dílem mezi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: members.map((member) {
                  return FilterChip(
                    label: Text(member.displayName),
                    selected: _participants.contains(member.id),
                    onSelected: (selected) => setState(() {
                      selected
                          ? _participants.add(member.id)
                          : _participants.remove(member.id);
                    }),
                  );
                }).toList(),
              ),
            ] else ...[
              _MemberDropdown(
                label: 'Kdo platil',
                members: members,
                value: _from,
                onChanged: (id) => setState(() => _from = id),
              ),
              const SizedBox(height: 12),
              _MemberDropdown(
                label: 'Komu',
                members: members,
                value: _to,
                onChanged: (id) => setState(() => _to = id),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(
                  _mode == _EntryMode.expense
                      ? 'Uložit výdaj'
                      : 'Zaznamenat platbu',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberDropdown extends StatelessWidget {
  final String label;
  final List<GroupMember> members;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _MemberDropdown({
    required this.label,
    required this.members,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: members
              .map(
                (m) => DropdownMenuItem(value: m.id, child: Text(m.displayName)),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
