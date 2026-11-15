import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'web_safe_insets_stub.dart'
    if (dart.library.js_interop) 'web_safe_insets_web.dart' as web_insets;

export 'web_safe_insets_stub.dart'
    if (dart.library.js_interop) 'web_safe_insets_web.dart'
    show
        WebSafeInsets,
        initWebSafeInsetsListener,
        readWebSafeInsets,
        setWebThemeColor,
        webSafeInsetsNotifier;

class AppLayout {
  static const String shellThemeHex = '#2B1309';
  static const String darkSurfaceThemeHex = '#100B09';
  static int _darkBarSurfaceDepth = 0;

  static ValueNotifier<web_insets.WebSafeInsets> get webSafeInsetsNotifier =>
      web_insets.webSafeInsetsNotifier;

  static void initWebSafeInsetsListener() =>
      web_insets.initWebSafeInsetsListener();

  /// Switches the web browser chrome (`theme-color` & viewport background) to
  /// `#100B09` while dark full-screen overlays/settings are mounted.
  static void pushDarkBarSurface() {
    _darkBarSurfaceDepth++;
    if (_darkBarSurfaceDepth == 1) {
      web_insets.setWebThemeColor(darkSurfaceThemeHex);
    }
  }

  /// Restores the web browser chrome to `#2B1309` once all `#100B09`
  /// overlays/settings routes are closed.
  static void popDarkBarSurface() {
    if (_darkBarSurfaceDepth > 0) {
      _darkBarSurfaceDepth--;
    }
    if (_darkBarSurfaceDepth == 0) {
      web_insets.setWebThemeColor(shellThemeHex);
    }
  }

  /// Maximum width of the main content column across phones and tablets.
  static const double contentMaxWidth = 600;

  /// Responsive horizontal side margin so cards utilize full usable phone width
  /// on compact, standard, and large devices alike.
  static double pageMargin(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 380) return 14.0;
    if (width < 600) return 16.0;
    return 24.0;
  }

  /// Effective top safe-area inset across native mobile, desktop, and iOS
  /// Safari / PWA (`env(safe-area-inset-top)`).
  static double topSafeInset(BuildContext context) {
    final viewTop = MediaQuery.viewPaddingOf(context).top;
    final webTop = web_insets.readWebSafeInsets().top;
    return math.max(viewTop, webTop);
  }

  /// Effective bottom safe-area inset across native mobile, desktop, and iOS
  /// Safari / PWA (`env(safe-area-inset-bottom)` + floating browser chrome).
  static double bottomSafeInset(BuildContext context) {
    final viewBottom = MediaQuery.viewPaddingOf(context).bottom;
    final webBottom = web_insets.readWebSafeInsets().bottom;
    return math.max(viewBottom, webBottom);
  }

  /// Effective left safe-area inset (landscape notch / Dynamic Island).
  static double leftSafeInset(BuildContext context) {
    final viewLeft = MediaQuery.viewPaddingOf(context).left;
    final webLeft = web_insets.readWebSafeInsets().left;
    return math.max(viewLeft, webLeft);
  }

  /// Effective right safe-area inset (landscape notch / Dynamic Island).
  static double rightSafeInset(BuildContext context) {
    final viewRight = MediaQuery.viewPaddingOf(context).right;
    final webRight = web_insets.readWebSafeInsets().right;
    return math.max(viewRight, webRight);
  }

  /// Bottom clearance for the floating [BuckFooterNav] so it sits cleanly above
  /// both hardware home indicators and mobile Safari's floating bottom bar,
  /// adapting dynamically as browser toolbars expand or collapse.
  static double footerBottomOffset(BuildContext context) {
    final webInsets = web_insets.readWebSafeInsets();
    final viewPaddingBottom = math.max(
      MediaQuery.viewPaddingOf(context).bottom,
      webInsets.bottom,
    );
    if (webInsets.browserBarBottom > 0) {
      return math.max(10.0, webInsets.browserBarBottom * 0.32).clamp(10.0, 20.0);
    }
    if (viewPaddingBottom > 0) {
      return (viewPaddingBottom * 0.35).clamp(6.0, 16.0);
    }
    return 6.0;
  }
}
