import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../ai/data/services/buck_ai_service.dart';
import 'receipt_ocr_engine_stub.dart'
    if (dart.library.io) 'receipt_ocr_engine_io.dart'
    if (dart.library.js_interop) 'receipt_ocr_engine_web.dart' as ocr_engine;

/// Image quality metrics produced by [EdgeImageOps] during Stage 2 preprocessing.
class ImageQualityAssessment {
  final double meanLuminance;
  final double sharpnessVariance;
  final double foregroundRatio;
  final bool isLowQuality;
  final String? qualityWarning;

  const ImageQualityAssessment({
    required this.meanLuminance,
    required this.sharpnessVariance,
    required this.foregroundRatio,
    required this.isLowQuality,
    this.qualityWarning,
  });
}

/// On-device image preprocessing and quality gate (SDD 5.1 Stage 2 / SRS 3.1.2).
///
/// Computes grayscale luminance (`0.299R + 0.587G + 0.114B`), applies a `1.35x`
/// contrast boost, evaluates an `11x11` adaptive Gaussian threshold (`C = 2.0`),
/// and measures Laplacian variance for focus/blur detection.
class EdgeImageOps {
  static const String lowQualityMessage =
      'Image text unclear - please retake with flash or proceed manually';

  static const double contrastBoostFactor = 1.35;
  static const int adaptiveWindowRadius = 5; // 11x11 window (2*5 + 1)
  static const double adaptiveConstantC = 2.0;

  static final List<double> _gaussianKernel1D = _buildGaussianKernel(
    radius: adaptiveWindowRadius,
    sigma: 2.0,
  );

  static List<double> _buildGaussianKernel({
    required int radius,
    required double sigma,
  }) {
    final weights = <double>[];
    var sum = 0.0;
    for (var i = -radius; i <= radius; i++) {
      final w = math.exp(-(i * i) / (2.0 * sigma * sigma));
      weights.add(w);
      sum += w;
    }
    return weights.map((w) => w / sum).toList(growable: false);
  }

  /// Synchronously evaluates raw RGB/byte image data via grayscale conversion,
  /// `1.35x` contrast boost, `11x11` adaptive Gaussian thresholding (`C = 2.0`),
  /// and discrete Laplacian sharpness variance.
  static ImageQualityAssessment evaluateAndPreprocess(Uint8List rawBytes) {
    if (rawBytes.isEmpty) {
      return const ImageQualityAssessment(
        meanLuminance: 0,
        sharpnessVariance: 0,
        foregroundRatio: 0,
        isLowQuality: true,
        qualityWarning: lowQualityMessage,
      );
    }

    // Group raw bytes into RGB triplets when sufficient bytes are available,
    // or treat each byte as luminance for very tiny synthetic test payloads.
    final bool useRgbTriplets = rawBytes.length >= 27;
    final int pixelCount = useRgbTriplets ? rawBytes.length ~/ 3 : rawBytes.length;

    const maxSide = 64;
    final int gridSide = math.sqrt(pixelCount).floor().clamp(1, maxSide);
    final int sampledPixels = gridSide * gridSide;
    final luminance = Float64List(sampledPixels);

    for (var i = 0; i < sampledPixels; i++) {
      final srcPixelIndex = (i * pixelCount) ~/ sampledPixels;
      final double luma;
      if (useRgbTriplets) {
        final offset = srcPixelIndex * 3;
        final r = rawBytes[offset];
        final g = rawBytes[offset + 1];
        final b = rawBytes[offset + 2];
        luma = (0.299 * r + 0.587 * g + 0.114 * b).clamp(0.0, 255.0);
      } else {
        luma = rawBytes[srcPixelIndex].toDouble().clamp(0.0, 255.0);
      }
      luminance[i] = luma;
    }

    return _evaluateLuminanceGrid(luminance, width: gridSide, height: gridSide);
  }

  /// Evaluates a decoded RGBA pixel buffer (`width * height * 4` bytes).
  static ImageQualityAssessment evaluateRgbaPixels(
    Uint8List rgbaBytes, {
    required int width,
    required int height,
  }) {
    if (width <= 0 || height <= 0 || rgbaBytes.length < 4) {
      return const ImageQualityAssessment(
        meanLuminance: 0,
        sharpnessVariance: 0,
        foregroundRatio: 0,
        isLowQuality: true,
        qualityWarning: lowQualityMessage,
      );
    }

    final totalPixels = math.min(width * height, rgbaBytes.length ~/ 4);
    final gridW = math.min(width, 96);
    final gridH = math.min(height, 96);
    final luminance = Float64List(gridW * gridH);

    for (var gy = 0; gy < gridH; gy++) {
      final sy = (gy * height) ~/ gridH;
      for (var gx = 0; gx < gridW; gx++) {
        final sx = (gx * width) ~/ gridW;
        final idx = sy * width + sx;
        if (idx >= totalPixels) continue;
        final byteOffset = idx * 4;
        final r = rgbaBytes[byteOffset];
        final g = rgbaBytes[byteOffset + 1];
        final b = rgbaBytes[byteOffset + 2];
        luminance[gy * gridW + gx] =
            (0.299 * r + 0.587 * g + 0.114 * b).clamp(0.0, 255.0);
      }
    }

    return _evaluateLuminanceGrid(luminance, width: gridW, height: gridH);
  }

  /// Decodes encoded image bytes (JPEG/PNG) via `dart:ui` when possible so real
  /// camera photos get true pixel luminance/sharpness inspection, falling back
  /// cleanly to [evaluateAndPreprocess] for raw/synthetic test payloads.
  static Future<ImageQualityAssessment> evaluateImageBytes(
    Uint8List rawBytes,
  ) async {
    if (rawBytes.isEmpty) {
      return evaluateAndPreprocess(rawBytes);
    }
    try {
      final codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: 96,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        if (byteData != null) {
          return evaluateRgbaPixels(
            byteData.buffer.asUint8List(),
            width: image.width,
            height: image.height,
          );
        }
      } finally {
        image.dispose();
        codec.dispose();
      }
    } catch (_) {
      // Synthetic byte arrays or unsupported headers fall back cleanly.
    }
    return evaluateAndPreprocess(rawBytes);
  }

  static ImageQualityAssessment _evaluateLuminanceGrid(
    Float64List luminance, {
    required int width,
    required int height,
  }) {
    final total = width * height;
    if (total == 0) {
      return const ImageQualityAssessment(
        meanLuminance: 0,
        sharpnessVariance: 0,
        foregroundRatio: 0,
        isLowQuality: true,
        qualityWarning: lowQualityMessage,
      );
    }

    // 1. Mean luminance & 1.35x contrast boost around midpoint 128.0
    var lumaSum = 0.0;
    final boosted = Float64List(total);
    for (var i = 0; i < total; i++) {
      final l = luminance[i];
      lumaSum += l;
      boosted[i] = ((l - 128.0) * contrastBoostFactor + 128.0).clamp(0.0, 255.0);
    }
    final meanLuminance = lumaSum / total;

    // 2. Separable 11x11 Gaussian blur for adaptive thresholding
    final tempBlur = Float64List(total);
    for (var y = 0; y < height; y++) {
      final rowOffset = y * width;
      for (var x = 0; x < width; x++) {
        var acc = 0.0;
        var wSum = 0.0;
        for (var k = -adaptiveWindowRadius; k <= adaptiveWindowRadius; k++) {
          final sx = x + k;
          if (sx >= 0 && sx < width) {
            final w = _gaussianKernel1D[k + adaptiveWindowRadius];
            acc += boosted[rowOffset + sx] * w;
            wSum += w;
          }
        }
        tempBlur[rowOffset + x] = wSum > 0 ? acc / wSum : boosted[rowOffset + x];
      }
    }

    var foregroundCount = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var acc = 0.0;
        var wSum = 0.0;
        for (var k = -adaptiveWindowRadius; k <= adaptiveWindowRadius; k++) {
          final sy = y + k;
          if (sy >= 0 && sy < height) {
            final w = _gaussianKernel1D[k + adaptiveWindowRadius];
            acc += tempBlur[sy * width + x] * w;
            wSum += w;
          }
        }
        final localGaussianMean = wSum > 0 ? acc / wSum : boosted[y * width + x];
        final threshold = localGaussianMean - adaptiveConstantC;
        if (boosted[y * width + x] < threshold) {
          foregroundCount++;
        }
      }
    }
    final foregroundRatio = foregroundCount / total;

    // 3. Discrete 2D Laplacian operator for focus/sharpness variance
    final laplacianValues = <double>[];
    if (width >= 3 && height >= 3) {
      for (var y = 1; y < height - 1; y++) {
        for (var x = 1; x < width - 1; x++) {
          final idx = y * width + x;
          final response =
              (4.0 * luminance[idx]) -
              luminance[idx - 1] -
              luminance[idx + 1] -
              luminance[idx - width] -
              luminance[idx + width];
          laplacianValues.add(response);
        }
      }
    } else if (total >= 3) {
      for (var i = 1; i < total - 1; i++) {
        final response =
            (2.0 * luminance[i]) - luminance[i - 1] - luminance[i + 1];
        laplacianValues.add(response);
      }
    }

    var sharpnessVariance = 0.0;
    if (laplacianValues.isNotEmpty) {
      var lapMean = 0.0;
      for (final v in laplacianValues) {
        lapMean += v;
      }
      lapMean /= laplacianValues.length;

      var sqDiffSum = 0.0;
      for (final v in laplacianValues) {
        final d = v - lapMean;
        sqDiffSum += d * d;
      }
      sharpnessVariance = sqDiffSum / laplacianValues.length;
    }

    final tooDark = meanLuminance < 38.0;
    final tooBlurry = sharpnessVariance < 18.0;
    final overexposed = meanLuminance > 246.0;
    final isLowQuality = tooDark || tooBlurry || overexposed;

    return ImageQualityAssessment(
      meanLuminance: double.parse(meanLuminance.toStringAsFixed(2)),
      sharpnessVariance: double.parse(sharpnessVariance.toStringAsFixed(2)),
      foregroundRatio: double.parse(foregroundRatio.toStringAsFixed(4)),
      isLowQuality: isLowQuality,
      qualityWarning: isLowQuality ? lowQualityMessage : null,
    );
  }
}

/// Structured fields parsed from raw receipt OCR text (SDD 5.1 Stage 4).
class ParsedReceiptData {
  final String merchantName;
  final double totalAmount;
  final double? subtotalAmount;
  final double evatAmount;
  final double vatableSales;
  final DateTime date;
  final String categoryName;
  final String rawText;
  final bool evatWasExplicit;

  const ParsedReceiptData({
    required this.merchantName,
    required this.totalAmount,
    this.subtotalAmount,
    required this.evatAmount,
    required this.vatableSales,
    required this.date,
    required this.categoryName,
    required this.rawText,
    required this.evatWasExplicit,
  });
}

/// Output of the end-to-end [ReceiptOcrProcessor.processReceipt] pipeline.
class ReceiptPipelineOutput {
  final ParsedReceiptData parsed;
  final ImageQualityAssessment? quality;
  final int processingTimeMs;
  final bool usedNativeOcr;

  const ReceiptPipelineOutput({
    required this.parsed,
    this.quality,
    required this.processingTimeMs,
    required this.usedNativeOcr,
  });
}

/// On-device Philippine retail receipt parser & OCR coordinator (`MOD-01-OCR`).
class ReceiptOcrProcessor {
  static final RegExp _phMobileRegex = RegExp(r'(\+?63|0)9\d{9}\b');
  static final RegExp _emailRegex = RegExp(
    r'[\w\.\-+]+@[\w\.\-]+\.[A-Za-z]{2,}',
  );

  static final RegExp _explicitEvatRegex = RegExp(
    r'(?:12%\s*V[A4]T|E-?V[A4]T|V[A4]T\s*AM[O0]UNT|V[A4]T\s*AMT|V[A4]T\s*\(12%\)|ADD:\s*12%\s*V[A4]T|LESS:\s*12%\s*V[A4]T|V[A4]T\s*12%)\s*[:=\s₱PpHh]*([0-9Oo]{1,3}(?:,[0-9Oo]{3})*[.,][0-9Oo]{2}|[0-9Oo]+[.,][0-9Oo]{2})',
    caseSensitive: false,
  );

  static final RegExp _currencyRegex = RegExp(
    r'(?:₱|PHP|Php|P\s*)?([0-9Oo]{1,3}(?:,[0-9Oo]{3})*(?:\s*[.,]\s*[0-9Oo]{2})|[0-9Oo]+(?:\s*[.,]\s*[0-9Oo]{2}))(?:\s*[VvAa*])?',
  );

  static final RegExp _totalKeywordRegex = RegExp(
    r'\b(?:GRAND\s*T[O0]T[A4][LI]|T[O0]T[A4][LI]\s*AM[O0]UNT\s*DUE|NET\s*AM[O0]UNT\s*DUE|AM[O0]UNT\s*DUE|T[O0]T[A4][LI]\s*DUE|NET\s*DUE|BALANCE\s*DUE|AM[O0]UNT\s*PAYABLE|T[O0]T[A4][LI]\s*PAYABLE|NET\s*T[O0]T[A4][LI]|T[O0]T[A4][LI]\s*SALES|T[O0]T[A4][LI]\s*AMT|T[O0]T[A4][LI]\s*(?:PHP|P)?|INVOICE\s*T[O0]T[A4][LI]|ORDER\s*T[O0]T[A4][LI])\b',
    caseSensitive: false,
  );

  static final RegExp _highPriorityTotalRegex = RegExp(
    r'\b(?:GRAND\s*T[O0]T[A4][LI]|T[O0]T[A4][LI]\s*AM[O0]UNT\s*DUE|NET\s*AM[O0]UNT\s*DUE|AM[O0]UNT\s*DUE|T[O0]T[A4][LI]\s*DUE|NET\s*T[O0]T[A4][LI]|AM[O0]UNT\s*PAYABLE|T[O0]T[A4][LI]\s*PAYABLE)\b',
    caseSensitive: false,
  );

  static final RegExp _tenderKeywordRegex = RegExp(
    r'\b(?:GCASH|MAYA|PAYMAYA|VISA|MASTERCARD|AMEX|CREDIT\s*CARD|DEBIT\s*CARD|CARD\s*PAYMENT|E-?WALLET|QRPH|QR\s*PH|AMOUNT\s*PAID|PAID)\b',
    caseSensitive: false,
  );

  static final RegExp _excludedTotalLineRegex = RegExp(
    r'\b(?:SUB[\s-]*T[O0]T[A4][LI]|V[A4]TABLE|VAT[\s-]*EXEMPT|ZERO[\s-]*RATED|V[A4]T\s*AM[O0]UNT|V[A4]T\s*AMT|12%\s*V[A4]T|E-?V[A4]T|LESS[\s:]*V[A4]T|DISCOUNT|SC[\s/]*PWD|SENIOR|PWD|SAVINGS|CASH|TENDERED|CHANGE|SUKLI|SERVICE\s*CHARGE|NO\.?\s*OF\s*ITEMS?|T[O0]T[A4][LI]\s*ITEMS?|T[O0]T[A4][LI]\s*QTY|ITEMS?|QTY|POINTS|REWARD)\b',
    caseSensitive: false,
  );

  static final RegExp _subtotalKeywordRegex = RegExp(
    r'\b(?:SUB[\s-]*T[O0]T[A4][LI]|V[A4]TABLE\s*SALES?|V[A4]T[\s-]*ABLE|V[A4]T\s*SALES|TAXABLE\s*(?:AMOUNT|SALES)?)\b',
    caseSensitive: false,
  );

  static final RegExp _boilerplateHeaderRegex = RegExp(
    r'^(?:[\W_\d\s]+$|OFFICIAL\s*RECEIPT|SALES\s*INVOICE|COLLECTION\s*RECEIPT|ACKNOWLEDGEMENT|PROVISIONAL|POS\s*RECEIPT|CUSTOMER\s*COPY|MERCHANT\s*COPY|REPRINT|VAT\s*REG|NON[\s-]*VAT|OPERATED\s*BY|OWNED\s*(?:&|AND)\s*OPERATED|MANAGED\s*BY|TIN[\s:#]|MIN[\s:#]|S/?N[\s:#]|SERIAL[\s:#]|PTU[\s:#]|ACCR|BIR\s*PERMIT|PERMIT[\s:#]|OR\s*#|SI\s*#|INV\s*#|TXN[\s:#]|TRANS[\s:#]|RECEIPT\s*NO|STORE\s*#|POS\s*\d|TERMINAL|CASHIER|SERVER|CREW|DATE\s*ISSUED|VALID\s*UNTIL|DATE|TIME|TEL|TELEPHONE|FAX|MOBILE|EMAIL|WWW\.|HTTP|BRGY\.|BARANGAY|STREET|ST\.|AVE\.|BLDG\.|FLOOR|MALL|MAKATI\s*CITY|MANILA|QUEZON\s*CITY|TAGUIG|CEBU|DAVAO|PHILIPPINES|WELCOME|THANK\s*YOU|THIS\s*SERVES)',
    caseSensitive: false,
  );

  static final RegExp _birFooterDateRegex = RegExp(
    r'\b(?:DATE\s*ISSUED|ISSUED\s*DATE|VALID\s*UNTIL|ACCR(?:EDITATION)?|PTU|PERMIT\s*NO)\b',
    caseSensitive: false,
  );

  static const Map<String, String> _knownPhMerchants = {
    'fresh mart': 'Shopping',
    'jollibee': 'Food',
    'mcdonald': 'Food',
    'starbucks': 'Food',
    'chowking': 'Food',
    'mang inasal': 'Food',
    'greenwich': 'Food',
    'red ribbon': 'Food',
    'goldilocks': 'Food',
    'kfc': 'Food',
    'burger king': 'Food',
    'pizza hut': 'Food',
    'shakey': 'Food',
    'yellow cab': 'Food',
    'army navy': 'Food',
    'max\'s': 'Food',
    'maxs restaurant': 'Food',
    'andok': 'Food',
    'baliwag': 'Food',
    'botejyu': 'Food',
    'dunkin': 'Food',
    'krispy kreme': 'Food',
    'tim hortons': 'Food',
    'pickup coffee': 'Food',
    'zus coffee': 'Food',
    'gong cha': 'Food',
    'coco fresh': 'Food',
    'potato corner': 'Food',
    'pan de manila': 'Food',
    'sm supermarket': 'Food',
    'sm hypermarket': 'Food',
    'savemore': 'Food',
    'puregold': 'Food',
    'robinsons supermarket': 'Food',
    'waltermart': 'Food',
    'metro supermarket': 'Food',
    'shopwise': 'Food',
    'rustan': 'Food',
    '7-eleven': 'Food',
    '7 eleven': 'Food',
    'uncle john': 'Food',
    'ministop': 'Food',
    'alfamart': 'Food',
    'lawson': 'Food',
    'familymart': 'Food',
    'allday': 'Food',
    'grabfood': 'Food',
    'foodpanda': 'Food',
    's&r': 'Shopping',
    'landers': 'Shopping',
    'sm store': 'Shopping',
    'sm department': 'Shopping',
    'sm retail': 'Shopping',
    'robinsons': 'Shopping',
    'uniqlo': 'Shopping',
    'lazada': 'Shopping',
    'shopee': 'Shopping',
    'ace hardware': 'Shopping',
    'handyman': 'Shopping',
    'true value': 'Shopping',
    'power mac': 'Shopping',
    'datablitz': 'Shopping',
    'mercury drug': 'Health & Wellness',
    'watsons': 'Health & Wellness',
    'southstar drug': 'Health & Wellness',
    'the generics pharmacy': 'Health & Wellness',
    'tgp': 'Health & Wellness',
    'rose pharmacy': 'Health & Wellness',
    'shell': 'Transportation',
    'petron': 'Transportation',
    'caltex': 'Transportation',
    'seaoil': 'Transportation',
    'unioil': 'Transportation',
    'cleanfuel': 'Transportation',
    'grab': 'Transportation',
    'angkas': 'Transportation',
    'joyride': 'Transportation',
    'cebu pacific': 'Transportation',
    'philippine airlines': 'Transportation',
    'meralco': 'Bills & Utilities',
    'maynilad': 'Bills & Utilities',
    'manila water': 'Bills & Utilities',
    'pldt': 'Bills & Utilities',
    'globe': 'Bills & Utilities',
    'smart': 'Bills & Utilities',
    'converge': 'Bills & Utilities',
    'national book store': 'Education',
    'fully booked': 'Education',
  };

  static const Map<String, int> _monthLookup = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'sept': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  /// Scrubs Philippine mobile numbers (`+639...` / `09...`) and email
  /// addresses before text leaves device memory (SRS 3.5.1 / SDD 5.2).
  static String sanitizePii(String input) {
    return input
        .replaceAll(_phMobileRegex, '[REDACTED_PHONE]')
        .replaceAll(_emailRegex, '[REDACTED_EMAIL]');
  }

  /// Parses raw OCR text into structured Philippine retail receipt entities.
  static ParsedReceiptData parseReceiptText(
    String rawText, {
    DateTime? fallbackDate,
  }) {
    final sanitizedText = sanitizePii(rawText);
    final lines = sanitizedText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final merchant = _extractMerchant(lines);
    final date = _extractDate(lines, fallbackDate: fallbackDate);
    final subtotalAmount = _extractSubtotalAmount(lines);
    final totalAmount = _extractTotalAmount(
      lines,
      subtotalAmount: subtotalAmount,
    );

    double? explicitEvat;
    final explicitMatch = _explicitEvatRegex.firstMatch(sanitizedText);
    if (explicitMatch != null) {
      explicitEvat = _parseCurrencyToken(explicitMatch.group(1)!);
    } else {
      explicitEvat = _extractEvatFromNeighborLines(lines);
    }

    final bool hasValidExplicitEvat = explicitEvat != null &&
        explicitEvat > 0 &&
        (totalAmount <= 0 || explicitEvat < totalAmount);

    final double evatAmount;
    final double vatableSales;
    if (hasValidExplicitEvat) {
      evatAmount = double.parse(explicitEvat.toStringAsFixed(2));
      if (subtotalAmount != null &&
          subtotalAmount > 0 &&
          (subtotalAmount + evatAmount - totalAmount).abs() <= 0.10) {
        vatableSales = double.parse(subtotalAmount.toStringAsFixed(2));
      } else {
        vatableSales = double.parse((totalAmount - evatAmount).toStringAsFixed(2));
      }
    } else if (totalAmount > 0) {
      vatableSales = double.parse((totalAmount / 1.12).toStringAsFixed(2));
      evatAmount = double.parse((totalAmount - vatableSales).toStringAsFixed(2));
    } else {
      vatableSales = 0.0;
      evatAmount = 0.0;
    }

    final categoryName = _inferCategory(
      merchantName: merchant,
      fullText: sanitizedText,
    );

    return ParsedReceiptData(
      merchantName: merchant,
      totalAmount: totalAmount,
      subtotalAmount: subtotalAmount,
      evatAmount: evatAmount,
      vatableSales: vatableSales,
      date: date,
      categoryName: categoryName,
      rawText: sanitizedText,
      evatWasExplicit: hasValidExplicitEvat,
    );
  }

  /// Pre-warms the OCR engine (on Web, preloads Tesseract.js before capture).
  static void warmup() => ocr_engine.warmupNativeOcr();

  /// Executes the full on-device OCR pipeline (preprocessing, ML Kit text
  /// extraction on mobile, fallback synthesis for web/desktop/test, and heuristic parsing).
  static Future<ReceiptPipelineOutput> processReceipt({
    String? imagePath,
    Uint8List? imageBytes,
    String? sourceName,
    bool allowSampleFallback = false,
  }) async {
    final stopwatch = Stopwatch()..start();

    ImageQualityAssessment? quality;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      quality = await EdgeImageOps.evaluateImageBytes(imageBytes);
    }

    final nativeText = await ocr_engine.extractNativeOcrText(
      imagePath: imagePath,
      imageBytes: imageBytes,
    );

    final bool usedNative = nativeText != null && nativeText.trim().isNotEmpty;
    final bool hasImageBytes = imageBytes != null && imageBytes.isNotEmpty;

    if (!usedNative && (hasImageBytes || !allowSampleFallback)) {
      stopwatch.stop();
      final cleanLabel = _cleanSourceLabel(sourceName);
      return ReceiptPipelineOutput(
        parsed: ParsedReceiptData(
          merchantName: cleanLabel ?? 'Unreadable receipt',
          totalAmount: 0,
          subtotalAmount: null,
          evatAmount: 0,
          vatableSales: 0,
          date: DateTime.now(),
          categoryName: 'Other',
          rawText: '',
          evatWasExplicit: false,
        ),
        quality: ImageQualityAssessment(
          meanLuminance: quality?.meanLuminance ?? 0,
          sharpnessVariance: quality?.sharpnessVariance ?? 0,
          foregroundRatio: quality?.foregroundRatio ?? 0,
          isLowQuality: true,
          qualityWarning: hasImageBytes
              ? 'Could not read receipt text clearly — retake with flash or enter details manually.'
              : 'No receipt image captured — retake photo or pick from gallery.',
        ),
        processingTimeMs: stopwatch.elapsedMilliseconds,
        usedNativeOcr: false,
      );
    }

    final String effectiveText = usedNative
        ? nativeText
        : _buildFallbackReceiptText(sourceName: sourceName);

    final parsed = parseReceiptText(
      effectiveText,
      fallbackDate: DateTime.now(),
    );

    stopwatch.stop();
    return ReceiptPipelineOutput(
      parsed: parsed,
      quality: quality,
      processingTimeMs: stopwatch.elapsedMilliseconds,
      usedNativeOcr: usedNative,
    );
  }

  static String? _cleanSourceLabel(String? sourceName) {
    if (sourceName == null || sourceName.trim().isEmpty) return null;
    final cleanName = sanitizePii(
      sourceName
          .replaceAll(RegExp(r'\.[A-Za-z0-9]{2,5}$'), '')
          .replaceAll(RegExp(r'[_]+'), ' ')
          .trim(),
    );
    if (cleanName.isEmpty) return null;
    // Generic camera/gallery filenames (e.g. image_picker_1234, IMG_001) add noise.
    if (RegExp(
      r'^(?:image|img|photo|pxl|dsc|scaled|cap)[\s\-0-9]*$',
      caseSensitive: false,
    ).hasMatch(cleanName)) {
      return null;
    }
    return cleanName;
  }

  static String _buildFallbackReceiptText({String? sourceName}) {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    if (sourceName != null && sourceName.trim().isNotEmpty) {
      final cleanName = sanitizePii(
        sourceName
            .replaceAll(RegExp(r'\.[A-Za-z0-9]{2,5}$'), '')
            .replaceAll(RegExp(r'[_]+'), ' ')
            .trim(),
      );
      final header = cleanName.isNotEmpty
          ? 'Scanned Receipt ($cleanName)'
          : 'Fresh Mart - Makati (#098765)';
      return '''
$header
VAT REG TIN: 000-123-456-000
DATE: $dateStr
SUBTOTAL 752.23
12% VAT 90.27
TOTAL AMOUNT DUE 842.50
''';
    }

    return '''
Fresh Mart - Makati (#098765)
VAT REG TIN: 000-123-456-000
DATE: $dateStr
SUBTOTAL 752.23
12% VAT 90.27
TOTAL AMOUNT DUE 842.50
''';
  }

  static String _extractMerchant(List<String> lines) {
    if (lines.isEmpty) return 'Scanned Receipt';

    // First look for known Philippine retail merchants near the top
    final searchLimit = math.min(lines.length, 12);
    for (var i = 0; i < searchLimit; i++) {
      final line = lines[i];
      if (_boilerplateHeaderRegex.hasMatch(line)) continue;
      final lower = line.toLowerCase();
      for (final keyword in _knownPhMerchants.keys) {
        if (lower.contains(keyword)) {
          return _formatMerchantDisplay(line);
        }
      }
    }

    // Also allow known merchants anywhere if header was noisy/truncated
    for (final line in lines) {
      if (_boilerplateHeaderRegex.hasMatch(line)) continue;
      final lower = line.toLowerCase();
      for (final keyword in _knownPhMerchants.keys) {
        if (lower.contains(keyword)) {
          return _formatMerchantDisplay(line);
        }
      }
    }

    // Otherwise select the first informative non-boilerplate text header
    for (final line in lines) {
      if (line.length < 3) continue;
      if (_boilerplateHeaderRegex.hasMatch(line)) continue;
      if (!RegExp(r'[A-Za-z]{2,}').hasMatch(line)) continue;
      // Skip lines that are purely a date, price, or summary keyword
      if (_totalKeywordRegex.hasMatch(line) ||
          _subtotalKeywordRegex.hasMatch(line) ||
          _excludedTotalLineRegex.hasMatch(line) ||
          _currencyRegex.hasMatch(line)) {
        continue;
      }
      return _formatMerchantDisplay(line);
    }

    return 'Scanned Receipt';
  }

  static String _formatMerchantDisplay(String line) {
    final cleaned = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    final hasLowercase = RegExp(r'[a-z]').hasMatch(cleaned);
    if (hasLowercase) return cleaned;

    // Convert shouting ALL-CAPS thermal receipt headers into readable Title Case
    const preserveUpper = {
      'SM',
      'BDO',
      'BPI',
      'BGC',
      'KFC',
      'LBC',
      'S&R',
      'TGP',
      'PLDT',
      'PH',
    };
    return cleaned
        .split(' ')
        .map((word) {
          if (preserveUpper.contains(word.toUpperCase())) {
            return word.toUpperCase();
          }
          if (word.length <= 1 || !RegExp(r'[A-Z]{2,}').hasMatch(word)) {
            return word;
          }
          return word.replaceAllMapped(RegExp(r'[A-Za-z]+'), (m) {
            final seg = m.group(0)!;
            if (seg.length == 1) return seg.toUpperCase();
            return seg[0].toUpperCase() + seg.substring(1).toLowerCase();
          });
        })
        .join(' ');
  }

  static DateTime _extractDate(
    List<String> lines, {
    DateTime? fallbackDate,
  }) {
    final now = fallbackDate ?? DateTime.now();

    final isoRegex = RegExp(
      r'\b(20\d{2})[-/](0?[1-9]|1[0-2])[-/](0?[1-9]|[12]\d|3[01])\b',
    );
    final monthFirstAlpha = RegExp(
      r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\.?\s+(\d{1,2}),?\s+(20\d{2})\b',
      caseSensitive: false,
    );
    final dayFirstAlpha = RegExp(
      r'\b(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\.?,?\s+(20\d{2})\b',
      caseSensitive: false,
    );
    final numericSlash = RegExp(
      r'\b(\d{1,2})[-/](\d{1,2})[-/]((?:20)?\d{2})\b',
    );

    // Exclude BIR permit/accreditation footer lines ("Date Issued", "Valid Until")
    // from date priority so transaction dates always win over POS permit dates.
    final txDateLines = lines.where((l) => !_birFooterDateRegex.hasMatch(l)).toList();
    final footerDateLines = lines.where(_birFooterDateRegex.hasMatch).toList();
    final prioritized = [
      ...txDateLines.where((l) => l.toUpperCase().contains('DATE')),
      ...txDateLines.where((l) => !l.toUpperCase().contains('DATE')),
      ...footerDateLines,
    ];

    for (final line in prioritized) {
      final iso = isoRegex.firstMatch(line);
      if (iso != null) {
        final dt = _safeDate(
          int.parse(iso.group(1)!),
          int.parse(iso.group(2)!),
          int.parse(iso.group(3)!),
          now,
        );
        if (dt != null) return dt;
      }

      final alphaM = monthFirstAlpha.firstMatch(line);
      if (alphaM != null) {
        final monKey = alphaM.group(1)!.toLowerCase().substring(0, 3);
        final month = _monthLookup[monKey];
        if (month != null) {
          final dt = _safeDate(
            int.parse(alphaM.group(3)!),
            month,
            int.parse(alphaM.group(2)!),
            now,
          );
          if (dt != null) return dt;
        }
      }

      final alphaD = dayFirstAlpha.firstMatch(line);
      if (alphaD != null) {
        final monKey = alphaD.group(2)!.toLowerCase().substring(0, 3);
        final month = _monthLookup[monKey];
        if (month != null) {
          final dt = _safeDate(
            int.parse(alphaD.group(3)!),
            month,
            int.parse(alphaD.group(1)!),
            now,
          );
          if (dt != null) return dt;
        }
      }

      final numM = numericSlash.firstMatch(line);
      if (numM != null) {
        final a = int.parse(numM.group(1)!);
        final b = int.parse(numM.group(2)!);
        var year = int.parse(numM.group(3)!);
        if (year < 100) year += 2000;

        int month;
        int day;
        if (a > 12 && b <= 12) {
          day = a;
          month = b;
        } else if (b > 12 && a <= 12) {
          month = a;
          day = b;
        } else {
          month = a;
          day = b;
        }

        final dt = _safeDate(year, month, day, now);
        if (dt != null) return dt;
      }
    }

    return now;
  }

  static DateTime? _safeDate(
    int year,
    int month,
    int day,
    DateTime maxDate,
  ) {
    if (year < 2000 || year > maxDate.year + 1) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    final candidate = DateTime(year, month, day);
    if (candidate.month != month || candidate.day != day) return null;
    return candidate.isAfter(maxDate) ? maxDate : candidate;
  }

  static double _extractTotalAmount(
    List<String> lines, {
    double? subtotalAmount,
  }) {
    double? highPriorityTotal;
    double? generalTotal;
    double? tenderTotal;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isHighPriority = _highPriorityTotalRegex.hasMatch(line);
      if (_excludedTotalLineRegex.hasMatch(line) && !isHighPriority) {
        continue;
      }

      if (_totalKeywordRegex.hasMatch(line)) {
        double? found = _lastCurrencyOnLine(line);
        if (found == null || found <= 0) {
          for (var lookahead = 1;
              lookahead <= 2 && i + lookahead < lines.length;
              lookahead++) {
            final nextLine = lines[i + lookahead];
            if (_excludedTotalLineRegex.hasMatch(nextLine) ||
                _totalKeywordRegex.hasMatch(nextLine)) {
              break;
            }
            final candidate = _lastCurrencyOnLine(nextLine);
            if (candidate != null && candidate > 0) {
              found = candidate;
              break;
            }
          }
        }
        if (found != null && found > 0) {
          if (isHighPriority) {
            highPriorityTotal = found;
          } else {
            generalTotal = found;
          }
        }
      } else if (_tenderKeywordRegex.hasMatch(line)) {
        final paid = _lastCurrencyOnLine(line);
        if (paid != null && paid > 0) {
          tenderTotal = paid;
        }
      }
    }

    // Prefer explicit Grand Total / Amount Due; if general TOTAL disagrees strongly
    // with subtotal while tender agrees, trust the higher consistent match.
    var chosen = highPriorityTotal ?? generalTotal ?? tenderTotal;
    if (highPriorityTotal == null &&
        generalTotal != null &&
        subtotalAmount != null &&
        generalTotal < subtotalAmount &&
        tenderTotal != null &&
        tenderTotal >= subtotalAmount) {
      chosen = tenderTotal;
    }

    if (chosen != null && chosen > 0) {
      return double.parse(chosen.toStringAsFixed(2));
    }

    // Fallback: pick largest monetary decimal amount excluding change/cash lines
    var maxAmount = 0.0;
    for (final line in lines) {
      if (RegExp(r'\b(?:CASH|CHANGE|SUKLI|TENDERED|SAVED|DISCOUNT)\b',
              caseSensitive: false)
          .hasMatch(line)) {
        continue;
      }
      for (final m in _currencyRegex.allMatches(line)) {
        final val = _parseCurrencyToken(m.group(1)!);
        if (val != null && val > maxAmount) {
          maxAmount = val;
        }
      }
    }

    return double.parse(maxAmount.toStringAsFixed(2));
  }

  static double? _extractSubtotalAmount(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_subtotalKeywordRegex.hasMatch(line)) {
        final amount = _lastCurrencyOnLine(line);
        if (amount != null && amount > 0) {
          return double.parse(amount.toStringAsFixed(2));
        }
        if (i + 1 < lines.length) {
          final nextAmount = _lastCurrencyOnLine(lines[i + 1]);
          if (nextAmount != null && nextAmount > 0) {
            return double.parse(nextAmount.toStringAsFixed(2));
          }
        }
      }
    }
    return null;
  }

  static double? _extractEvatFromNeighborLines(List<String> lines) {
    final vatLabelOnly = RegExp(
      r'^(?:12%\s*V[A4]T|E-?V[A4]T|V[A4]T\s*AM[O0]UNT|V[A4]T\s*AMT|V[A4]T\s*\(12%\)|ADD:\s*12%\s*V[A4]T|LESS:\s*12%\s*V[A4]T|V[A4]T\s*12%)\s*:?$',
      caseSensitive: false,
    );
    for (var i = 0; i < lines.length - 1; i++) {
      if (vatLabelOnly.hasMatch(lines[i])) {
        final candidate = _lastCurrencyOnLine(lines[i + 1]);
        if (candidate != null && candidate > 0) {
          return candidate;
        }
      }
    }
    return null;
  }

  static double? _lastCurrencyOnLine(String line) {
    final matches = _currencyRegex.allMatches(line).toList();
    if (matches.isEmpty) return null;
    return _parseCurrencyToken(matches.last.group(1)!);
  }

  static double? _parseCurrencyToken(String raw) {
    var normalized = raw
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('O', '0')
        .replaceAll('o', '0')
        .trim();
    // Handle European / noisy OCR decimal comma when followed by exactly 2 cents digits.
    if (RegExp(r'^[0-9]+,[0-9]{2}$').hasMatch(normalized)) {
      normalized = normalized.replaceFirst(',', '.');
    } else {
      normalized = normalized.replaceAll(',', '');
    }
    return double.tryParse(normalized);
  }

  static String _inferCategory({
    required String merchantName,
    required String fullText,
  }) {
    final lowerMerchant = merchantName.toLowerCase();
    for (final entry in _knownPhMerchants.entries) {
      if (lowerMerchant.contains(entry.key)) {
        return entry.value;
      }
    }
    final mappedFromMerchant = BuckAiService.mapToMobileCategory(
      '',
      fallbackDescription: merchantName,
    );
    if (mappedFromMerchant != 'Other') {
      return mappedFromMerchant;
    }

    final mappedFromBody = BuckAiService.mapToMobileCategory(
      '',
      fallbackDescription: fullText,
    );
    return mappedFromBody;
  }
}
