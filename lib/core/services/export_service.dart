import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service responsible for exporting expense records and settlements to CSV,
/// and sharing the exported file via native system sheet.
class ExportService {
  ExportService._();

  /// Converts tabular data to CSV and triggers the native OS Share dialog.
  static Future<void> exportAndShareExpensesCsv({
    required String groupName,
    required List<List<dynamic>> rows,
  }) async {
    final csvString = const ListToCsvConverter().convert(rows);

    final directory = await getTemporaryDirectory();
    final sanitizedName = groupName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final fileName = 'split_bill_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${directory.path}/$fileName');

    await file.writeAsString(csvString);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Exported expenses for group "$groupName"',
      subject: 'Split Bill Export - $groupName',
    );
  }
}
