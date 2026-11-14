import 'dart:convert';
import 'dart:js_interop';

@JS('buckGetSafeInsets')
external JSString? _jsBuckGetSafeInsets();

/// Web viewport safe-area and browser-toolbar insets measured from CSS
/// `env(safe-area-inset-*)` and the difference between `100lvh` and `100svh`.
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

WebSafeInsets readWebSafeInsets() {
  try {
    final raw = _jsBuckGetSafeInsets()?.toDart;
    if (raw == null || raw.isEmpty) return WebSafeInsets.zero;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return WebSafeInsets.zero;

    double toDouble(String key) {
      final v = decoded[key];
      return v is num ? v.toDouble().clamp(0.0, 300.0) : 0.0;
    }

    return WebSafeInsets(
      top: toDouble('top'),
      bottom: toDouble('bottom'),
      left: toDouble('left'),
      right: toDouble('right'),
      browserBarBottom: toDouble('browserBarBottom'),
    );
  } catch (_) {
    return WebSafeInsets.zero;
  }
}
