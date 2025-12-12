class InterpreterBadge {
  final String id;
  final String userId;
  final String badgeType; // medical_section_type
  final double scorePercentage;
  final DateTime earnedAt;

  InterpreterBadge({
    required this.id,
    required this.userId,
    required this.badgeType,
    required this.scorePercentage,
    required this.earnedAt,
  });

  factory InterpreterBadge.fromJson(Map<String, dynamic> json) =>
      InterpreterBadge(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        badgeType: json['badge'] as String,
        scorePercentage: (json['score'] as num).toDouble(),
        earnedAt: DateTime.parse(json['earned_at'] as String),
      );

  String get displayName {
    switch (badgeType) {
      case 'neurology':
        return 'Neurology';
      case 'cardiology':
        return 'Cardiology';
      case 'respiratory':
        return 'Respiratory';
      case 'gastrointestinal':
        return 'Gastrointestinal';
      case 'endocrinology':
        return 'Endocrinology';
      case 'renal':
        return 'Renal System';
      case 'ob_gyn':
        return 'OB/GYN';
      case 'oncology':
        return 'Oncology';
      case 'emergency':
        return 'Emergency';
      case 'psychology':
        return 'Psychology';
      case 'musculoskeletal':
        return 'Musculoskeletal';
      default:
        return badgeType;
    }
  }
}
