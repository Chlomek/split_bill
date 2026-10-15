import 'scanned_receipt_item.dart';

/// Identifier for which OCR / Vision engine produced the scan.
enum ReceiptScannerType {
  aiVision,
  mlKit,
  manual,
}

/// Normalized output produced by any receipt scanning engine.
class ReceiptScanResult {
  final List<ScannedReceiptItem> items;
  final double? subtotal;
  final double? tax;
  final double? totalAmount;
  final String? currency;
  final String? merchantName;
  final DateTime? date;
  final String? rawText;
  final ReceiptScannerType scannerType;
  final bool isAiProcessed;

  const ReceiptScanResult({
    required this.items,
    this.subtotal,
    this.tax,
    this.totalAmount,
    this.currency,
    this.merchantName,
    this.date,
    this.rawText,
    required this.scannerType,
    required this.isAiProcessed,
  });

  /// Computed total if totalAmount was not explicitly parsed.
  double get calculatedTotal =>
      totalAmount ?? items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  factory ReceiptScanResult.empty({ReceiptScannerType scannerType = ReceiptScannerType.manual}) {
    return ReceiptScanResult(
      items: const [],
      scannerType: scannerType,
      isAiProcessed: false,
    );
  }
}
