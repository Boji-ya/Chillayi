// lib/models/user_model.dart

class UserModel {
  final String uid;
  final String username;
  final String email;
  final String? avatarUrl;
  final List<String> favorites;
  final int points;
  final List<String> completedMissions;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.favorites = const [],
    this.points = 0,
    this.completedMissions = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      username: map['username'] ?? '旅行者',
      email: map['email'] ?? '',
      avatarUrl: map['avatarUrl'],
      favorites: List<String>.from(map['favorites'] ?? []),
      points: map['points'] ?? 0,
      completedMissions: List<String>.from(map['completedMissions'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'avatarUrl': avatarUrl,
      'favorites': favorites,
      'points': points,
      'completedMissions': completedMissions,
    };
  }

  UserModel copyWith({
    String? username,
    String? avatarUrl,
    List<String>? favorites,
    int? points,
    List<String>? completedMissions,
  }) {
    return UserModel(
      uid: uid,
      username: username ?? this.username,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      favorites: favorites ?? this.favorites,
      points: points ?? this.points,
      completedMissions: completedMissions ?? this.completedMissions,
    );
  }
}
