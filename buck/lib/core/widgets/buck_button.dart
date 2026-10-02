import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum BuckButtonVariant { primaryCream, orange, outline }

class BuckButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final BuckButtonVariant variant;
  final IconData? suffixIcon;
  final bool isLoading;

  const BuckButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = BuckButtonVariant.primaryCream,
    this.suffixIcon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Border? border;

    switch (variant) {
      case BuckButtonVariant.primaryCream:
        bgColor = AppColors.raisedCream;
        textColor = AppColors.textDark;
        border = null;
        break;
      case BuckButtonVariant.orange:
        bgColor = AppColors.primaryOrange;
        textColor = AppColors.textDark;
        border = null;
        break;
      case BuckButtonVariant.outline:
        bgColor = Colors.transparent;
        textColor = AppColors.textPrimary;
        border = Border.all(color: AppColors.inputBorder, width: 1.2);
        break;
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: isLoading ? null : onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: border,
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(textColor),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        text,
                        style: AppTextStyles.buttonPrimary.copyWith(color: textColor),
                      ),
                      if (suffixIcon != null) ...[
                        const SizedBox(width: 8),
                        Icon(suffixIcon, color: textColor, size: 18),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
