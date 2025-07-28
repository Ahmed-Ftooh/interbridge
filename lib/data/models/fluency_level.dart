class FluencyLevel {
  final int id;
  final String level;

  FluencyLevel({required this.id, required this.level});

  factory FluencyLevel.fromJson(Map<String, dynamic> json) =>
      FluencyLevel(id: json['id'], level: json['level']);

  Map<String, dynamic> toJson() => {'id': id, 'level': level};
}
