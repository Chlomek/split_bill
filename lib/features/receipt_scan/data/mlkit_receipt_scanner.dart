import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../domain/receipt_scan_result.dart';
import '../domain/scanned_receipt_item.dart';
import 'receipt_scanner_service.dart';

/// On-device local OCR scanner using Google ML Kit Text Recognition.
/// Works offline on both Android and iOS with zero API cost.
class MlKitReceiptScanner implements ReceiptScannerService {
  @override
  ReceiptScannerType get type => ReceiptScannerType.mlKit;

  @override
  String get displayName => 'On-Device ML Kit';

  @override
  Future<ReceiptScanResult> scanReceipt(File imageFile) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      final List<ScannedReceiptItem> parsedItems = [];
      double? detectedTotal;

      // Regular expressions for price detection (e.g. 45.00, 45,50 CZK, $12.99)
      final priceRegex = RegExp(r'(\d+[\.,]\d{2})');
      final totalKeywordRegex = RegExp(
        r'(celkem|total|sum|suma|k\s*úhradě|celkem\s*k\s*úhradě)',
        caseSensitive: false,
      );

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.isEmpty) continue;

          // Check for total line
          if (totalKeywordRegex.hasMatch(text)) {
            final match = priceRegex.firstMatch(text);
            if (match != null) {
              final parsedVal =
                  double.tryParse(match.group(1)!.replaceAll(',', '.'));
              if (parsedVal != null) {
                detectedTotal = parsedVal;
                continue;
              }
            }
          }

          // Check if line contains a price at the end
          final matches = priceRegex.allMatches(text).toList();
          if (matches.isNotEmpty) {
            final lastMatch = matches.last;
            final priceString = lastMatch.group(1)!.replaceAll(',', '.');
            final price = double.tryParse(priceString);

            if (price != null && price > 0) {
              final itemName = text
                  .substring(0, lastMatch.start)
                  .replaceAll(RegExp(r'[\*\-_=:]'), '')
                  .trim();

              if (itemName.isNotEmpty && itemName.length > 1) {
                parsedItems.add(
                  ScannedReceiptItem(
                    name: itemName,
                    price: price,
                    quantity: 1,
                  ),
                );
              }
            }
          }
        }
      }

      return ReceiptScanResult(
        items: parsedItems,
        totalAmount: detectedTotal,
        rawText: recognizedText.text,
        scannerType: ReceiptScannerType.mlKit,
        isAiProcessed: false,
      );
    } finally {
      await textRecognizer.close();
    }
  }
}
