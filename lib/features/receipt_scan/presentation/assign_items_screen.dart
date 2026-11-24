import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/theme.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/ui/receipt_widgets.dart';
import '../../../core/utils/assignment_calculator.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/split_calculator.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/domain/expense_item.dart';
import '../../groups/application/group_providers.dart';
import '../domain/receipt_scan_result.dart';

/// What the assignment screen works on: a fresh scan, or an existing
/// expense whose split is being edited.
class AssignItemsArgs {
  final ReceiptScanResult? scan;
  final String? expenseId;

  const AssignItemsArgs({this.scan, this.expenseId});
}

/// An editable receipt line on this screen.
class _Line {
  final String id;
  String name;
  int quantity;
  double lineTotal;
  double discount;

  _Line({
    required this.id,
    required this.name,
    required this.quantity,
    required this.lineTotal,
    this.discount = 0,
  });

  _Line copy() => _Line(
    id: id,
    name: name,
    quantity: quantity,
    lineTotal: lineTotal,
    discount: discount,
  );

  ReceiptLine get receiptLine =>
      ReceiptLine(id: id, name: name, quantity: quantity, lineTotal: lineTotal);
}

/// Undo point: lines and their assignments.
class _Snapshot {
  final List<_Line> lines;
  final Map<String, LineAssignment> assign;

  _Snapshot(List<_Line> lines, Map<String, LineAssignment> assign)
    : lines = lines.map((l) => l.copy()).toList(),
      assign = Map.of(assign);
}

class _Notice {
  final String text;
  final _Snapshot? undo;

  const _Notice(this.text, [this.undo]);
}

const String _everyone = '__all';

/// Screen 3 of the design: pick a person in the bar at the bottom, then tap
/// the lines they had. One tap is one piece; single-piece lines are shared
/// evenly between everyone who tapped them.
class AssignItemsScreen extends ConsumerStatefulWidget {
  final String groupId;
  final AssignItemsArgs args;

  const AssignItemsScreen({
    super.key,
    required this.groupId,
    this.args = const AssignItemsArgs(),
  });

  @override
  ConsumerState<AssignItemsScreen> createState() => _AssignItemsScreenState();
}

class _AssignItemsScreenState extends ConsumerState<AssignItemsScreen> {
  final _uuid = const Uuid();

  bool _initialized = false;
  late List<_Line> _lines;
  Map<String, LineAssignment> _assign = {};
  double? _receiptTotal;
  String _title = 'Účtenka';
  String? _source;
  Expense? _editing;

  String _selected = '';
  String? _payer;
  _Notice? _notice;
  ({String lineId, String memberId})? _over;
  bool _leaving = false;
  bool _taught = false;
  bool _saving = false;

  void _init(GroupDetail detail) {
    if (_initialized) return;
    _initialized = true;
    final meId = detail.me?.id ?? detail.members.first.id;
    _selected = meId;
    _payer = meId;

    final expenseId = widget.args.expenseId;
    final scan = widget.args.scan;
    if (expenseId != null) {
      final expense = detail.expenses
          .where((e) => e.id == expenseId)
          .firstOrNull;
      _editing = expense;
      if (expense != null) {
        _title = expense.title;
        _payer = expense.paidByMemberId;
        _receiptTotal = expense.totalAmount;
        _source = expense.source;
      }
      final items = detail.itemsOf(expenseId);
      _lines = [
        for (final item in items)
          _Line(
            id: item.id,
            name: item.name,
            quantity: item.quantity,
            lineTotal: item.lineTotal,
            discount: item.discount,
          ),
      ];
      _assign = {
        for (final item in items)
          item.id: LineAssignment(
            everyone: item.everyone,
            restToEveryone: item.restToEveryone,
            pieces: Map.of(item.pieces),
          ),
      };
    } else {
      final merchant = scan?.merchantName?.trim() ?? '';
      if (merchant.isNotEmpty) _title = merchant;
      _receiptTotal = scan?.totalAmount;
      _source = switch (scan?.scannerType) {
        ReceiptScannerType.aiVision => 'ai',
        ReceiptScannerType.mlKit => 'device',
        _ => null,
      };
      _lines = [
        for (final item in scan?.items ?? const [])
          _Line(
            id: item.id,
            name: item.name,
            quantity: item.quantity < 1 ? 1 : item.quantity,
            lineTotal: item.price * (item.quantity < 1 ? 1 : item.quantity),
            discount: item.discount,
          ),
      ];
    }
  }

  // ---------------------------------------------------------------------
  // Derived values
  // ---------------------------------------------------------------------

  List<String> _memberIds(GroupDetail d) {
    final ids = d.members.map((m) => m.id).toList();
    final me = d.me?.id;
    if (me != null && ids.remove(me)) ids.insert(0, me);
    return ids;
  }

  String _name(GroupDetail d, String id) =>
      id == d.me?.id ? 'Ty' : d.memberName(id);

  LineAssignment _a(String lineId) => _assign[lineId] ?? LineAssignment.none;

  bool get _hasWork => _assign.values.any((a) => !a.isEmpty);

  String _kc(double crowns) => CurrencyFormatter.compact(crowns);
  String _kcMinor(int minor) => _kc(SplitCalculator.fromMinor(minor));

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  _Snapshot _snap() => _Snapshot(_lines, _assign);

  void _setLine(String lineId, LineAssignment next, [_Notice? notice]) {
    setState(() {
      _assign = {..._assign, lineId: next};
      _over = null;
      _leaving = false;
      _notice = notice;
    });
  }

  void _tap(GroupDetail d, _Line line) {
    final a = _a(line.id);
    final members = _memberIds(d);
    final undo = _snap();

    if (_selected == _everyone) {
      final next = !a.everyone;
      final takers = a.takers(members);
      _setLine(
        line.id,
        a.copyWith(everyone: next),
        _Notice(
          next
              ? '${line.name} teď platí všichni rovným dílem.'
              : '${line.name} už neplatí všichni.'
                    '${takers.isEmpty ? '' : ' Zpátky u: ${takers.map((m) => _name(d, m)).join(', ')}.'}',
          undo,
        ),
      );
      return;
    }

    if (a.everyone) {
      setState(() {
        _over = null;
        _notice = _Notice(
          '${line.name} platí všichni. Zrušíš to v režimu Všichni.',
        );
      });
      return;
    }

    final sel = _selected;
    if (line.quantity <= 1) {
      final on = a.piecesOf(sel) > 0;
      final others = a.takers(members).where((m) => m != sel).toList();
      final after = on ? others : [...others, sel];
      final notice = others.isEmpty
          ? null
          : _Notice(
              '${line.name}: ${after.map((m) => _name(d, m).toLowerCase() == 'ty' ? 'ty' : _name(d, m)).join(' a ')}'
              '${after.length > 1 ? ', po ${_kc(line.lineTotal / after.length)}' : ''}.',
              undo,
            );
      _setLine(line.id, a.withPieces(sel, on ? 0 : 1), notice);
      return;
    }

    if (a.taps < line.quantity) {
      final nextCount = a.piecesOf(sel) + 1;
      final teach = !_taught && nextCount == 1;
      if (teach) _taught = true;
      _setLine(
        line.id,
        a.withPieces(sel, nextCount),
        teach
            ? _Notice(
                '1 z ${line.quantity} ks: ${_name(d, sel)}. Klepni znovu za '
                'další kus, podržením řádku opravíš cenu.',
              )
            : null,
      );
      return;
    }

    setState(() {
      _over = (lineId: line.id, memberId: sel);
      _notice = null;
    });
  }

  void _confirmOver(GroupDetail d) {
    final over = _over;
    if (over == null) return;
    final line = _lines.firstWhere((l) => l.id == over.lineId);
    final a = _a(line.id);
    _setLine(
      line.id,
      a.withPieces(over.memberId, a.piecesOf(over.memberId) + 1),
      _Notice(
        '${line.name} se teď dělí poměrně podle ${a.taps + 1} klepnutí.',
        _snap(),
      ),
    );
  }

  void _minus(_Line line) {
    final a = _a(line.id);
    if (_selected == _everyone) {
      _setLine(
        line.id,
        a.copyWith(everyone: false),
        _Notice('${line.name} už neplatí všichni.', _snap()),
      );
      return;
    }
    _setLine(line.id, a.withPieces(_selected, a.piecesOf(_selected) - 1));
  }

  void _reset() {
    final undo = _snap();
    setState(() {
      _assign = {};
      _over = null;
      _notice = _Notice('Rozdělení vymazáno. Ceny a položky zůstaly.', undo);
    });
  }

  void _restToAll(AssignmentResult result) {
    final undo = _snap();
    setState(() {
      _assign = {
        ..._assign,
        for (final id in result.openLineIds)
          id: _a(id).copyWith(restToEveryone: true),
      };
      _over = null;
      _notice = _Notice(
        'Zbytek ${_kcMinor(result.openMinor)} teď platí všichni rovným dílem.',
        undo,
      );
    });
  }

  void _undo() {
    final snap = _notice?.undo;
    if (snap == null) return;
    setState(() {
      _lines = snap.lines;
      _assign = snap.assign;
      _notice = null;
      _over = null;
    });
  }

  void _addLine({String name = 'Nová položka', double total = 0}) {
    final line = _Line(
      id: _uuid.v4(),
      name: name,
      quantity: 1,
      lineTotal: total,
    );
    setState(() => _lines.add(line));
    _editLine(line);
  }

  Future<void> _editLine(_Line line) async {
    final undo = _snap();
    final deleted = await showPaperSheet<bool>(
      context,
      (_) => _EditLineSheet(line: line, onChanged: () => setState(() {})),
    );
    if (deleted == true) {
      setState(() {
        _lines.removeWhere((l) => l.id == line.id);
        _assign = Map.of(_assign)..remove(line.id);
        _notice = _Notice('Smazáno: ${line.name}.', undo);
      });
    }
  }

  Future<void> _pickPayer(GroupDetail d) async {
    final picked = await showPaperSheet<String>(
      context,
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Kdo zaplatil účet?', showClose: false),
          const SizedBox(height: 8),
          PaperCard(
            child: Column(
              children: [
                for (final (i, id) in _memberIds(d).indexed)
                  InkWell(
                    onTap: () => Navigator.of(context).pop(id),
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
                              _name(d, id),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: id == _payer
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.slip,
                              border: Border.all(
                                color: id == _payer
                                    ? AppColors.emerald
                                    : AppColors.outline,
                                width: id == _payer ? 7 : 2,
                              ),
                            ),
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
    if (picked != null) setState(() => _payer = picked);
  }

  Future<void> _openSummary(GroupDetail d, AssignmentResult result) async {
    setState(() => _notice = null);
    final action = await showPaperSheet<String>(
      context,
      (_) => _SummarySheet(
        result: result,
        members: _memberIds(d),
        payer: _payer!,
        meId: d.me?.id,
        nameOf: (id) => _name(d, id),
      ),
    );
    if (!mounted) return;
    if (action == 'save') {
      await _save(d, result);
    } else if (action == 'missing') {
      _addLine(
        name: 'Chybějící položka',
        total: SplitCalculator.fromMinor(result.differenceMinor),
      );
    }
  }

  Future<void> _save(GroupDetail d, AssignmentResult result) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final shares = result.sharesInCrowns;
    final lines = _lines.map((l) => l.copy()).toList();
    final assign = Map.of(_assign);

    await ref
        .read(groupActionsProvider)
        .addExpense(
          groupId: widget.groupId,
          title: _title,
          paidByMemberId: _payer!,
          shares: shares,
          expenseId: _editing?.id,
          createdAt: _editing?.createdAt,
          source: _source,
          items: (expenseId) => [
            for (final l in lines)
              ExpenseItem(
                id: _uuid.v4(),
                expenseId: expenseId,
                name: l.name,
                quantity: l.quantity,
                lineTotal: l.lineTotal,
                discount: l.discount,
                everyone: assign[l.id]?.everyone ?? false,
                restToEveryone: assign[l.id]?.restToEveryone ?? false,
                pieces: assign[l.id]?.pieces ?? const {},
              ),
          ],
        );

    final meId = d.me?.id;
    final othersOwe = shares.entries
        .where((e) => e.key != _payer)
        .fold<double>(0, (s, e) => s + e.value);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _payer == meId && othersOwe > 0
              ? 'Uloženo. Ostatní ti pošlou ${_kc(othersOwe)}.'
              : 'Výdaj uložen a dluhy přepočítány.',
        ),
      ),
    );
    router.go(RouteNames.groupDetail(widget.groupId));
  }

  void _askLeave() => setState(() {
    _leaving = true;
    _over = null;
    _notice = null;
  });

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(groupDetailProvider(widget.groupId));
    final d = detailAsync.valueOrNull;
    if (d == null || d.members.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Přiřazení položek')),
        body: Center(
          child: detailAsync.isLoading
              ? const CircularProgressIndicator()
              : const Text('Skupina nebyla nalezena.'),
        ),
      );
    }
    _init(d);

    final members = _memberIds(d);
    final result = AssignmentCalculator.calculate(
      lines: _lines.map((l) => l.receiptLine).toList(),
      assignments: _assign,
      members: members,
      receiptTotal: _receiptTotal,
    );

    return PopScope(
      canPop: !_hasWork,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askLeave();
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              _progress(result),
              Expanded(child: _list(d, members, result)),
              _bottomPanel(d, members, result),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Zpět',
            onPressed: _hasWork ? _askLeave : () => context.pop(),
            icon: const Icon(LucideIcons.chevronLeft, size: 24),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _renameReceipt,
              child: Text(
                _title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _hasWork ? _reset : null,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.ink,
              disabledForegroundColor: AppColors.disabledText,
              minimumSize: const Size(44, 44),
            ),
            icon: const Icon(LucideIcons.rotateCcw, size: 18),
            label: const Text(
              'Začít znovu',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _renameReceipt() async {
    final controller = TextEditingController(text: _title);
    final value = await showPaperSheet<String>(
      context,
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(title: 'Název výdaje'),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Uložit',
            onPressed: () => Navigator.of(context).pop(controller.text),
          ),
        ],
      ),
    );
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) setState(() => _title = trimmed);
  }

  Widget _progress(AssignmentResult result) {
    final open = result.openLineIds.isNotEmpty || _lines.isEmpty;
    final done = _lines.length - result.openLineIds.length;
    final pct = result.grandMinor > 0
        ? (result.grandMinor - result.openMinor) / result.grandMinor
        : 0.0;
    final diff = result.differenceMinor;
    final color = open ? AppColors.ink : AppColors.emeraldDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  open ? '$done z ${_lines.length} rozděleno' : 'Vše rozděleno',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: open
                          ? 'zbývá ${_kcMinor(result.openMinor)}'
                          : _kcMinor(result.grandMinor),
                    ),
                    if (diff != 0)
                      TextSpan(
                        text: diff > 0
                            ? ' · rozdíl +${_kcMinor(diff)}'
                            : ' · sleva −${_kcMinor(-diff)}',
                        style: const TextStyle(color: AppColors.amber),
                      ),
                  ],
                ),
                style: AppFonts.money(size: 12, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: AppColors.track,
              color: AppColors.emerald,
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(GroupDetail d, List<String> members, AssignmentResult result) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        for (final line in _lines) ...[
          _row(d, members, line, result.lines[line.id]!),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _addLine,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text(
              'Přidat položku',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(
    GroupDetail d,
    List<String> members,
    _Line line,
    LineSplit split,
  ) {
    final a = _a(line.id);
    final takers = a.takers(members);
    final hasPrice = line.lineTotal > 0;
    final qty = line.quantity < 1 ? 1 : line.quantity;
    final allSel = _selected == _everyone;

    var summaryColor = AppColors.muted;
    var summaryBold = false;
    String summary;
    if (!hasPrice) {
      summary = 'Doplň cenu · podrž řádek';
      summaryColor = AppColors.amber;
      summaryBold = true;
    } else if (a.everyone || (takers.isEmpty && a.restToEveryone)) {
      summary =
          'Všichni rovným dílem · ${_kc(line.lineTotal / members.length)} / os';
    } else if (takers.isEmpty) {
      summary = 'Nikdo · klepni, kdo to měl';
      summaryColor = AppColors.amber;
      summaryBold = true;
    } else if (qty == 1) {
      summary =
          takers.map((m) => _name(d, m)).join(', ') +
          (takers.length > 1
              ? ' · ${_kc(line.lineTotal / takers.length)} / os'
              : '');
    } else {
      summary = takers
          .map((m) => '${_name(d, m)} ${a.piecesOf(m)}×')
          .join(' · ');
    }

    final open = split.open > 0.001 || !hasPrice;
    final full = split.open >= line.lineTotal * 100 - 1;
    final state = !hasPrice || (open && full)
        ? _RowState.open
        : (open ? _RowState.partial : _RowState.done);

    String tail = '';
    var tailColor = AppColors.amber;
    if (state == _RowState.partial) {
      tail = 'zbývá ${split.openPieces} ks';
    } else if (split.proportional) {
      tail = 'poměrně · ${a.taps}/$qty';
    } else if (a.restToEveryone &&
        !a.everyone &&
        takers.isNotEmpty &&
        a.taps < qty) {
      tail = 'zbytek všem';
      tailColor = AppColors.muted;
    }

    final mineCount = allSel
        ? (a.everyone ? 1 : 0)
        : (a.everyone ? 0 : a.piecesOf(_selected));
    final mine = mineCount > 0;
    final mineLabel = allSel
        ? '÷${members.length}'
        : (qty > 1
              ? '$mineCount×'
              : (takers.length > 1 ? '1/${takers.length}' : '1×'));

    // When the row shows the selected person's count, keep room for the name.
    final qtyParts = mine
        ? const <String>[]
        : [
            if (qty > 1) '$qty × ${_kc(line.lineTotal / qty)}',
            if (line.discount > 0.005) 'sleva −${_kc(line.discount)}',
          ];

    final pct = hasPrice
        ? (1 - split.open / math.max(1, line.lineTotal * 100)).clamp(0.0, 1.0)
        : 0.0;

    return Semantics(
      button: true,
      label:
          '${line.name}, ${_kc(line.lineTotal)}. $summary. '
          '${allSel ? 'Klepnutím přepneš placení všemi.' : 'Klepnutím přidáš kus.'} '
          'Podržením upravíš.',
      child: Material(
        color: state == _RowState.done && !mine
            ? AppColors.doneFill
            : AppColors.slip,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: mine
                ? AppColors.ink
                : (state == _RowState.done
                      ? AppColors.line
                      : AppColors.amberLine),
            width: mine || state != _RowState.done ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _tap(d, line),
                  onLongPress: () => _editLine(line),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
                    child: Row(
                      children: [
                        _StateDot(state: state, progress: pct),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Flexible(
                                    child: Text(
                                      line.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (qtyParts.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      qtyParts.join(' · '),
                                      style: AppFonts.money(
                                        size: 12,
                                        weight: FontWeight.w400,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                summary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: summaryColor,
                                  fontWeight: summaryBold
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_kc(line.lineTotal), style: AppFonts.money()),
                            if (tail.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                tail,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: tailColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (mine)
                Padding(
                  padding: const EdgeInsets.only(right: 10, left: 2),
                  child: Row(
                    children: [
                      Container(
                        constraints: const BoxConstraints(minWidth: 32),
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          mineLabel,
                          style: AppFonts.money(
                            size: 13,
                            color: AppColors.slip,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          tooltip: allSel
                              ? 'Zrušit placení všemi: ${line.name}'
                              : 'Ubrat kus: ${line.name}',
                          onPressed: () => _minus(line),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.slip,
                            side: const BorderSide(color: AppColors.outline),
                          ),
                          icon: const Icon(LucideIcons.minus, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomPanel(
    GroupDetail d,
    List<String> members,
    AssignmentResult result,
  ) {
    final allSel = _selected == _everyone;
    final open = result.openLineIds.isNotEmpty || _lines.isEmpty;
    final overLine = _over == null
        ? null
        : _lines.where((l) => l.id == _over!.lineId).firstOrNull;
    final compact = members.length + 1 > 6;
    final columns = compact ? 4 : 3;

    String hint;
    if (allSel) {
      hint = 'Klepni na položky, které platí všichni rovným dílem.';
    } else if (_selected == d.me?.id) {
      hint = 'Klepni jednou za každý kus, co jsi měl(a).';
    } else {
      hint = 'Klepni jednou za každý kus, co měl(a) ${_name(d, _selected)}.';
    }

    String unassignedLabel = '';
    if (_lines.isEmpty) {
      unassignedLabel = 'Účtenka nemá žádné položky';
    } else if (result.openLineIds.length == 1) {
      final line = _lines.firstWhere((l) => l.id == result.openLineIds.first);
      unassignedLabel = line.lineTotal > 0
          ? 'Zbývá ${line.name} · ${_kcMinor(result.openMinor)}'
          : 'Doplň cenu: ${line.name}';
    } else if (result.openLineIds.length > 1) {
      final n = result.openLineIds.length;
      unassignedLabel =
          '${n < 5 ? 'Zbývají $n položky' : 'Zbývá $n položek'}'
          ' · ${_kcMinor(result.openMinor)}';
    }

    final people = [_everyone, ...members];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.slip,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_leaving) ...[
                AmberNotice(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Odejít a zahodit rozdělení této účtenky?'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Zahodit',
                              kind: AppButtonKind.danger,
                              height: 44,
                              onPressed: () => context.pop(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppButton(
                              label: 'Zůstat',
                              kind: AppButtonKind.dark,
                              height: 44,
                              onPressed: () => setState(() => _leaving = false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ] else if (overLine != null) ...[
                AmberNotice(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Všech ${overLine.quantity} ks položky '
                        '${overLine.name} už je rozdaných. Přidat další kus '
                        '(${_name(d, _over!.memberId)})? Pak se rozdělí '
                        'poměrně a ostatním klesne cena.',
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Ano, dělit',
                              kind: AppButtonKind.dark,
                              height: 44,
                              onPressed: () => _confirmOver(d),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AppButton(
                              label: 'Nechat',
                              kind: AppButtonKind.outline,
                              height: 44,
                              onPressed: () => setState(() => _over = null),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ] else if (_notice != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _notice!.text,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: AppColors.slip,
                              ),
                            ),
                          ),
                        ),
                        if (_notice!.undo != null)
                          TextButton(
                            onPressed: _undo,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.mintBright,
                            ),
                            child: const Text(
                              'Zpět',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (allSel || !_hasWork) ...[
                Text(
                  hint,
                  style: const TextStyle(fontSize: 13, color: AppColors.body),
                ),
                const SizedBox(height: 8),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final width =
                      (constraints.maxWidth - (columns - 1) * 6) / columns;
                  return Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final id in people)
                        SizedBox(
                          width: width,
                          child: _personButton(d, id, result, compact),
                        ),
                    ],
                  );
                },
              ),
              if (open) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        unassignedLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.amber,
                        ),
                      ),
                    ),
                    if (result.openMinor > 0)
                      AppButton(
                        label: 'Zbytek všem',
                        kind: AppButtonKind.ghost,
                        height: 44,
                        onPressed: () => _restToAll(result),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Material(
                    color: AppColors.slip,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.outline),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _pickPayer(d),
                      child: SizedBox(
                        height: 54,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Zaplatil(a)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  Text(
                                    _name(d, _payer!),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              const Icon(LucideIcons.chevronDown, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      label: 'Zkontrolovat',
                      onPressed: open || _saving
                          ? null
                          : () => _openSummary(d, result),
                      trailing: Text(
                        _kcMinor(result.grandMinor),
                        style: AppFonts.money(
                          size: 16,
                          color: open ? AppColors.mutedStrong : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _personButton(
    GroupDetail d,
    String id,
    AssignmentResult result,
    bool compact,
  ) {
    final selected = _selected == id;
    final isAll = id == _everyone;
    final name = isAll ? 'Všichni' : _name(d, id);
    final label = isAll || !compact
        ? name
        : name.characters.take(2).toString().toUpperCase();
    final sub = isAll ? 'rovným dílem' : _kcMinor(result.shares[id] ?? 0);

    return Semantics(
      selected: selected,
      button: true,
      label: isAll ? 'Všichni rovným dílem' : '$name, $sub',
      child: Material(
        color: selected ? AppColors.ink : AppColors.slip,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? AppColors.ink : AppColors.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() {
            _selected = id;
            _over = null;
            _leaving = false;
            if (_notice?.undo == null) _notice = null;
          }),
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.slip : AppColors.ink,
                    ),
                  ),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (isAll
                                ? const TextStyle(fontSize: 12)
                                : AppFonts.money(
                                    size: 12,
                                    weight: FontWeight.w400,
                                  ))
                            .copyWith(
                              color: selected
                                  ? const Color(0xFFCFCABE)
                                  : AppColors.muted,
                            ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _RowState { open, partial, done }

/// Status circle of a line: dashed amber (open), amber arc (partly split),
/// green check (done).
class _StateDot extends StatelessWidget {
  final _RowState state;
  final double progress;

  const _StateDot({required this.state, required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: CustomPaint(
        painter: _DotPainter(state, progress),
        child: state == _RowState.done
            ? const Icon(LucideIcons.check, size: 14, color: Colors.white)
            : null,
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  final _RowState state;
  final double progress;

  _DotPainter(this.state, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final r = size.width / 2 - 0.75;
    final rect = Rect.fromCircle(center: centre, radius: r);
    switch (state) {
      case _RowState.done:
        canvas.drawCircle(centre, r + 0.75, Paint()..color = AppColors.emerald);
      case _RowState.partial:
        canvas.drawCircle(centre, r, Paint()..color = const Color(0xFFF3E6C8));
        canvas.drawArc(
          rect,
          -math.pi / 2,
          2 * math.pi * progress,
          true,
          Paint()..color = AppColors.amberStrong,
        );
        canvas.drawCircle(
          centre,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.amberStrong,
        );
      case _RowState.open:
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.amberStrong;
        const dashes = 12;
        for (var i = 0; i < dashes; i++) {
          final start = i * 2 * math.pi / dashes;
          canvas.drawArc(rect, start, math.pi / dashes, false, paint);
        }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.state != state || old.progress != progress;
}

/// Edit a line's name, piece count and line total; or delete it. Returns
/// true when the line should be deleted.
class _EditLineSheet extends StatefulWidget {
  final _Line line;
  final VoidCallback onChanged;

  const _EditLineSheet({required this.line, required this.onChanged});

  @override
  State<_EditLineSheet> createState() => _EditLineSheetState();
}

class _EditLineSheetState extends State<_EditLineSheet> {
  late final _name = TextEditingController(text: widget.line.name);
  late final _qty = TextEditingController(text: '${widget.line.quantity}');
  late final _price = TextEditingController(
    text: widget.line.lineTotal > 0
        ? CurrencyFormatter.compact(
            widget.line.lineTotal,
          ).replaceAll(' Kč', '').replaceAll(' ', '').replaceAll(' ', '')
        : '',
  );

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  void _apply() {
    final line = widget.line;
    final name = _name.text.trim();
    if (name.isNotEmpty) line.name = name;
    final qty = int.tryParse(_qty.text.trim());
    if (qty != null && qty >= 1) line.quantity = qty;
    final price = CurrencyFormatter.tryParse(_price.text);
    if (price != null && price >= 0) {
      if ((price - line.lineTotal).abs() > 0.004) line.discount = 0;
      line.lineTotal = price;
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetHeader(title: 'Upravit položku'),
        const SizedBox(height: 8),
        const FieldLabel('Název'),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _apply(),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Kusů'),
                  TextField(
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    style: AppFonts.money(size: 16, weight: FontWeight.w400),
                    onChanged: (_) => _apply(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel('Cena celkem (Kč)'),
                  TextField(
                    controller: _price,
                    autofocus: widget.line.lineTotal <= 0,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: AppFonts.money(size: 16, weight: FontWeight.w400),
                    onChanged: (_) => _apply(),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.line.discount > 0.005) ...[
          const SizedBox(height: 8),
          Text(
            'Včetně slevy −${CurrencyFormatter.compact(widget.line.discount)}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            AppButton(
              label: 'Smazat řádek',
              kind: AppButtonKind.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppButton(
                label: 'Hotovo',
                kind: AppButtonKind.dark,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Kdo ti kolik pošle": final amounts before saving. Returns 'save',
/// 'missing' (add a line for the difference) or null.
class _SummarySheet extends StatelessWidget {
  final AssignmentResult result;
  final List<String> members;
  final String payer;
  final String? meId;
  final String Function(String id) nameOf;

  const _SummarySheet({
    required this.result,
    required this.members,
    required this.payer,
    required this.meId,
    required this.nameOf,
  });

  String _kc(int minor) =>
      CurrencyFormatter.compact(SplitCalculator.fromMinor(minor));

  @override
  Widget build(BuildContext context) {
    final diff = result.differenceMinor;
    final payerIsMe = payer == meId;
    final rows = members.where((m) => (result.shares[m] ?? 0) > 0).toList();

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: payerIsMe
                ? 'Kdo ti kolik pošle'
                : 'Kdo kolik posílá · platil(a) ${nameOf(payer)}',
          ),
          const SizedBox(height: 8),
          if (diff > 0) ...[
            AmberNotice(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Na účtence je o '),
                        TextSpan(
                          text: _kc(diff),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(
                          text:
                              ' víc než v položkách. Bereme to jako spropitné '
                              'a dělí se podle útraty. Chybí-li položka, '
                              'doplň ji.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop('missing'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.amberText,
                      backgroundColor: AppColors.slip,
                      side: const BorderSide(color: AppColors.amberStrong),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Chybí položka za ${_kc(diff)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ] else if (diff < 0) ...[
            AmberNotice(
              child: Text(
                'Sleva na celý nákup ${_kc(-diff)} se dělí podle útraty, '
                'každému podle toho, co měl.',
              ),
            ),
            const SizedBox(height: 14),
          ],
          Slip(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final m in rows) ...[
                  LeaderRow(
                    label: Text(
                      m == payer
                          ? (m == meId
                                ? 'Tvůj díl'
                                : '${nameOf(m)} · platil(a)')
                          : (payerIsMe
                                ? '${nameOf(m)} ti pošle'
                                : (m == meId
                                      ? 'Ty pošleš'
                                      : '${nameOf(m)} pošle')),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    amount: _kc(result.shares[m]!),
                    amountStyle: AppFonts.money(
                      color: m == payer ? AppColors.muted : AppColors.emerald,
                    ),
                  ),
                  if (m == payer || result.differenceShares[m] != null)
                    Text(
                      [
                        if (m == payer) 'už zaplaceno',
                        if (result.differenceShares[m] != null)
                          diff > 0
                              ? 'vč. ${_kc(result.differenceShares[m]!)} spropitného'
                              : 'po slevě ${_kc(-result.differenceShares[m]!)}',
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  const SizedBox(height: 9),
                ],
                const DashedRule(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        diff > 0
                            ? 'Celkem vč. spropitného ${_kc(diff)}'
                            : 'Celkem',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    Text(
                      _kc(result.grandMinor),
                      style: AppFonts.money(size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              AppButton(
                label: 'Upravit',
                kind: AppButtonKind.ghost,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Uložit výdaj',
                  onPressed: () => Navigator.of(context).pop('save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
