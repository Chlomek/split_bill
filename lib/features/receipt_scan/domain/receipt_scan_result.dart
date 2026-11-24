import 'scanned_receipt_item.dart';

/// Identifier for which OCR / Vision engine produced the scan.
enum ReceiptScannerType { aiVision, mlKit, manual }

/// Why the AI could not read the receipt and the on-device reader was used.
enum AiFallbackReason {
  /// No GEMINI_API_KEY configured.
  noKey,

  /// The AI service was overloaded or rate-limited, even after retrying.
  busy,

  /// No connection to the AI service.
  offline,

  /// Any other error (bad response, unexpected status).
  error,
}

/// Normalized output produced by any receipt scanning engine.
class ReceiptScanResult {
  final List<ScannedReceiptItem> items;
  final double? subtotal;
  final double? tax;

  /// Discount on the whole purchase (e.g. a percentage coupon), as a positive
  /// number. It is already reflected in [totalAmount].
  final double? generalDiscount;
  final double? totalAmount;
  final String? currency;
  final String? merchantName;
  final DateTime? date;
  final String? rawText;
  final ReceiptScannerType scannerType;
  final bool isAiProcessed;

  /// Set when the AI was tried but the on-device reader produced this result.
  final AiFallbackReason? fallbackReason;

  const ReceiptScanResult({
    required this.items,
    this.subtotal,
    this.tax,
    this.generalDiscount,
    this.totalAmount,
    this.currency,
    this.merchantName,
    this.date,
    this.rawText,
    required this.scannerType,
    required this.isAiProcessed,
    this.fallbackReason,
  });

  /// The same result, marked with why the AI was not used.
  ReceiptScanResult withFallbackReason(AiFallbackReason reason) =>
      ReceiptScanResult(
        items: items,
        subtotal: subtotal,
        tax: tax,
        generalDiscount: generalDiscount,
        totalAmount: totalAmount,
        currency: currency,
        merchantName: merchantName,
        date: date,
        rawText: rawText,
        scannerType: scannerType,
        isAiProcessed: isAiProcessed,
        fallbackReason: reason,
      );

  /// Computed total if totalAmount was not explicitly parsed.
  double get calculatedTotal =>
      totalAmount ??
      items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  factory ReceiptScanResult.empty({
    ReceiptScannerType scannerType = ReceiptScannerType.manual,
  }) {
    return ReceiptScanResult(
      items: const [],
      scannerType: scannerType,
      isAiProcessed: false,
    );
  }
}
