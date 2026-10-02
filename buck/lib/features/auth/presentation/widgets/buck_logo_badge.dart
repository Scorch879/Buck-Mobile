import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

class BuckLogoBadge extends StatelessWidget {
  final double size;

  const BuckLogoBadge({super.key, this.size = 88});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF35251D),
        border: Border.all(color: AppColors.inputBorder, width: 2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.72,
        height: size * 0.72,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.raisedCream,
        ),
        alignment: Alignment.center,
        child: Text(
          'B',
          style: GoogleFonts.inter(
            fontSize: size * 0.45,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
          ),
        ),
      ),
    );
  }
}
