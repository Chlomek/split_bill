import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/config/theme.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/services/document_capture_service.dart';
import '../../../core/ui/receipt_widgets.dart';
import '../../expenses/presentation/add_expense_sheet.dart';
import '../data/receipt_scanner_provider.dart';
import '../domain/receipt_scan_result.dart';
import '../domain/scanned_receipt_item.dart';
import 'assign_items_screen.dart';

enum _ScanState { capturing, reading, failed, onDevice }

/// Opens the document scanner straight away, then shows the reading state
/// and its outcomes: read by AI (goes straight to assignment), read on the
/// device (check before assigning), or not read at all.
class ScanReceiptScreen extends ConsumerStatefulWidget {
  final String groupId;

  const ScanReceiptScreen({super.key, required this.groupId});

  @override
  ConsumerState<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends ConsumerState<ScanReceiptScreen>
    with SingleTickerProviderStateMixin {
  late final DocumentCaptureService _capture = ref.read(
    documentCaptureProvider,
  );
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  _ScanState _state = _ScanState.capturing;
  ReceiptScanResult? _result;

  /// Why the AI was not used for the last reading, if it wasn't.
  AiFallbackReason? _aiProblem;

  /// The last photo, kept until the screen closes so the AI can be retried
  /// without taking it again.
  File? _photo;

  /// Bumped on every new attempt so a cancelled one is ignored.
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fromCamera());
  }

  @override
  void dispose() {
    _sweep.dispose();
    _discardPhoto();
    super.dispose();
  }

  /// The photo is only needed for reading; don't keep it around.
  void _discardPhoto() {
    final photo = _photo;
    _photo = null;
    try {
      if (photo != null && photo.existsSync()) photo.deleteSync();
    } catch (_) {}
  }

  Future<void> _retryAi() async {
    final photo = _photo;
    if (photo == null) return _fromCamera();
    await _read(photo, ++_attempt);
  }

  Future<void> _fromCamera() async {
    final attempt = ++_attempt;
    setState(() => _state = _ScanState.capturing);
    List<File> files;
    try {
      files = await _capture.scanReceiptWithCamera();
    } catch (e, stackTrace) {
      debugPrint('Receipt capture failed: $e\n$stackTrace');
      if (mounted && attempt == _attempt) {
        setState(() => _state = _ScanState.failed);
      }
      return;
    }
    if (!mounted || attempt != _attempt) return;
    if (files.isEmpty) {
      // Scanner closed without a photo: go back where the user came from.
      context.pop();
      return;
    }
    await _read(files.first, attempt);
  }

  Future<void> _fromGallery() async {
    final attempt = ++_attempt;
    File? file;
    try {
      file = await _capture.pickReceiptFromGallery();
    } catch (e, stackTrace) {
      debugPrint('Gallery pick failed: $e\n$stackTrace');
    }
    if (file != null && mounted && attempt == _attempt) {
      await _read(file, attempt);
    }
  }

  Future<void> _read(File file, int attempt) async {
    if (_photo?.path != file.path) _discardPhoto();
    _photo = file;
    setState(() => _state = _ScanState.reading);
    _startSweep();
    ReceiptScanResult? result;
    try {
      result = await ref.read(receiptScannerProvider).scanReceipt(file);
      debugPrint(
        'Receipt scan (${result.scannerType.name}): ${result.items.length} '
        'items, total ${result.totalAmount}. Raw text: ${result.rawText}',
      );
    } catch (e, stackTrace) {
      debugPrint('Receipt recognition failed: $e\n$stackTrace');
    }
    _sweep.stop();
    if (!mounted || attempt != _attempt) return;

    _aiProblem = result?.fallbackReason;
    if (result == null || result.items.isEmpty) {
      setState(() => _state = _ScanState.failed);
    } else if (result.scannerType == ReceiptScannerType.mlKit) {
      setState(() {
        _result = result;
        _state = _ScanState.onDevice;
      });
    } else {
      _discardPhoto();
      _openAssign(result);
    }
  }

  void _startSweep() {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    _sweep.repeat(reverse: true);
  }

  void _openAssign(ReceiptScanResult result) {
    context.pushReplacement(
      RouteNames.assignItems(widget.groupId),
      extra: AssignItemsArgs(scan: result),
    );
  }

  void _openDemo() {
    _openAssign(
      ReceiptScanResult(
        merchantName: 'Restaurace U Medvídka',
        totalAmount: 430.0,
        currency: 'CZK',
        scannerType: ReceiptScannerType.aiVision,
        isAiProcessed: true,
        items: [
          ScannedReceiptItem(name: 'Pizza Margherita', price: 190.0),
          ScannedReceiptItem(
            name: 'Plzeňské pivo 12°',
            price: 30.0,
            quantity: 4,
          ),
          ScannedReceiptItem(name: 'Domácí limonáda', price: 65.0),
          ScannedReceiptItem(name: 'Espresso', price: 55.0),
        ],
      ),
    );
  }

  Future<void> _manual() async {
    await showAddExpenseSheet(context, widget.groupId);
    if (mounted) context.pop();
  }

  /// The AI failed for a reason that trying again may fix.
  bool get _aiRetryable =>
      _photo != null &&
      (_aiProblem == AiFallbackReason.busy ||
          _aiProblem == AiFallbackReason.offline ||
          _aiProblem == AiFallbackReason.error);

  @override
  Widget build(BuildContext context) {
    final problem = _aiProblem;
    final copy = switch (_state) {
      _ScanState.capturing => (
        badge: 'FOTOAPARÁT',
        badgeBg: AppColors.nightPanel,
        badgeFg: AppColors.nightMuted,
        title: 'Otevírám skener…',
        body: 'Polož účtenku na rovnou plochu, ať se dobře ořízne.',
      ),
      _ScanState.reading => (
        badge: 'AI',
        badgeBg: AppColors.nightPanel,
        badgeFg: AppColors.nightMuted,
        title: 'Čtení účtenky…',
        body:
            'Většinou do 5 sekund. Fotka se pošle jen ke čtení a hned '
            'se zahodí, nikde se neukládá.',
      ),
      _ScanState.failed when problem == AiFallbackReason.busy => (
        badge: 'AI PŘETÍŽENÁ',
        badgeBg: const Color(0xFF4A3A14),
        badgeFg: const Color(0xFFF2D58A),
        title: 'AI čtení je teď přetížené',
        body:
            'Služba na čtení účtenek teď nestíhá a v telefonu se účtenku '
            'přečíst nepodařilo. Zkus to za chvíli znovu, fotka zůstala.',
      ),
      _ScanState.failed when problem == AiFallbackReason.offline => (
        badge: 'BEZ INTERNETU',
        badgeBg: const Color(0xFF4A3A14),
        badgeFg: const Color(0xFFF2D58A),
        title: 'Bez internetu se to nepovedlo',
        body:
            'AI čtení potřebuje internet a v telefonu se účtenku přečíst '
            'nepodařilo. Připoj se a zkus to znovu, fotka zůstala.',
      ),
      _ScanState.failed => (
        badge: 'NEPŘEČTENO',
        badgeBg: const Color(0xFF4A2224),
        badgeFg: const Color(0xFFF5B7B1),
        title: 'Účtenku se nepodařilo přečíst',
        body:
            'Fotka je rozmazaná nebo moc tmavá. Polož účtenku na rovnou '
            'plochu, rozsviť a vyfoť ji znovu.',
      ),
      _ScanState.onDevice => (
        badge: 'V TELEFONU',
        badgeBg: const Color(0xFF4A3A14),
        badgeFg: const Color(0xFFF2D58A),
        title: 'Přečteno v telefonu',
        body:
            '${switch (problem) {
              AiFallbackReason.busy => 'AI čtení bylo přetížené, tak se účtenka přečetla v telefonu. ',
              AiFallbackReason.offline => 'Bez internetu se účtenka přečetla v telefonu. ',
              _ => '',
            }}Čtení v telefonu je méně přesné. Projdi ceny a počty kusů, '
            'než položky rozdělíš. Řádek opravíš podržením.',
      ),
    };

    return Scaffold(
      backgroundColor: AppColors.night,
      body: SafeArea(
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: AppColors.nightText),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Zavřít',
                      onPressed: () {
                        _attempt++;
                        context.pop();
                      },
                      icon: const Icon(
                        LucideIcons.x,
                        color: AppColors.nightText,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Účtenka',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.nightMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
                  children: [
                    Center(child: _illustration()),
                    const SizedBox(height: 28),
                    Semantics(
                      liveRegion: true,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: copy.badgeBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              copy.badge,
                              style: AppFonts.money(
                                size: 11,
                                color: copy.badgeFg,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            copy.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            copy.body,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: AppColors.nightMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _actions(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actions() {
    switch (_state) {
      case _ScanState.capturing:
      case _ScanState.reading:
        return [
          AppButton(
            label: 'Zrušit',
            kind: AppButtonKind.ghost,
            onDark: true,
            height: 50,
            onPressed: () {
              _attempt++;
              context.pop();
            },
          ),
        ];
      case _ScanState.failed:
        return [
          if (_aiRetryable) ...[
            AppButton(label: 'Zkusit znovu', onDark: true, onPressed: _retryAi),
            const SizedBox(height: 10),
            AppButton(
              label: 'Vyfotit znovu',
              kind: AppButtonKind.ghost,
              onDark: true,
              height: 50,
              onPressed: _fromCamera,
            ),
          ] else
            AppButton(
              label: 'Vyfotit znovu',
              onDark: true,
              onPressed: _fromCamera,
            ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Zadat ručně',
            kind: AppButtonKind.ghost,
            onDark: true,
            height: 50,
            onPressed: _manual,
          ),
          _textLink('Vybrat fotku z galerie', _fromGallery),
          if (kDebugMode) _textLink('Ukázková účtenka (vývoj)', _openDemo),
        ];
      case _ScanState.onDevice:
        return [
          AppButton(
            label: 'Zkontrolovat položky',
            onDark: true,
            onPressed: () => _openAssign(_result!),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: _aiRetryable ? 'Zkusit znovu přes AI' : 'Vyfotit znovu',
            kind: AppButtonKind.ghost,
            onDark: true,
            height: 50,
            onPressed: _aiRetryable ? _retryAi : _fromCamera,
          ),
        ];
    }
  }

  Widget _textLink(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.nightText,
        minimumSize: const Size.fromHeight(44),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  /// A stylised receipt photo with a scanning line while reading.
  Widget _illustration() {
    const widths = [0.70, 0.55, 0.62, 0.48, 0.66, 0.40, 0.58, 0.52];
    final dimmed = _state == _ScanState.failed;
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: -0.035,
        child: Opacity(
          opacity: dimmed ? 0.45 : 1,
          child: Container(
            width: 220,
            height: 300,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            decoration: BoxDecoration(
              color: const Color(0xFFE9E4D8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Column(
                  children: [
                    _bar(0.6, 10, const Color(0xFFB8B1A2)),
                    const SizedBox(height: 10),
                    _bar(0.4, 6, const Color(0xFFCFC8B9)),
                    for (final w in widths) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: w,
                                child: _block(7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(width: 34, child: _block(7)),
                        ],
                      ),
                    ],
                  ],
                ),
                if (_state == _ScanState.reading)
                  AnimatedBuilder(
                    animation: _sweep,
                    builder: (context, _) => Positioned(
                      left: -20,
                      right: -20,
                      top: Curves.easeOutCubic.transform(_sweep.value) * 230,
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.emerald,
                              AppColors.emerald.withAlpha(40),
                              AppColors.emerald.withAlpha(0),
                            ],
                            stops: const [0.1, 0.12, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(double widthFactor, double height, Color color) =>
      FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _block(double height) => Container(
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFC3BCAD),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}
