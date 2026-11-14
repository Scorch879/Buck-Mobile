import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device ML Vision OCR engine using Google ML Kit Text Recognition v2.
///
/// Runs offline on Android and iOS without transmitting receipt images over
/// the network (SRS 3.5.1 / SDD 5.1 Stage 3). Returns `null` on desktop/test
/// environments or if the native plugin channel is unavailable.
Future<String?> extractNativeOcrText({
  String? imagePath,
  Uint8List? imageBytes,
}) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return null;
  }

  if (imagePath == null || imagePath.isEmpty) {
    return null;
  }

  final file = File(imagePath);
  if (!file.existsSync()) {
    return null;
  }

  final inputImage = InputImage.fromFilePath(imagePath);
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
  }
}
