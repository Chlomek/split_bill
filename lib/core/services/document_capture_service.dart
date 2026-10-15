import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image_picker/image_picker.dart';

/// Service responsible for capturing receipt images using either the
/// native document scanner (auto-edge detection, perspective crop)
/// or photo gallery fallback.
class DocumentCaptureService {
  final ImagePicker _imagePicker;

  DocumentCaptureService({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  /// Launches the native document scanner (Google ML Kit on Android, VisionKit on iOS).
  /// Returns a list of captured and auto-cropped image files.
  Future<List<File>> scanReceiptWithCamera({int maxPages = 3}) async {
    try {
      final List<String>? pictures = await CunningDocumentScanner.getPictures(
        noOfPages: maxPages,
      );
      if (pictures == null || pictures.isEmpty) return [];
      return pictures.map((path) => File(path)).toList();
    } catch (_) {
      // Fallback to standard camera if document scanner fails or is unavailable
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      return photo != null ? [File(photo.path)] : [];
    }
  }

  /// Picks a receipt photo from the device gallery.
  Future<File?> pickReceiptFromGallery() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    return image != null ? File(image.path) : null;
  }
}
