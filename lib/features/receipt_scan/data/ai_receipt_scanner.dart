import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/failure.dart';
import '../domain/receipt_scan_result.dart';
import '../domain/scanned_receipt_item.dart';
import 'receipt_scanner_service.dart';

/// Cloud AI Vision scanner calling a Supabase Edge Function (`scan-receipt-ai`).
/// Returns high-accuracy structured items, currency, merchant, and total.
class AiReceiptScanner implements ReceiptScannerService {
  final SupabaseClient _supabase;

  AiReceiptScanner({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  @override
  ReceiptScannerType get type => ReceiptScannerType.aiVision;

  @override
  String get displayName => 'Cloud AI Vision';

  @override
  Future<ReceiptScanResult> scanReceipt(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Invoke Supabase Edge Function "scan-receipt-ai"
      final response = await _supabase.functions.invoke(
        'scan-receipt-ai',
        body: {
          'image': base64Image,
          'mimeType': 'image/jpeg',
        },
      );

      if (response.status != 200) {
        throw ScanFailure('AI Scanner failed with status ${response.status}');
      }

      final data = response.data is String
          ? jsonDecode(response.data as String) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;

      final rawItems = (data['items'] as List<dynamic>? ?? []);
      final items = rawItems
          .map((item) => ScannedReceiptItem.fromJson(item as Map<String, dynamic>))
          .toList();

      return ReceiptScanResult(
        items: items,
        totalAmount: (data['total'] as num?)?.toDouble(),
        subtotal: (data['subtotal'] as num?)?.toDouble(),
        tax: (data['tax'] as num?)?.toDouble(),
        currency: data['currency'] as String?,
        merchantName: data['merchant_name'] as String?,
        rawText: data['raw_text'] as String?,
        scannerType: ReceiptScannerType.aiVision,
        isAiProcessed: true,
      );
    } on FunctionException catch (e) {
      throw ScanFailure('AI Edge Function error: ${e.details ?? e.reasonPhrase ?? e.toString()}');
    } catch (e) {
      if (e is Failure) rethrow;
      throw ScanFailure('Failed to process receipt with AI: $e');
    }
  }
}
