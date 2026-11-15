import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gemini_receipt_scanner.dart';
import 'receipt_scanner_service.dart';

/// The receipt scanning engine used by the app. Swap the implementation here
/// (e.g. for the tier-aware scanner) without touching the screens.
final receiptScannerProvider = Provider<ReceiptScannerService>(
  (ref) => GeminiReceiptScanner(),
);
