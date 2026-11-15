import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:split_bill/core/utils/split_calculator.dart';
import 'package:split_bill/features/receipt_scan/data/gemini_receipt_scanner.dart';
import 'package:split_bill/features/receipt_scan/domain/receipt_scan_result.dart';

/// Wraps [answer] the way the Gemini API returns it.
http.Response _geminiResponse(Map<String, dynamic> answer) => http.Response.bytes(
      utf8.encode(jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': jsonEncode(answer)},
              ],
            },
          },
        ],
      })),
      200,
    );

void main() {
  late File photo;

  setUpAll(() {
    dotenv.testLoad(fileInput: '');
    photo = File('${Directory.systemTemp.createTempSync().path}/receipt.jpg')
      ..writeAsBytesSync([1, 2, 3]);
  });

  test('folds item discounts into prices and keeps the general discount apart',
      () async {
    final scanner = GeminiReceiptScanner(
      apiKey: 'test-key',
      httpClient: MockClient(
        (_) async => _geminiResponse({
          'merchant_name': 'Tesco',
          'currency': 'CZK',
          'total': 92.61,
          'general_discount': 10.29,
          'items': [
            {'name': 'JOJO KAKTUS 80g', 'quantity': 1, 'line_total': 29.9, 'discount': 13.0},
            {'name': 'MENTOS', 'quantity': 2, 'line_total': 39.8, 'discount': 10.0},
            {'name': 'BAGETKA', 'quantity': 3, 'line_total': 11.7, 'discount': 0.0},
            {'name': 'CHIPSY', 'quantity': 1, 'line_total': 44.5},
          ],
        }),
      ),
    );

    final result = await scanner.scanReceipt(photo);

    expect(result.scannerType, ReceiptScannerType.aiVision);
    expect(result.items, hasLength(4));
    expect(result.generalDiscount, 10.29);
    expect(result.totalAmount, 92.61);

    final jojo = result.items[0];
    expect(jojo.price, closeTo(16.9, 0.0001));
    expect(jojo.discount, 13.0);

    // 39.80 for two pieces, minus 10 -> 14.90 each.
    final mentos = result.items[1];
    expect(mentos.quantity, 2);
    expect(mentos.price, closeTo(14.9, 0.0001));

    // Line total is for all three pieces.
    expect(result.items[2].price, closeTo(3.9, 0.0001));
    expect(result.items[3].discount, 0);

    // Items after their own discounts: 16.90 + 29.80 + 11.70 + 44.50 = 102.90.
    // The remaining 10.29 coupon is spread proportionally by the calculator.
    final shares = SplitCalculator.splitItems(
      items: [
        for (final item in result.items) item.copyWith(assignedMemberIds: ['a']),
      ],
      scannedTotal: result.totalAmount,
    );
    expect(shares, {'a': 92.61});
  });
}
