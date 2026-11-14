import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'web_safe_insets_stub.dart'
    if (dart.library.js_interop) 'web_safe_insets_web.dart' as web_insets;

export 'web_safe_insets_stub.dart'
    if (dart.library.js_interop) 'web_safe_insets_web.dart'
    show WebSafeInsets, readWebSafeInsets;

class AppLayout {
  /// Width of the content column in the 440px Figma mobile frames.
  static const double contentMaxWidth = 383;

  /// Side margin for page content: 28px on the 440px Figma frame,
  /// shrinking to 16px on narrow phones so cards keep their width.
  static double pageMargin(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return ((width - contentMaxWidth) / 2).clamp(16.0, 28.0);
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
