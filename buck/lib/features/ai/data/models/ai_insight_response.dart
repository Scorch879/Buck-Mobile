class AiPeriod {
  final String asOf;
  final String monthStart;

  const AiPeriod({required this.asOf, required this.monthStart});

  factory AiPeriod.fromJson(Map<String, dynamic> json) => AiPeriod(
        asOf: (json['asOf'] as String?) ?? '',
        monthStart: (json['monthStart'] as String?) ?? '',
      );
}

class AiInsightResponse {
  final String id;
  final String title;
  final String suggestion;
  final String advice;
  final int financialHealthScore;
  final String priority;
  final String focus;
  final String walletAdvice;
  final AiPeriod? period;
  final String generatedWith;
  final String createdAt;
  final bool cached;
  final bool stale;

  const AiInsightResponse({
    required this.id,
    required this.title,
    required this.suggestion,
    required this.advice,
    required this.financialHealthScore,
    required this.priority,
    required this.focus,
    required this.walletAdvice,
    this.period,
    required this.generatedWith,
    required this.createdAt,
    this.cached = false,
    this.stale = false,
  });

  factory AiInsightResponse.fromJson(Map<String, dynamic> json) =>
      AiInsightResponse(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? 'Financial Strategy',
        suggestion: (json['suggestion'] as String?) ?? '',
        advice: (json['advice'] as String?) ?? '',
        financialHealthScore: (json['financialHealthScore'] as num?)?.toInt() ?? 80,
        priority: (json['priority'] as String?) ?? 'medium',
        focus: (json['focus'] as String?) ?? 'spending',
        walletAdvice: (json['walletAdvice'] as String?) ?? '',
        period: json['period'] is Map<String, dynamic>
            ? AiPeriod.fromJson(json['period'] as Map<String, dynamic>)
            : null,
        generatedWith: (json['generatedWith'] as String?) ?? 'rules',
        createdAt: (json['createdAt'] as String?) ?? '',
        cached: (json['cached'] as bool?) ?? false,
        stale: (json['stale'] as bool?) ?? false,
      );
}
