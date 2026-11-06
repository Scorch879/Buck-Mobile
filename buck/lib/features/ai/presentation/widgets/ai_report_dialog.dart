import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/buck_glass_card.dart';
import '../../../../core/widgets/buck_overlay_dialog.dart';
import '../../data/models/ai_insight_response.dart';
import '../../data/services/buck_ai_service.dart';

/// Shows the full AI Financial Health & Strategy report modal.
Future<void> showAiReportDialog({
  required BuildContext context,
  AiInsightResponse? initialInsight,
  BuckAiService? aiService,
}) {
  return showBuckOverlayDialog<void>(
    context: context,
    builder: (ctx) => _AiReportDialogContent(
      initialInsight: initialInsight,
      aiService: aiService ?? BuckAiService(),
    ),
  );
}

class _AiReportDialogContent extends StatefulWidget {
  final AiInsightResponse? initialInsight;
  final BuckAiService aiService;

  const _AiReportDialogContent({
    this.initialInsight,
    required this.aiService,
  });

  @override
  State<_AiReportDialogContent> createState() => _AiReportDialogContentState();
}

class _AiReportDialogContentState extends State<_AiReportDialogContent> {
  late AiInsightResponse? _insight = widget.initialInsight;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (_insight == null) {
      _loadReport(refresh: false);
    }
  }

  Future<void> _loadReport({required bool refresh}) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await widget.aiService.getInsight(refresh: refresh);
      if (mounted) {
        setState(() {
          _insight = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return AppColors.savingsGreen;
    if (score >= 60) return AppColors.amberAccent;
    return AppColors.expensePink;
  }

  String _getScoreLabel(int score) {
    if (score >= 80) return 'Optimal';
    if (score >= 60) return 'Moderate';
    return 'Attention Needed';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 380;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: size.height * 0.88,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 24,
            vertical: 24,
          ),
          child: Material(
            color: Colors.transparent,
            child: BuckGlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context),
                  const Divider(color: AppColors.subtleDivider, height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _loading
                          ? _buildLoadingState()
                          : _errorMessage != null
                              ? _buildErrorState()
                              : _insight != null
                                  ? _buildReportBody(_insight!)
                                  : const SizedBox.shrink(),
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  AppColors.gradientOrangeStart,
                  AppColors.gradientOrangeEnd,
                ],
              ),
            ),
            child: SvgPicture.asset(
              'assets/icons/sparkles.svg',
              width: 18,
              height: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BUCK AI REPORT',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textAccent,
                  ),
                ),
                Text(
                  'Financial Health & Strategy',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cardTitle,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.primaryOrange),
            SizedBox(height: 16),
            Text(
              'Analyzing financial metrics with Buck AI...',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_off, color: AppColors.expensePink, size: 36),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unable to connect to AI Advisor',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _loadReport(refresh: true),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportBody(AiInsightResponse report) {
    final scoreColor = _getScoreColor(report.financialHealthScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Health Score Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF140B07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scoreColor.withValues(alpha: 0.15),
                  border: Border.all(color: scoreColor, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${report.financialHealthScore}',
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: scoreColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'FINANCIAL SCORE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: scoreColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getScoreLabel(report.financialHealthScore),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: scoreColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.title,
                      style: GoogleFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Actionable Suggestion Callout
        if (report.suggestion.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.amberAccent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    report.suggestion,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 3. Detailed Strategy Advice
        Text(
          'DETAILED STRATEGY ANALYSIS',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.textAccent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          report.advice,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.55,
            color: const Color(0xFFE2D6CF),
          ),
        ),

        // 4. Wallet Allocation Strategy
        if (report.walletAdvice.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'WALLET ALLOCATION DIRECTIVE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.textAccent,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF160D08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.3)),
            ),
            child: Text(
              report.walletAdvice,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // 5. Metadata & Refresh Controls
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF231610),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'AI: ${report.generatedWith}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _loading ? null : () => _loadReport(refresh: true),
              icon: const Icon(Icons.refresh, size: 14, color: AppColors.primaryOrange),
              label: Text(
                'Regenerate',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryOrange,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
