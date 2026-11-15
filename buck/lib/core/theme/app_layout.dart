import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'web_safe_insets_stub.dart'
    if (dart.library.js_interop) 'web_safe_insets_web.dart' as web_insets;

export 'web_safe_insets_stub.dart'
    if (dart.library.js_interop) 'web_safe_insets_web.dart'
    show WebSafeInsets, readWebSafeInsets;

class AppLayout {
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

  /// Bottom clearance for the floating [BuckFooterNav] so it sits cleanly above
  /// both hardware home indicators and mobile Safari's floating bottom bar.
  static double footerBottomOffset(BuildContext context) {
    final webInsets = web_insets.readWebSafeInsets();
    if (webInsets.browserBarBottom > 0) {
      return webInsets.browserBarBottom + 6.0;
    }
    final viewPaddingBottom = MediaQuery.viewPaddingOf(context).bottom;
    if (viewPaddingBottom > 0) {
      return (viewPaddingBottom * 0.4).clamp(6.0, 14.0);
    }
    return 6.0;
  }
}
