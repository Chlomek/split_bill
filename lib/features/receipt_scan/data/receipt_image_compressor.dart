import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Shrinks a receipt photo before it is uploaded for recognition.
///
/// The document scanner already crops the photo to the receipt itself; what is
/// left to save is resolution. Receipt text stays readable well below camera
/// resolution, so the upload can be several times smaller.
class ReceiptImageCompressor {
  ReceiptImageCompressor._();

  /// Target for the shorter side (the receipt's width). Long receipts keep
  /// their full length, so the text never gets smaller than on a short one.
  static const int maxShortSide = 1200;

  static const int jpegQuality = 80;

  /// Returns a downscaled JPEG of [original]. Runs off the UI thread.
  /// Returns [original] unchanged if it cannot be decoded.
  static Future<Uint8List> compress(Uint8List original) =>
      compute(compressSync, original);

  @visibleForTesting
  static Uint8List compressSync(Uint8List original) {
    final decoded = img.decodeImage(original);
    if (decoded == null) return original;

    // Apply the EXIF rotation, since the re-encoded file carries no EXIF.
    var image = img.bakeOrientation(decoded);

    final shortSide = image.width < image.height ? image.width : image.height;
    if (shortSide > maxShortSide) {
      image = image.width <= image.height
          ? img.copyResize(
              image,
              width: maxShortSide,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              image,
              height: maxShortSide,
              interpolation: img.Interpolation.average,
            );
    }

    final encoded = img.encodeJpg(image, quality: jpegQuality);
    // Never send something bigger than what we started with.
    return encoded.length < original.length ? encoded : original;
  }
}
