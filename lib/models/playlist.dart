class Playlist {
  final String id;
  final String name;
  final List<String> usernames;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    required this.usernames,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'usernames': usernames,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        usernames: (json['usernames'] as List<dynamic>).cast<String>(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
