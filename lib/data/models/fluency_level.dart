class FluencyLevel {
  final int id;
  final String level;

  FluencyLevel({required this.id, required this.level});

  factory FluencyLevel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final parsedId =
        rawId is num
            ? rawId.toInt()
            : rawId is String
            ? int.tryParse(rawId) ?? 0
            : 0;

    return FluencyLevel(id: parsedId, level: json['level']?.toString() ?? '');
  }

  Map<String, dynamic> toJson() => {'id': id, 'level': level};
}
