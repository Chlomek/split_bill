import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/services/document_capture_service.dart';
import '../data/receipt_scanner_provider.dart';
import '../domain/receipt_scan_result.dart';
import '../domain/scanned_receipt_item.dart';

/// Screen allowing users to launch the document scanner, pick a photo,
/// or load a sample receipt for quick testing.
class ScanReceiptScreen extends ConsumerStatefulWidget {
  final String groupId;

  const ScanReceiptScreen({super.key, required this.groupId});

  @override
  ConsumerState<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends ConsumerState<ScanReceiptScreen> {
  final DocumentCaptureService _captureService = DocumentCaptureService();
  bool _isLoading = false;
  String? _statusMessage;

  Future<void> _scanWithCamera() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Otevírám fotoaparát a skener...';
    });

    try {
      final files = await _captureService.scanReceiptWithCamera();
      if (files.isNotEmpty) {
        await _processImage(files.first);
      }
    } catch (e, stackTrace) {
      debugPrint('Receipt capture failed: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Snímání zrušeno nebo selhalo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final file = await _captureService.pickReceiptFromGallery();
    if (file != null) {
      await _processImage(file);
    }
  }

  Future<void> _processImage(File file) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'AI rozpoznává položky na účtence...';
    });

    try {
      final result = await ref.read(receiptScannerProvider).scanReceipt(file);
      debugPrint(
        'Receipt scan (${result.scannerType.name}): ${result.items.length} items, '
        'total ${result.totalAmount}. Raw text: ${result.rawText}',
      );
      if (mounted) {
        if (result.items.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Na snímku se nepodařilo rozpoznat položky. Zkuste účtenku vyfotit s lepším světlem.'),
            ),
          );
        } else {
          context.push(RouteNames.assignItems(widget.groupId), extra: result);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Receipt recognition failed: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při čtení účtenky: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
        });
      }
    }
  }

  /// Loads sample demo items for immediate testing without physical paper receipts
  void _loadDemoReceipt() {
    final demoResult = ReceiptScanResult(
      merchantName: 'Restaurace U Medvídka',
      totalAmount: 430.0,
      currency: 'CZK',
      scannerType: ReceiptScannerType.aiVision,
      isAiProcessed: true,
      items: [
        ScannedReceiptItem(name: 'Pizza Margherita', price: 190.0, quantity: 1),
        ScannedReceiptItem(name: 'Plzeňské pivo 12°', price: 60.0, quantity: 2),
        ScannedReceiptItem(name: 'Domácí limonáda', price: 65.0, quantity: 1),
        ScannedReceiptItem(name: 'Espresso', price: 55.0, quantity: 1),
      ],
    );

    context.push(RouteNames.assignItems(widget.groupId), extra: demoResult);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Naskenovat účtenku')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF10B981)),
                    const SizedBox(height: 20),
                    Text(
                      _statusMessage ?? 'Zpracovávám...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gemini / ML Kit',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.scanLine,
                        size: 72,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Vyfoťte účtenku',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Automatické oříznutí a vytažení položek s cenami pomocí AI.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(LucideIcons.camera),
                        label: const Text('Spustit fotoaparát a skener'),
                        onPressed: _scanWithCamera,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(LucideIcons.image),
                        label: const Text('Vybrat z fotogalerie'),
                        onPressed: _pickFromGallery,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      icon: const Icon(LucideIcons.sparkles, size: 16),
                      label: const Text('Otestovat s ukázkovou účtenkou (Demo)'),
                      onPressed: _loadDemoReceipt,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
