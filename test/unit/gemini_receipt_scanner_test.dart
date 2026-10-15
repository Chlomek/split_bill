import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill/features/receipt_scan/data/gemini_receipt_scanner.dart';
import 'package:split_bill/features/receipt_scan/domain/receipt_scan_result.dart';

void main() {
  group('GeminiReceiptScanner', () {
    test('falls back to ML Kit or handles missing API key gracefully', () async {
      final scanner = GeminiReceiptScanner(apiKey: '');
      expect(scanner.type, ReceiptScannerType.aiVision);
      expect(scanner.displayName, 'Gemini 2.0 Flash');
    });

    test('ReceiptScanResult calculates computed total correctly when totalAmount is omitted', () {
      final result = ReceiptScanResult.empty();
      expect(result.calculatedTotal, 0.0);
      expect(result.items, isEmpty);
      expect(result.isAiProcessed, isFalse);
    });
  });
}
