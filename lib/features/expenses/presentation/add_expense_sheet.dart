import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/config/theme.dart';
import '../../../core/ui/receipt_widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/split_calculator.dart';
import '../../../core/utils/text_formatter.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/presentation/group_visuals.dart';

/// Opens the sheet for adding an expense without a receipt, or for recording
/// money handed back between two members.
Future<void> showAddExpenseSheet(BuildContext context, String groupId) {
  return showPaperSheet<void>(
    context,
    (_) => _AddExpenseSheet(groupId: groupId),
  );
}

class _AddExpenseSheet extends ConsumerStatefulWidget {
  final String groupId;

  const _AddExpenseSheet({required this.groupId});

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _amount = TextEditingController();
  final _title = TextEditingController();

  /// 0 = expense, 1 = money handed back.
  int _tab = 0;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  String? _paidBy;
  final Set<String> _participants = {};
  String? _from;
  String? _to;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    super.dispose();
  }

  void _init(GroupDetail d) {
    if (_initialized) return;
    _initialized = true;
    _paidBy = d.me?.id ?? d.members.first.id;
    _participants.addAll(d.members.map((m) => m.id));
    _from = _paidBy;
    _to = d.members.where((m) => m.id != _from).firstOrNull?.id;
  }

  Future<void> _pickMember(
    GroupDetail d,
    String title,
    String? current,
    ValueChanged<String> onPicked,
  ) async {
    final picked = await showPaperSheet<String>(
      context,
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: title, showClose: false),
          const SizedBox(height: 8),
          PaperCard(
            child: Column(
              children: [
                for (final (i, m) in d.members.indexed)
                  InkWell(
                    onTap: () => Navigator.of(context).pop(m.id),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: i == 0
                            ? null
                            : const Border(
                                top: BorderSide(color: AppColors.hairline),
                              ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName(d, m.id),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: m.id == current
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (m.id == current)
                            const Icon(
                              LucideIcons.check,
                              size: 18,
                              color: AppColors.emerald,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  Future<void> _save() async {
    final amount = CurrencyFormatter.tryParse(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Zadej částku větší než nula.');
      return;
    }
    final actions = ref.read(groupActionsProvider);

    if (_tab == 0) {
      final title = _title.text.trim();
      if (title.isEmpty) {
        setState(() => _error = 'Napiš, za co výdaj byl.');
        return;
      }
      if (_paidBy == null || _participants.isEmpty) return;
      setState(() => _saving = true);
      await actions.addExpense(
        groupId: widget.groupId,
        title: title,
        paidByMemberId: _paidBy!,
        shares: SplitCalculator.equalSplit(amount, _participants.toList()),
      );
    } else {
      if (_from == null || _to == null || _from == _to) {
        setState(() => _error = 'Vyber dva různé lidi.');
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
    final d = ref.watch(groupDetailProvider(widget.groupId)).valueOrNull;
    if (d == null || d.members.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    _init(d);

    final amount = CurrencyFormatter.tryParse(_amount.text) ?? 0;
    final n = _participants.length;
    final allOn = n == d.members.length;
    String perHead = 'Vyber, mezi koho se výdaj rozdělí';
    if (n > 0) {
      final each = amount / n;
      final exact = ((amount * 100).round() % n) == 0;
      perHead = amount > 0
          ? '${exact ? '' : '≈ '}${CurrencyFormatter.compact(each)} na osobu · '
                '${TextFormatter.people(n)}'
          : TextFormatter.people(n);
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: _tab == 0 ? 'Nový výdaj' : 'Vrácení peněz'),
          const SizedBox(height: 8),
          SegmentTabs(
            labels: const ['Výdaj', 'Vrácení peněz'],
            selected: _tab,
            onChanged: (i) => setState(() {
              _tab = i;
              _error = null;
            }),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'Částka',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _amount,
                  autofocus: true,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() => _error = null),
                  style: AppFonts.money(size: 48).copyWith(letterSpacing: -1),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: AppFonts.money(size: 48, color: AppColors.dots),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  'Kč',
                  style: AppFonts.money(
                    size: 24,
                    weight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          if (_tab == 0)
            Center(
              child: Text(
                perHead,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          const SizedBox(height: 16),
          if (_tab == 0) ...[
            const FieldLabel('Za co'),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                hintText: 'Např. Taxi z letiště',
              ),
            ),
            const SizedBox(height: 12),
            _memberField(
              d,
              label: 'Zaplatil(a)',
              value: _paidBy,
              onTap: () => _pickMember(
                d,
                'Kdo zaplatil?',
                _paidBy,
                (id) => _paidBy = id,
              ),
            ),
            const SizedBox(height: 14),
            const FieldLabel('Rozdělit mezi'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                PillToggle(
                  label: 'Všichni',
                  selected: allOn,
                  dashedWhenOff: true,
                  onTap: () => setState(() {
                    if (allOn) {
                      _participants.clear();
                    } else {
                      _participants.addAll(d.members.map((m) => m.id));
                    }
                  }),
                ),
                for (final m in d.members)
                  PillToggle(
                    label: displayName(d, m.id),
                    selected: _participants.contains(m.id),
                    onTap: () => setState(() {
                      _participants.contains(m.id)
                          ? _participants.remove(m.id)
                          : _participants.add(m.id);
                    }),
                  ),
              ],
            ),
            if (d.members.any(
              (m) => m.isVirtual && _participants.contains(m.id),
            ))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${d.members.where((m) => m.isVirtual && _participants.contains(m.id)).map((m) => m.displayName).join(', ')} '
                  'nemá aplikaci, díl se mu i tak započítá.',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
          ] else ...[
            _memberField(
              d,
              label: 'Kdo peníze vrátil',
              value: _from,
              onTap: () => _pickMember(
                d,
                'Kdo peníze vrátil?',
                _from,
                (id) => _from = id,
              ),
            ),
            const SizedBox(height: 10),
            _memberField(
              d,
              label: 'Komu',
              value: _to,
              onTap: () => _pickMember(d, 'Komu?', _to, (id) => _to = id),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hotovost nebo převod mimo QR. Zůstatky se hned přepočítají.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(fontSize: 13, color: AppColors.red),
            ),
          ],
          const SizedBox(height: 20),
          AppButton(
            label: _tab == 0
                ? (n == 0 ? 'Vyber, mezi koho se dělí' : 'Uložit výdaj')
                : 'Zaznamenat vrácení',
            onPressed: _saving || (_tab == 0 && n == 0) ? null : _save,
          ),
        ],
      ),
    );
  }

  Widget _memberField(
    GroupDetail d, {
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.slip,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        value == null ? '—' : displayName(d, value),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronDown, size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
