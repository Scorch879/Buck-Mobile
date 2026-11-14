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

WebSafeInsets readWebSafeInsets() => WebSafeInsets.zero;
