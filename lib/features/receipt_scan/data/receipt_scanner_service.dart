import 'dart:io';
import '../domain/receipt_scan_result.dart';

/// Contract for all receipt scanning engines (AI, ML Kit, Mock, etc.).
/// This makes OCR engines fully swappable without affecting UI or business logic.
abstract class ReceiptScannerService {
  /// Unique identifier of the scanning engine.
  ReceiptScannerType get type;

  /// Human-readable name of the engine.
  String get displayName;

  /// Scans the given receipt [imageFile] and returns structured line items.
  Future<ReceiptScanResult> scanReceipt(File imageFile);
}
