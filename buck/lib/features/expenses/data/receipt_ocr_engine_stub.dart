import 'dart:typed_data';

/// Web/non-IO stub for native ML Kit text recognition.
Future<String?> extractNativeOcrText({
  String? imagePath,
  Uint8List? imageBytes,
}) async {
  return null;
}

/// Optional engine pre-warming hook (used on Web to preload Tesseract.js).
void warmupNativeOcr() {}
