import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/env.dart';
import '../domain/receipt_scan_result.dart';
import '../domain/scanned_receipt_item.dart';
import 'mlkit_receipt_scanner.dart';
import 'receipt_image_compressor.dart';
import 'receipt_scanner_service.dart';

/// Cloud AI Vision scanner calling a Gemini Flash model directly (see Env.geminiModel).
/// Extracts line items, quantities, prices, taxes, and total with high accuracy.
/// Falls back to on-device ML Kit if API key is missing or offline.
class GeminiReceiptScanner implements ReceiptScannerService {
  final String? _apiKey;
  final http.Client _httpClient;
  final MlKitReceiptScanner _mlKitFallback;

  GeminiReceiptScanner({
    String? apiKey,
    http.Client? httpClient,
    MlKitReceiptScanner? mlKitFallback,
  })  : _apiKey = apiKey ?? Env.geminiApiKey,
        _httpClient = httpClient ?? http.Client(),
        _mlKitFallback = mlKitFallback ?? MlKitReceiptScanner();

  /// After this long the request is abandoned and ML Kit is used instead.
  static const Duration requestTimeout = Duration(seconds: 30);

  @override
  ReceiptScannerType get type => ReceiptScannerType.aiVision;

  @override
  String get displayName => 'Gemini Flash';

  @override
  Future<ReceiptScanResult> scanReceipt(File imageFile) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_gemini_api_key_here') {
      // Fallback to local on-device ML Kit OCR if no API key is set
      debugPrint('Receipt scan: no GEMINI_API_KEY in ${Env.fileName}, using on-device ML Kit.');
      return await _mlKitFallback.scanReceipt(imageFile);
    }

    try {
      final originalBytes = await imageFile.readAsBytes();
      final bytes = await ReceiptImageCompressor.compress(originalBytes);
      debugPrint(
        'Receipt scan: uploading ${bytes.length ~/ 1024} kB '
        '(photo was ${originalBytes.length ~/ 1024} kB).',
      );
      final base64Image = base64Encode(bytes);

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${Env.geminiModel}:generateContent?key=$apiKey',
      );

      final payload = {
        'contents': [
          {
            'parts': [
              {
                'text': '''
You are an expert receipt parser. Analyze this receipt image and extract:
1. All purchased items with exact item name, quantity, line_total and discount.
   line_total is the full amount charged for that line (all pieces together),
   exactly as printed in the price column, before any discount. Do not
   multiply or divide it.
2. Discounts. Lines with a negative amount (e.g. "SLEVA", "KUPON", or a prefix
   such as "CC" followed by an item name) are discounts, never items.
   - If a discount line names one specific item, add its amount to that
     item's "discount" as a positive number (0 when the item has none).
   - Discounts on the whole purchase (percentage coupons, loyalty cards)
     go to "general_discount" as a positive number.
   - Ignore summary lines such as subtotal ("mezisoučet") and total savings
     ("celková úspora").
3. The total sum actually paid (celkem / total).
4. The merchant/restaurant name.
5. Currency (CZK, EUR, USD, etc. Default to CZK if Czech crowns or no symbol).
6. Subtotal and tax if explicitly listed.

Return ONLY a valid JSON object matching this schema:
{
  "merchant_name": "string or null",
  "currency": "CZK",
  "total": 0.0,
  "subtotal": 0.0,
  "tax": 0.0,
  "general_discount": 0.0,
  "items": [
    {
      "name": "Item description",
      "quantity": 1,
      "line_total": 0.0,
      "discount": 0.0
    }
  ]
}
'''
              },
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Image,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'response_mime_type': 'application/json',
          'temperature': 0.1,
        }
      };

      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(requestTimeout);

      if (response.statusCode != 200) {
        // Fallback to local OCR if Gemini endpoint returns error
        debugPrint(
          'Receipt scan: Gemini (${Env.geminiModel}) returned HTTP '
          '${response.statusCode}: ${response.body}. Falling back to ML Kit.',
        );
        return await _mlKitFallback.scanReceipt(imageFile);
      }

      final responseBody = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final candidates = responseBody['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        debugPrint('Receipt scan: Gemini returned no candidates. Falling back to ML Kit.');
        return await _mlKitFallback.scanReceipt(imageFile);
      }

      final content = candidates.first['content'] as Map<String, dynamic>;
      final parts = content['parts'] as List<dynamic>;
      // Newer models may return extra parts (e.g. thoughts) before the answer.
      final text = parts
          .cast<Map<String, dynamic>>()
          .where((part) => part['text'] is String && part['thought'] != true)
          .map((part) => part['text'] as String)
          .join();

      final parsedJson = jsonDecode(text) as Map<String, dynamic>;
      final rawItems = parsedJson['items'] as List<dynamic>? ?? [];

      final items = rawItems.map((item) {
        final itemMap = item as Map<String, dynamic>;
        final quantity = ((itemMap['quantity'] ?? 1) as num).toInt();
        final safeQuantity = quantity < 1 ? 1 : quantity;
        // The model reports the amount for the whole line; the app stores the
        // price of one piece, so that price * quantity equals the line total.
        final lineTotal = itemMap['line_total'] as num?;
        // A discount printed for this specific item is folded into its price,
        // so nobody has to assign the discount line separately.
        final discount = ((itemMap['discount'] ?? 0) as num).toDouble().abs();
        final unitPrice = lineTotal != null
            ? (lineTotal.toDouble() - discount) / safeQuantity
            : ((itemMap['price'] ?? 0) as num).toDouble();
        return ScannedReceiptItem(
          name: (itemMap['name'] ?? 'Položka').toString(),
          price: unitPrice,
          quantity: safeQuantity,
          discount: lineTotal != null ? discount : 0,
        );
      }).toList();

      return ReceiptScanResult(
        items: items,
        totalAmount: (parsedJson['total'] as num?)?.toDouble(),
        subtotal: (parsedJson['subtotal'] as num?)?.toDouble(),
        tax: (parsedJson['tax'] as num?)?.toDouble(),
        generalDiscount: (parsedJson['general_discount'] as num?)?.toDouble().abs(),
        currency: parsedJson['currency'] as String? ?? 'CZK',
        merchantName: parsedJson['merchant_name'] as String?,
        scannerType: ReceiptScannerType.aiVision,
        isAiProcessed: true,
      );
    } catch (error, stackTrace) {
      // In case of network failure or parsing error, fallback to ML Kit
      debugPrint('Receipt scan: Gemini request failed: $error\n$stackTrace');
      return await _mlKitFallback.scanReceipt(imageFile);
    }
  }
}
