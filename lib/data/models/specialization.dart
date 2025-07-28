class Specialization {
  final int id;
  final String name;

  Specialization({required this.id, required this.name});

  factory Specialization.fromJson(Map<String, dynamic> json) =>
      Specialization(id: json['id'], name: json['name']);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
