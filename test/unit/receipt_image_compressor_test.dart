import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:split_bill/features/receipt_scan/data/receipt_image_compressor.dart';

Uint8List _photo(int width, int height) {
  final image = img.Image(width: width, height: height);
  // Noise, so the JPEG is not trivially small.
  for (final pixel in image) {
    final v = (pixel.x * 31 + pixel.y * 17) % 256;
    pixel.setRgb(v, 255 - v, (v * 3) % 256);
  }
  return img.encodeJpg(image, quality: 100);
}

void main() {
  test('downscales a large photo so its short side is 1200 px', () {
    final original = _photo(2400, 3200);
    final result = ReceiptImageCompressor.compressSync(original);
    final decoded = img.decodeJpg(result)!;

    expect(decoded.width, 1200);
    expect(decoded.height, 1600);
    expect(result.length, lessThan(original.length));
  });

  test('keeps the full length of a long, narrow receipt', () {
    final result = ReceiptImageCompressor.compressSync(_photo(800, 3000));
    final decoded = img.decodeJpg(result)!;

    expect(decoded.width, 800);
    expect(decoded.height, 3000);
  });

  test('returns the input unchanged when it is not an image', () {
    final garbage = Uint8List.fromList([1, 2, 3, 4]);
    expect(ReceiptImageCompressor.compressSync(garbage), same(garbage));
  });
}
