import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/services/document_capture_service.dart';
import '../data/mlkit_receipt_scanner.dart';
import '../data/receipt_scanner_service.dart';

/// Screen allowing users to launch the camera document scanner or pick a receipt from gallery.
class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  final DocumentCaptureService _captureService = DocumentCaptureService();
  final ReceiptScannerService _scannerService = MlKitReceiptScanner();
  bool _isLoading = false;
  String? _statusMessage;

  Future<void> _scanWithCamera() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Skenování účtenky...';
    });

    try {
      final files = await _captureService.scanReceiptWithCamera();
      if (files.isNotEmpty) {
        await _processImage(files.first);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při snímání: $e')),
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
      _statusMessage = 'Rozpoznávání položek...';
    });

    try {
      final result = await _scannerService.scanReceipt(file);
      if (mounted) {
        context.push(RouteNames.assignItems, extra: result);
      }
    } catch (e) {
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
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage ?? 'Zpracovávám...',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
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
                      'Automatické oříznutí a načtení položek bez ručního zadávání.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(LucideIcons.camera),
                        label: const Text('Spustit fotoaparát / skener'),
                        onPressed: _scanWithCamera,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(LucideIcons.image),
                        label: const Text('Vybrat z galerie'),
                        onPressed: _pickFromGallery,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
