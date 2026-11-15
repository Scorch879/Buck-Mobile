import 'package:flutter/foundation.dart';

/// Web viewport safe-area and browser-toolbar insets.
///
/// On non-web platforms (iOS/Android/desktop), native [MediaQuery] already
/// reports accurate hardware insets, so all fields default to zero.
class WebSafeInsets {
  final double top;
  final double bottom;
  final double left;
  final double right;
  final double browserBarBottom;

  const WebSafeInsets({
    this.top = 0,
    this.bottom = 0,
    this.left = 0,
    this.right = 0,
    this.browserBarBottom = 0,
  });

  static const WebSafeInsets zero = WebSafeInsets();
}

final ValueNotifier<WebSafeInsets> webSafeInsetsNotifier =
    ValueNotifier<WebSafeInsets>(WebSafeInsets.zero);

WebSafeInsets readWebSafeInsets() => WebSafeInsets.zero;

void initWebSafeInsetsListener() {}

void setWebThemeColor(String hexColor) {}
