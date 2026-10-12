import 'package:flutter/widgets.dart';

class AppLayout {
  /// Width of the content column in the 440px Figma mobile frames.
  static const double contentMaxWidth = 383;

  /// Side margin for page content: 28px on the 440px Figma frame,
  /// shrinking to 16px on narrow phones so cards keep their width.
  static double pageMargin(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return ((width - contentMaxWidth) / 2).clamp(16.0, 28.0);
  }
}
