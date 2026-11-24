import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:split_bill/features/receipt_scan/data/gemini_receipt_scanner.dart';
import 'package:split_bill/features/receipt_scan/data/receipt_scanner_service.dart';
import 'package:split_bill/features/receipt_scan/domain/receipt_scan_result.dart';

/// Stands in for the on-device reader, which needs a real phone.
class _FakeOnDevice implements ReceiptScannerService {
  int calls = 0;

  @override
  ReceiptScannerType get type => ReceiptScannerType.mlKit;

  @override
  String get displayName => 'fake';

  @override
  Future<ReceiptScanResult> scanReceipt(File imageFile) async {
    calls++;
    return const ReceiptScanResult(
      items: [],
      scannerType: ReceiptScannerType.mlKit,
      isAiProcessed: false,
    );
  }
}

http.Response _ok() => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'text': jsonEncode({
                  'total': 50,
                  'items': [
                    {'name': 'Pivo', 'quantity': 1, 'line_total': 50},
                  ],
                }),
              },
            ],
          },
        },
      ],
    }),
  ),
  200,
);

void main() {
  late File photo;

  setUpAll(() {
    dotenv.testLoad(fileInput: '');
    photo = File('${Directory.systemTemp.createTempSync().path}/r.jpg')
      ..writeAsBytesSync([1, 2, 3]);
  });

  GeminiReceiptScanner scanner(
    List<http.Response> responses,
    List<String> requestedModels,
    _FakeOnDevice onDevice,
  ) {
    var i = 0;
    return GeminiReceiptScanner(
      apiKey: 'test-key',
      models: const ['lite', 'lite', 'flash'],
      retryDelays: const [Duration.zero],
      mlKitFallback: onDevice,
      httpClient: MockClient((request) async {
        requestedModels.add(request.url.pathSegments.last.split(':').first);
        expect(
          request.url.queryParameters.containsKey('key'),
          isFalse,
          reason: 'the API key must not be in the URL',
        );
        expect(request.headers['x-goog-api-key'], 'test-key');
        return responses[i++];
      }),
    );
  }

  test('retries an overloaded model and succeeds on the second try', () async {
    final models = <String>[];
    final onDevice = _FakeOnDevice();
    final result = await scanner(
      [http.Response('{"error":{"code":503}}', 503), _ok()],
      models,
      onDevice,
    ).scanReceipt(photo);

    expect(models, ['lite', 'lite']);
    expect(result.scannerType, ReceiptScannerType.aiVision);
    expect(result.items.single.name, 'Pivo');
    expect(onDevice.calls, 0);
  });

  test(
    'falls back to the second model, then to the phone, and says why',
    () async {
      final models = <String>[];
      final onDevice = _FakeOnDevice();
      final busy = http.Response('{"error":{"code":503}}', 503);
      final result = await scanner(
        [busy, busy, busy],
        models,
        onDevice,
      ).scanReceipt(photo);

      expect(models, ['lite', 'lite', 'flash']);
      expect(onDevice.calls, 1);
      expect(result.fallbackReason, AiFallbackReason.busy);
    },
  );

  test('does not retry an error that retrying cannot fix', () async {
    final models = <String>[];
    final onDevice = _FakeOnDevice();
    final result = await scanner(
      [http.Response('{"error":{"code":400}}', 400)],
      models,
      onDevice,
    ).scanReceipt(photo);

    expect(models, ['lite']);
    expect(result.fallbackReason, AiFallbackReason.error);
  });
}
