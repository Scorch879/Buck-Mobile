import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Optional engine pre-warming hook (ML Kit initializes locally on demand).
void warmupNativeOcr() {}

/// On-device ML Vision OCR engine using Google ML Kit Text Recognition v2.
///
/// Runs offline on Android and iOS without transmitting receipt images over
/// the network (SRS 3.5.1 / SDD 5.1 Stage 3). Falls back to writing [imageBytes]
/// to a temporary file when [imagePath] is missing or inaccessible (e.g. URI).
/// Returns `null` on desktop/test environments or if OCR fails.
Future<String?> extractNativeOcrText({
  String? imagePath,
  Uint8List? imageBytes,
}) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return null;
  }

  File? tempFile;
  String? resolvedPath;

  if (imagePath != null && imagePath.isNotEmpty) {
    final candidate = File(imagePath);
    if (candidate.existsSync()) {
      resolvedPath = imagePath;
    }
  }

  if (resolvedPath == null && imageBytes != null && imageBytes.isNotEmpty) {
    try {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      tempFile = File('${Directory.systemTemp.path}/buck_ocr_$stamp.jpg');
      await tempFile.writeAsBytes(imageBytes, flush: true);
      resolvedPath = tempFile.path;
    } catch (e) {
      debugPrint('ReceiptOcrEngine: temp image write failed ($e)');
      return null;
    }
  }

  if (resolvedPath == null) {
    return null;
  }

  final inputImage = InputImage.fromFilePath(resolvedPath);
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  try {
    final recognized = await recognizer.processImage(inputImage);
    final text = recognized.text.trim();
    return text.isEmpty ? null : text;
  } on MissingPluginException catch (e) {
    debugPrint('ReceiptOcrEngine: ML Kit plugin unavailable ($e)');
    return null;
  } on PlatformException catch (e) {
    debugPrint('ReceiptOcrEngine: platform OCR failure ($e)');
    return null;
  } catch (e) {
    debugPrint('ReceiptOcrEngine: unexpected OCR error ($e)');
    return null;
  } finally {
    await recognizer.close();
    if (tempFile != null) {
      try {
        if (tempFile.existsSync()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }
}
