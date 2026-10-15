import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/config/env.dart';
import '../domain/receipt_scan_result.dart';
import '../domain/scanned_receipt_item.dart';
import 'mlkit_receipt_scanner.dart';
import 'receipt_scanner_service.dart';

/// Cloud AI Vision scanner calling Gemini 2.0 Flash directly.
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

  @override
  ReceiptScannerType get type => ReceiptScannerType.aiVision;

  @override
  String get displayName => 'Gemini 2.0 Flash';

  @override
  Future<ReceiptScanResult> scanReceipt(File imageFile) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_gemini_api_key_here') {
      // Fallback to local on-device ML Kit OCR if no API key is set
      return _mlKitFallback.scanReceipt(imageFile);
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
      );

      final payload = {
        'contents': [
          {
            'parts': [
              {
                'text': '''
You are an expert receipt parser. Analyze this receipt image and extract:
1. All purchased items with exact item name, individual item price, and quantity.
2. The total sum (celkem / total).
3. The merchant/restaurant name.
4. Currency (CZK, EUR, USD, etc. Default to CZK if Czech crowns or no symbol).
5. Subtotal and tax if explicitly listed.

Return ONLY a valid JSON object matching this schema:
{
  "merchant_name": "string or null",
  "currency": "CZK",
  "total": 0.0,
  "subtotal": 0.0,
  "tax": 0.0,
  "items": [
    {
      "name": "Item description",
      "price": 0.0,
      "quantity": 1
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
      );

      if (response.statusCode != 200) {
        // Fallback to local OCR if Gemini endpoint returns error
        return _mlKitFallback.scanReceipt(imageFile);
      }

      final responseBody = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final candidates = responseBody['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        return _mlKitFallback.scanReceipt(imageFile);
      }

      final content = candidates.first['content'] as Map<String, dynamic>;
      final parts = content['parts'] as List<dynamic>;
      final text = parts.first['text'] as String;

      final parsedJson = jsonDecode(text) as Map<String, dynamic>;
      final rawItems = parsedJson['items'] as List<dynamic>? ?? [];

      final items = rawItems.map((item) {
        final itemMap = item as Map<String, dynamic>;
        return ScannedReceiptItem(
          name: (itemMap['name'] ?? 'Položka').toString(),
          price: ((itemMap['price'] ?? 0) as num).toDouble(),
          quantity: ((itemMap['quantity'] ?? 1) as num).toInt(),
        );
      }).toList();

      return ReceiptScanResult(
        items: items,
        totalAmount: (parsedJson['total'] as num?)?.toDouble(),
        subtotal: (parsedJson['subtotal'] as num?)?.toDouble(),
        tax: (parsedJson['tax'] as num?)?.toDouble(),
        currency: parsedJson['currency'] as String? ?? 'CZK',
        merchantName: parsedJson['merchant_name'] as String?,
        scannerType: ReceiptScannerType.aiVision,
        isAiProcessed: true,
      );
    } catch (_) {
      // In case of network failure or parsing error, fallback to ML Kit
      return _mlKitFallback.scanReceipt(imageFile);
    }
  }
}
