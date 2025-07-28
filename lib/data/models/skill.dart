class Skill {
  final int id;
  final String name;

  Skill({required this.id, required this.name});

  factory Skill.fromJson(Map<String, dynamic> json) =>
      Skill(id: json['id'], name: json['name']);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
