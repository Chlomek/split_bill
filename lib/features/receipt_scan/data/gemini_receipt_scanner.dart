import 'dart:async';
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
  final ReceiptScannerService _mlKitFallback;
  final List<String>? _models;
  final List<Duration> _retryDelays;

  GeminiReceiptScanner({
    String? apiKey,
    http.Client? httpClient,
    ReceiptScannerService? mlKitFallback,
    List<String>? models,
    List<Duration> retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
    ],
  }) : _apiKey = apiKey ?? Env.geminiApiKey,
       _httpClient = httpClient ?? http.Client(),
       _mlKitFallback = mlKitFallback ?? MlKitReceiptScanner(),
       _models = models,
       _retryDelays = retryDelays;

  /// After this long one request is abandoned (and retried, if attempts
  /// remain).
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Statuses that mean "overloaded or briefly unavailable, try again".
  static const Set<int> _retryable = {429, 500, 502, 503, 504};

  /// Models tried in turn: the configured one twice, then the fallback
  /// model, which runs on separate capacity.
  List<String> get _attemptModels =>
      _models ?? [Env.geminiModel, Env.geminiModel, Env.geminiFallbackModel];

  Future<ReceiptScanResult> _fallback(
    File imageFile,
    AiFallbackReason reason,
  ) async {
    final result = await _mlKitFallback.scanReceipt(imageFile);
    return result.withFallbackReason(reason);
  }

  @override
  ReceiptScannerType get type => ReceiptScannerType.aiVision;

  @override
  String get displayName => 'Gemini Flash';

  @override
  Future<ReceiptScanResult> scanReceipt(File imageFile) async {
    final apiKey = _apiKey;
    if (apiKey == null ||
        apiKey.isEmpty ||
        apiKey == 'your_gemini_api_key_here') {
      // Fallback to local on-device ML Kit OCR if no API key is set
      debugPrint(
        'Receipt scan: no GEMINI_API_KEY in ${Env.fileName}, using on-device ML Kit.',
      );
      return await _fallback(imageFile, AiFallbackReason.noKey);
    }

    try {
      final originalBytes = await imageFile.readAsBytes();
      final bytes = await ReceiptImageCompressor.compress(originalBytes);
      debugPrint(
        'Receipt scan: uploading ${bytes.length ~/ 1024} kB '
        '(photo was ${originalBytes.length ~/ 1024} kB).',
      );
      final base64Image = base64Encode(bytes);

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
''',
              },
              {
                'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image},
              },
            ],
          },
        ],
        'generationConfig': {
          'response_mime_type': 'application/json',
          'temperature': 0.1,
        },
      };

      final body = jsonEncode(payload);
      final models = _attemptModels;
      http.Response? response;
      var reason = AiFallbackReason.error;

      for (var attempt = 0; attempt < models.length; attempt++) {
        if (attempt > 0) {
          final wait = _retryDelays.isEmpty
              ? Duration.zero
              : _retryDelays[(attempt - 1).clamp(0, _retryDelays.length - 1)];
          await Future<void>.delayed(wait);
        }
        final model = models[attempt];
        try {
          final res = await _httpClient
              .post(
                Uri.parse(
                  'https://generativelanguage.googleapis.com/v1beta/models/'
                  '$model:generateContent',
                ),
                headers: {
                  'Content-Type': 'application/json',
                  'x-goog-api-key': apiKey,
                },
                body: body,
              )
              .timeout(requestTimeout);
          if (res.statusCode == 200) {
            response = res;
            break;
          }
          debugPrint(
            'Receipt scan: Gemini ($model) returned HTTP ${res.statusCode}: '
            '${res.body}',
          );
          if (!_retryable.contains(res.statusCode)) {
            reason = AiFallbackReason.error;
            break;
          }
          reason = AiFallbackReason.busy;
        } on TimeoutException {
          debugPrint('Receipt scan: Gemini ($model) timed out.');
          reason = AiFallbackReason.busy;
        } on SocketException catch (e) {
          debugPrint('Receipt scan: no connection to Gemini: $e');
          reason = AiFallbackReason.offline;
          break;
        } on http.ClientException catch (e) {
          debugPrint('Receipt scan: no connection to Gemini: $e');
          reason = AiFallbackReason.offline;
          break;
        }
      }

      if (response == null) {
        debugPrint('Receipt scan: AI unavailable ($reason), using ML Kit.');
        return await _fallback(imageFile, reason);
      }

      final responseBody =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final candidates = responseBody['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        debugPrint(
          'Receipt scan: Gemini returned no candidates. Falling back to ML Kit.',
        );
        return await _fallback(imageFile, AiFallbackReason.error);
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
        generalDiscount: (parsedJson['general_discount'] as num?)
            ?.toDouble()
            .abs(),
        currency: parsedJson['currency'] as String? ?? 'CZK',
        merchantName: parsedJson['merchant_name'] as String?,
        scannerType: ReceiptScannerType.aiVision,
        isAiProcessed: true,
      );
    } catch (error, stackTrace) {
      // In case of network failure or parsing error, fallback to ML Kit
      debugPrint('Receipt scan: Gemini request failed: $error\n$stackTrace');
      return await _fallback(imageFile, AiFallbackReason.error);
    }
  }
}
