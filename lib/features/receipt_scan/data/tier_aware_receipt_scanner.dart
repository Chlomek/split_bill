import 'dart:io';
import '../domain/receipt_scan_result.dart';
import 'ai_receipt_scanner.dart';
import 'mlkit_receipt_scanner.dart';
import 'receipt_scanner_service.dart';

/// Quota callback or manager interface to check remaining AI scans.
typedef IsPremiumUserCallback = Future<bool> Function();
typedef GetRemainingAiScansCallback = Future<int> Function();
typedef ConsumeAiScanCallback = Future<void> Function();

/// Smart proxy scanner that selects between AI and ML Kit based on
/// the user's subscription tier and remaining free AI quota.
class TierAwareReceiptScanner implements ReceiptScannerService {
  final ReceiptScannerService _aiScanner;
  final ReceiptScannerService _mlKitScanner;
  final IsPremiumUserCallback _isPremium;
  final GetRemainingAiScansCallback _getRemainingAiScans;
  final ConsumeAiScanCallback _consumeAiScan;

  TierAwareReceiptScanner({
    ReceiptScannerService? aiScanner,
    ReceiptScannerService? mlKitScanner,
    required IsPremiumUserCallback isPremium,
    required GetRemainingAiScansCallback getRemainingAiScans,
    required ConsumeAiScanCallback consumeAiScan,
  })  : _aiScanner = aiScanner ?? AiReceiptScanner(),
        _mlKitScanner = mlKitScanner ?? MlKitReceiptScanner(),
        _isPremium = isPremium,
        _getRemainingAiScans = getRemainingAiScans,
        _consumeAiScan = consumeAiScan;

  @override
  ReceiptScannerType get type => ReceiptScannerType.aiVision;

  @override
  String get displayName => 'Smart Tier-Aware Scanner';

  @override
  Future<ReceiptScanResult> scanReceipt(
    File imageFile, {
    bool forceOffline = false,
  }) async {
    if (forceOffline) {
      return _mlKitScanner.scanReceipt(imageFile);
    }

    final isPremium = await _isPremium();

    if (isPremium) {
      // Premium users get unlimited AI scans
      try {
        return await _aiScanner.scanReceipt(imageFile);
      } catch (_) {
        // Fallback to offline ML Kit if network/AI is unavailable
        return _mlKitScanner.scanReceipt(imageFile);
      }
    }

    // Free users: check monthly quota
    final remainingScans = await _getRemainingAiScans();

    if (remainingScans > 0) {
      try {
        final result = await _aiScanner.scanReceipt(imageFile);
        await _consumeAiScan();
        return result;
      } catch (_) {
        return _mlKitScanner.scanReceipt(imageFile);
      }
    }

    // Free quota exhausted: fallback to on-device ML Kit OCR
    return _mlKitScanner.scanReceipt(imageFile);
  }
}
