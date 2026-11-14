import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('buckRecognizeReceiptBase64')
external JSPromise<JSString?>? _jsRecognizeReceiptBase64(JSString base64Image);

/// Web / Safari browser OCR engine powered by Tesseract.js via `dart:js_interop`.
///
/// Allows testing real receipt OCR directly on iPhone Safari without requiring
/// a macOS Xcode build. Returns `null` if bytes are empty, Tesseract fails,
/// or recognition times out.
Future<String?> extractNativeOcrText({
  String? imagePath,
  Uint8List? imageBytes,
}) async {
  if (imageBytes == null || imageBytes.isEmpty) {
    return null;
  }

  try {
    final encoded = base64Encode(imageBytes);
    final promise = _jsRecognizeReceiptBase64(encoded.toJS);
    if (promise == null) return null;

    final result = await promise.toDart.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
    final text = result?.toDart.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  } catch (_) {
    return null;
  }
}
