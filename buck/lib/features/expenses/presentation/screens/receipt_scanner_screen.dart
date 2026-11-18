import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_layout.dart';
import '../../data/receipt_ocr_processor.dart';

/// Data returned when a receipt is captured or selected in [ReceiptScannerScreen].
class ScannedReceiptResult {
  final double amount;
  final String categoryName;
  final String description;
  final DateTime date;
  final Uint8List? imageBytes;
  final bool isFromLiveCamera;
  final double evatAmount;
  final double vatableSales;
  final double? subtotalAmount;
  final String? rawText;
  final int? processingTimeMs;
  final String? qualityWarning;
  final bool isLowQuality;
  final bool manualEntryRequested;

  ScannedReceiptResult({
    required this.amount,
    required this.categoryName,
    required this.description,
    required this.date,
    this.imageBytes,
    this.isFromLiveCamera = false,
    double? evatAmount,
    double? vatableSales,
    this.subtotalAmount,
    this.rawText,
    this.processingTimeMs,
    this.qualityWarning,
    this.isLowQuality = false,
    this.manualEntryRequested = false,
  })  : vatableSales = vatableSales ??
            double.parse((amount / 1.12).toStringAsFixed(2)),
        evatAmount = evatAmount ??
            double.parse(
              (amount - double.parse((amount / 1.12).toStringAsFixed(2)))
                  .toStringAsFixed(2),
            );

  /// Returned when the user explicitly opts out of camera scanning for manual entry.
  factory ScannedReceiptResult.manualEntry() {
    return ScannedReceiptResult(
      amount: 0,
      categoryName: 'Other',
      description: '',
      date: DateTime.now(),
      evatAmount: 0,
      vatableSales: 0,
      manualEntryRequested: true,
    );
  }
}

/// Pushes the Figma "Screen / Receipt scanner — Buck" (2480:672) full-screen modal.
Future<ScannedReceiptResult?> showReceiptScanner(
  BuildContext context, {
  bool enableLiveCamera = true,
}) {
  return Navigator.of(context).push<ScannedReceiptResult>(
    PageRouteBuilder(
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ReceiptScannerScreen(enableLiveCamera: enableLiveCamera);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Figma "Screen / Receipt scanner — Buck" (node 2480:672).
///
/// Uses the device camera on mobile (Android/iOS) and web/development
/// (`camera` + `camera_web`), with a clean native camera viewfinder state when
/// initializing or when camera hardware/permissions are unavailable.
class ReceiptScannerScreen extends StatefulWidget {
  /// Whether to attempt initializing the hardware/browser camera.
  /// Can be set to false in widget tests.
  final bool enableLiveCamera;

  /// Test-only hook so widget tests without camera hardware can verify the
  /// capture-to-expense flow; production code always requires real camera bytes.
  @visibleForTesting
  static bool allowSampleFallbackForTesting = false;

  const ReceiptScannerScreen({
    super.key,
    this.enableLiveCamera = true,
  });

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen>
    with WidgetsBindingObserver {
  // Figma palette for node 2480:672
  static const _bgDark = Color(0xFF100B09);
  static const _surfaceButton = Color(0xFF1D110C);
  static const _previewBg = Color(0xFF2A1914);
  static const _strokeBrown = Color(0xFF68402B);
  static const _creamText = Color(0xFFFFF7EE);
  static const _mutedText = Color(0xFFC6B5AB);
  static const _accentOrange = Color(0xFFFF994A);
  static const _shutterCoral = Color(0xFFFF8E5D);

  CameraController? _cameraController;
  List<CameraDescription> _cameras = const [];
  bool _cameraInitialized = false;
  bool _initializingCamera = false;
  int _cameraEpoch = 0;
  bool _disposed = false;
  bool _flashOn = false;
  bool _capturing = false;
  Uint8List? _capturedBytes;
  String _statusMessage = 'Keep it flat. Hold steady.';
  Offset? _focusPoint;
  Timer? _focusTimer;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    AppLayout.pushDarkBarSurface();
    WidgetsBinding.instance.addObserver(this);
    if (widget.enableLiveCamera) {
      ReceiptOcrProcessor.warmup();
      _initCamera();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    AppLayout.popDarkBarSurface();
    _focusTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera(notify: false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_cameraController != null || _initializingCamera) {
        _disposeCamera();
      }
    } else if (state == AppLifecycleState.resumed && widget.enableLiveCamera) {
      if (_cameraController == null && !_initializingCamera) {
        _initCamera();
      }
    }
  }

  Future<void> _disposeCamera({bool notify = true}) async {
    _cameraEpoch++;
    final controller = _cameraController;
    _cameraController = null;
    if (notify && !_disposed && mounted) {
      setState(() {
        _cameraInitialized = false;
        _initializingCamera = false;
      });
    } else {
      _cameraInitialized = false;
      _initializingCamera = false;
    }
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (e) {
        debugPrint('Camera dispose error: $e');
      }
    }
  }

  Future<void> _initCamera() async {
    if (_initializingCamera || _disposed) return;
    final epoch = ++_cameraEpoch;
    setState(() {
      _initializingCamera = true;
    });

    try {
      final cameras = await availableCameras();
      if (_disposed || !mounted || epoch != _cameraEpoch) return;
      _cameras = cameras;
      if (_cameras.isEmpty) {
        setState(() {
          _cameraInitialized = false;
          _initializingCamera = false;
        });
        return;
      }

      // Prefer the primary rear camera on mobile and web Safari; fallback to first available
      final selectedCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.firstWhere(
          (c) {
            final name = c.name.toLowerCase();
            return name.contains('back') ||
                name.contains('rear') ||
                name.contains('environment');
          },
          orElse: () => _cameras.first,
        ),
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      if (_disposed || !mounted || epoch != _cameraEpoch) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraInitialized = true;
        _initializingCamera = false;
        _statusMessage = 'Good Lighting — Keep flat & steady.';
      });
    } catch (e) {
      debugPrint('Camera initialization unavailable: $e');
      if (!_disposed && mounted && epoch == _cameraEpoch) {
        setState(() {
          _cameraInitialized = false;
          _initializingCamera = false;
          _statusMessage = 'Keep it flat. Hold steady.';
        });
      }
    }
  }

  Future<void> _toggleFlash() async {
    final nextFlash = !_flashOn;
    setState(() => _flashOn = nextFlash);

    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.setFlashMode(
          nextFlash ? FlashMode.torch : FlashMode.off,
        );
      } catch (e) {
        debugPrint('Flash toggle unsupported: $e');
      }
    }
  }

  Future<void> _switchOrRetryCamera() async {
    if (_cameras.length > 1 && _cameraController != null) {
      final currentDesc = _cameraController!.description;
      final nextIndex = (_cameras.indexOf(currentDesc) + 1) % _cameras.length;
      final nextCamera = _cameras[nextIndex];
      await _disposeCamera();
      if (_disposed || !mounted) return;
      final epoch = ++_cameraEpoch;
      setState(() => _initializingCamera = true);
      try {
        final controller = CameraController(
          nextCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await controller.initialize();
        if (_disposed || !mounted || epoch != _cameraEpoch) {
          await controller.dispose();
          return;
        }
        setState(() {
          _cameraController = controller;
          _cameraInitialized = true;
          _initializingCamera = false;
        });
      } catch (e) {
        debugPrint('Camera switch failed: $e');
        if (!_disposed && mounted && epoch == _cameraEpoch) {
          setState(() {
            _cameraInitialized = false;
            _initializingCamera = false;
          });
        }
      }
      return;
    }
    await _initCamera();
  }

  Future<void> _handleFocusTap(TapUpDetails details, Size viewportSize) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return;

    final normalized = Offset(
      (details.localPosition.dx / viewportSize.width).clamp(0.0, 1.0),
      (details.localPosition.dy / viewportSize.height).clamp(0.0, 1.0),
    );

    _focusTimer?.cancel();
    setState(() => _focusPoint = details.localPosition);
    _focusTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _focusPoint = null);
    });

    try {
      await controller.setFocusPoint(normalized);
      await controller.setExposurePoint(normalized);
    } catch (_) {
      // Webcams or fixed-focus hardware may not support point focus/exposure.
    }
  }

  ScannedReceiptResult _resultFromPipeline(
    ReceiptPipelineOutput output, {
    Uint8List? imageBytes,
    required bool isFromLiveCamera,
  }) {
    final p = output.parsed;
    final q = output.quality;
    return ScannedReceiptResult(
      amount: p.totalAmount > 0 ? p.totalAmount : 0,
      categoryName: p.categoryName,
      description: p.merchantName,
      date: p.date,
      imageBytes: imageBytes,
      isFromLiveCamera: isFromLiveCamera,
      evatAmount: p.evatAmount,
      vatableSales: p.vatableSales,
      subtotalAmount: p.subtotalAmount,
      rawText: p.rawText,
      processingTimeMs: output.processingTimeMs,
      qualityWarning: q?.qualityWarning,
      isLowQuality: q?.isLowQuality ?? false,
    );
  }

  Future<void> _pickFromGallery() async {
    if (_capturing) return;
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _capturing = true;
        _capturedBytes = bytes;
        _statusMessage = 'Running on-device OCR...';
      });

      final output = await ReceiptOcrProcessor.processReceipt(
        imagePath: picked.path,
        imageBytes: bytes,
        sourceName: picked.name,
      );
      if (!mounted) return;

      final result = _resultFromPipeline(
        output,
        imageBytes: bytes,
        isFromLiveCamera: false,
      );

      setState(() {
        _statusMessage = result.isLowQuality && result.qualityWarning != null
            ? result.qualityWarning!
            : 'Receipt captured!';
      });

      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      Navigator.of(context).pop(result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _statusMessage = 'Could not open gallery.';
      });
    }
  }

  Future<void> _captureReceipt() async {
    if (_capturing) return;
    setState(() {
      _capturing = true;
      _statusMessage = 'Scanning receipt...';
    });

    XFile? photo;
    Uint8List? bytes;
    bool fromCamera = false;

    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized) {
      try {
        photo = await controller.takePicture();
        bytes = await photo.readAsBytes();
        fromCamera = true;
        if (mounted) {
          setState(() {
            _capturedBytes = bytes;
            _statusMessage = 'Running on-device OCR...';
          });
        }
      } catch (_) {
        // Fallback if takePicture fails on emulated webcam
      }
    }

    // On iOS/Safari Web when live WebRTC video is unavailable or blocked, trigger
    // native HTML5 rear camera capture (<input capture="environment">).
    if (!fromCamera && widget.enableLiveCamera && kIsWeb) {
      try {
        final XFile? captured = await _imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 95,
        );
        if (captured == null) {
          if (mounted) {
            setState(() {
              _capturing = false;
              _statusMessage = 'Keep it flat. Hold steady.';
            });
          }
          return;
        }
        photo = captured;
        bytes = await captured.readAsBytes();
        fromCamera = true;
        if (mounted) {
          setState(() {
            _capturedBytes = bytes;
            _statusMessage = 'Running on-device OCR...';
          });
        }
      } catch (_) {
        // Fallback if browser disallows programmatic camera input
      }
    }

    if (!fromCamera &&
        !ReceiptScannerScreen.allowSampleFallbackForTesting) {
      if (mounted) {
        setState(() {
          _capturing = false;
          _statusMessage =
              'Camera unavailable — check permission or pick a photo.';
        });
      }
      return;
    }

    final output = await ReceiptOcrProcessor.processReceipt(
      imagePath: photo?.path,
      imageBytes: bytes,
      allowSampleFallback: ReceiptScannerScreen.allowSampleFallbackForTesting,
    );

    if (!mounted) return;
    final result = _resultFromPipeline(
      output,
      imageBytes: bytes,
      isFromLiveCamera: fromCamera,
    );

    setState(() {
      if (bytes != null) _capturedBytes = bytes;
      _statusMessage = result.isLowQuality && result.qualityWarning != null
          ? result.qualityWarning!
          : 'Receipt captured!';
    });

    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final topSafe = AppLayout.topSafeInset(context);
    final leftSafe = AppLayout.leftSafeInset(context);
    final rightSafe = AppLayout.rightSafeInset(context);
    final browserBar = AppLayout.webSafeInsetsNotifier.value.browserBarBottom;
    final bottomSafe = math.max(
      AppLayout.bottomSafeInset(context),
      browserBar > 0 ? browserBar * 0.45 : 0.0,
    );

    return Scaffold(
      backgroundColor: _bgDark,
      extendBody: true,
      body: Padding(
        padding: EdgeInsets.fromLTRB(leftSafe, topSafe, rightSafe, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 680;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Scanner toolbar (Figma #2480:679)
                    _buildToolbar(compact: compact),

                    // 2. Framing instructions (Figma #2480:689)
                    _buildFramingInstructions(compact: compact),

                    // 3. Larger rectangular receipt viewfinder (#2480:692 / #2480:693)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 8 : 10,
                        ),
                        child: Center(
                          child: _buildCameraPreview(),
                        ),
                      ),
                    ),

                    // 4. Capture controls (Figma #2480:700)
                    _buildCaptureControls(compact: compact),

                    // 5. System / Safari bottom safe spacing
                    SizedBox(
                      height: bottomSafe > 0 ? bottomSafe + 4 : 8,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Figma "Scanner toolbar" (#2480:679): height 76px (62px compact), padding 0 24px.
  Widget _buildToolbar({bool compact = false}) {
    return SizedBox(
      height: compact ? 52 : 60,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Close button (#2485:586)
            Semantics(
              button: true,
              label: 'Close scanner',
              child: GestureDetector(
                key: const Key('scanner_close_button'),
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _surfaceButton,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _strokeBrown, width: 1),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    'assets/icons/x_circle.svg',
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            ),

            // Title (#2480:683)
            Text(
              'Scan receipt',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 20 / 14,
                color: _creamText,
              ),
            ),

            // Flash control (#2480:684)
            Semantics(
              button: true,
              label: _flashOn ? 'Turn flash off' : 'Turn flash on',
              child: GestureDetector(
                key: const Key('scanner_flash_button'),
                behavior: HitTestBehavior.opaque,
                onTap: _toggleFlash,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _surfaceButton,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _flashOn ? _accentOrange : _strokeBrown,
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    _flashOn
                        ? 'assets/icons/zap.svg'
                        : 'assets/icons/zap_off.svg',
                    width: 18,
                    height: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Figma "Framing instructions" (#2480:689).
  Widget _buildFramingInstructions({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, compact ? 2 : 6, 18, compact ? 6 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Line up your receipt.',
            style: GoogleFonts.inter(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 32 / 25,
              color: _creamText,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Fit the whole receipt inside the frame.',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 22 / 15,
              color: _mutedText,
            ),
          ),
        ],
      ),
    );
  }

  /// Portrait receipt rectangle camera viewfinder (#2480:693).
  ///
  /// Uses a tall 0.68 receipt aspect ratio so the alignment guides match real
  /// vertical receipts rather than squishing into a square, and renders captured/
  /// selected photos at consistent un-cropped bounds.
  Widget _buildCameraPreview() {
    return AspectRatio(
      aspectRatio: 0.73,
      child: Container(
        decoration: BoxDecoration(
          color: _previewBg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _strokeBrown, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(27),
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) =>
                  _handleFocusTap(details, constraints.biggest),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Live camera feed, full uncropped photo, or viewfinder backdrop
                  _buildViewportFeed(),

                  // 2. Peripheral dimming (#2480:695)
                  const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.22, 0.74, 1.0],
                          colors: [
                            Color(0x66100B09),
                            Color(0x00100B09),
                            Color(0x00100B09),
                            Color(0x66100B09),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Tall rectangular receipt alignment guides (#2480:696)
                  IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _capturedBytes == null ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 160),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 20, 26, 58),
                        child: CustomPaint(
                          painter: _ReceiptAlignmentGuidesPainter(
                            color: _accentOrange,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 3b. Tap-to-focus reticle indicator
                if (_focusPoint != null)
                  Positioned(
                    left: _focusPoint!.dx - 24,
                    top: _focusPoint!.dy - 24,
                    child: IgnorePointer(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _accentOrange,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 4. Alignment feedback pill (#2480:697)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 22,
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _bgDark,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: _shutterCoral,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _statusMessage,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _creamText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildViewportFeed() {
    if (_capturedBytes != null) {
      return ColoredBox(
        color: const Color(0xFF140D0A),
        child: Image.memory(
          _capturedBytes!,
          fit: BoxFit.contain,
        ),
      );
    }

    final controller = _cameraController;
    if (_cameraInitialized &&
        controller != null &&
        controller.value.isInitialized) {
      final previewSize = controller.value.previewSize;
      if (previewSize != null) {
        // Note: camera previewSize is reported in landscape (width > height) on mobile
        final isPortrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;
        final width = isPortrait ? previewSize.height : previewSize.width;
        final height = isPortrait ? previewSize.width : previewSize.height;

        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: width,
              height: height,
              child: CameraPreview(controller),
            ),
          ),
        );
      }
      return CameraPreview(controller);
    }

    // Clean, native-feeling camera viewfinder backdrop when initializing or without camera hardware
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.85,
          colors: [
            Color(0xFF2E1B15),
            Color(0xFF1A0F0B),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(56, 40, 56, 76),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _surfaceButton,
                      shape: BoxShape.circle,
                      border: Border.all(color: _strokeBrown, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: _accentOrange,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _initializingCamera
                        ? 'Starting camera...'
                        : 'Position receipt in frame',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _creamText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Allow camera access to scan live, or pick an image from your gallery.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                      color: _mutedText.withValues(alpha: 0.85),
                    ),
                  ),
                  if (widget.enableLiveCamera && !_initializingCamera) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _initCamera,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _surfaceButton,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _strokeBrown, width: 1),
                        ),
                        child: Text(
                          'Enable Camera',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _accentOrange,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Figma "Capture controls" (#2480:700).
  Widget _buildCaptureControls({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 6 : 10, 20, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Capture actions row (#2480:702)
          SizedBox(
            height: 88,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Gallery action (#2480:703)
                SizedBox(
                  width: 100,
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: 'Choose receipt from gallery',
                      child: GestureDetector(
                        key: const Key('scanner_gallery_button'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _pickFromGallery,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _surfaceButton,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _strokeBrown, width: 1),
                          ),
                          alignment: Alignment.center,
                          child: SvgPicture.asset(
                            'assets/icons/gallery_images.svg',
                            width: 23,
                            height: 23,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // Capture shutter button (#2480:708)
                Semantics(
                  button: true,
                  label: 'Capture receipt',
                  child: GestureDetector(
                    key: const Key('scanner_shutter_button'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _captureReceipt,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _accentOrange, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: AnimatedScale(
                        scale: _capturing ? 0.92 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: const BoxDecoration(
                            color: _shutterCoral,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: SvgPicture.asset(
                            'assets/icons/scan_shutter.svg',
                            width: 28,
                            height: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // Capture mode (#2480:711)
                SizedBox(
                  width: 100,
                  child: GestureDetector(
                    key: const Key('scanner_mode_button'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _switchOrRetryCamera,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/receipt_text.svg',
                          width: 23,
                          height: 23,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Single receipt',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Seamless bottom spacing handled directly via AppLayout safe insets in build().
}

/// Draws the 4 rounded L-shaped alignment corner brackets from Figma (#2480:696).
class _ReceiptAlignmentGuidesPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _ReceiptAlignmentGuidesPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const arm = 28.0;
    const radius = 10.0;
    final w = size.width;
    final h = size.height;

    final path = Path()
      // Top-left bracket
      ..moveTo(0, arm)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..lineTo(arm, 0)
      // Top-right bracket
      ..moveTo(w - arm, 0)
      ..lineTo(w - radius, 0)
      ..quadraticBezierTo(w, 0, w, radius)
      ..lineTo(w, arm)
      // Bottom-right bracket
      ..moveTo(w, h - arm)
      ..lineTo(w, h - radius)
      ..quadraticBezierTo(w, h, w - radius, h)
      ..lineTo(w - arm, h)
      // Bottom-left bracket
      ..moveTo(arm, h)
      ..lineTo(radius, h)
      ..quadraticBezierTo(0, h, 0, h - radius)
      ..lineTo(0, h - arm);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ReceiptAlignmentGuidesPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
