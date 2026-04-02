import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_parsers.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.roles,
    required this.impactPoints,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final List<String> roles;
  final int impactPoints;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isVolunteer => hasRole('Volunteer');
  bool get isOrganizer => hasRole('Organizer');

  bool hasRole(String role) {
    final target = role.trim().toLowerCase();
    return roles.any((item) => item.trim().toLowerCase() == target);
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    List<String>? roles,
    int? impactPoints,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      roles: roles ?? this.roles,
      impactPoints: impactPoints ?? this.impactPoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'roles': roles,
      'role': roles.isNotEmpty ? roles.first : 'Volunteer',
      'impactPoints': impactPoints,
      'totalPoints': impactPoints,
      'rewardPoints': impactPoints,
      'points': impactPoints,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {required String id}) {
    final parsedRoles = _parseRoles(map);

    return UserModel(
      id: id,
      name: ModelParsers.parseString(map['name']),
      email: ModelParsers.parseString(map['email']),
      phone: ModelParsers.parseString(map['phone']),
      roles: parsedRoles,
      impactPoints: ModelParsers.parseInt(
        map['impactPoints'] ??
            map['totalPoints'] ??
            map['rewardPoints'] ??
            map['points'],
      ),
      createdAt: ModelParsers.parseDate(map['createdAt']),
      updatedAt: ModelParsers.parseDate(map['updatedAt']),
    );
  }

  factory UserModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserModel.fromMap(data, id: doc.id);
  }

  static List<String> _parseRoles(Map<String, dynamic> map) {
    final roles = ModelParsers.parseStringList(map['roles']);
    if (roles.isNotEmpty) {
      return roles;
    }

    final fallbackRole = ModelParsers.parseString(
      map['role'],
      fallback: 'Volunteer',
    );
    if (fallbackRole.isNotEmpty) {
      return [fallbackRole];
    }

    return const ['Volunteer'];
  }
}

class UserProfileModel {
  const UserProfileModel({
    required this.id,
    this.name = '',
    this.bio = '',
    this.photoUrl = '',
    this.phone = '',
    this.location = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String bio;
  final String photoUrl;
  final String phone;
  final String location;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfileModel copyWith({
    String? id,
    String? name,
    String? bio,
    String? photoUrl,
    String? phone,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'bio': bio,
      'about': bio,
      'description': bio,
      'photoUrl': photoUrl,
      'avatarUrl': photoUrl,
      'phone': phone,
      'location': location,
      'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  factory UserProfileModel.fromMap(
    Map<String, dynamic> map, {
    required String id,
  }) {
    return UserProfileModel(
      id: id,
      name: ModelParsers.parseString(
        map['name'] ?? map['displayName'] ?? map['fullName'],
      ),
      bio: ModelParsers.parseString(
        map['bio'] ?? map['about'] ?? map['description'],
      ),
      photoUrl: ModelParsers.parseString(map['photoUrl'] ?? map['avatarUrl']),
      phone: ModelParsers.parseString(map['phone']),
      location: ModelParsers.parseString(map['location']),
      createdAt: ModelParsers.parseDate(map['createdAt']),
      updatedAt: ModelParsers.parseDate(map['updatedAt']),
    );
  }

  factory UserProfileModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return UserProfileModel.fromMap(data, id: doc.id);
  }
}

class FollowStateModel {
  const FollowStateModel({
    required this.userId,
    this.followingUserIds = const [],
    this.followerUserIds = const [],
    this.updatedAt,
  });

  final String userId;
  final List<String> followingUserIds;
  final List<String> followerUserIds;
  final DateTime? updatedAt;

  int get followingCount => followingUserIds.length;
  int get followerCount => followerUserIds.length;

  bool isFollowing(String targetUserId) {
    return followingUserIds.contains(targetUserId);
  }

  FollowStateModel copyWith({
    String? userId,
    List<String>? followingUserIds,
    List<String>? followerUserIds,
    DateTime? updatedAt,
  }) {
    return FollowStateModel(
      userId: userId ?? this.userId,
      followingUserIds: followingUserIds ?? this.followingUserIds,
      followerUserIds: followerUserIds ?? this.followerUserIds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'followingUserIds': followingUserIds,
      'followerUserIds': followerUserIds,
      'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  factory FollowStateModel.fromMap(
    Map<String, dynamic> map, {
    required String userId,
  }) {
    return FollowStateModel(
      userId: userId,
      followingUserIds: ModelParsers.parseStringList(map['followingUserIds']),
      followerUserIds: ModelParsers.parseStringList(map['followerUserIds']),
      updatedAt: ModelParsers.parseDate(map['updatedAt']),
    );
  }

  factory FollowStateModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return FollowStateModel.fromMap(data, userId: doc.id);
  }
}

class UserAggregateModel {
  const UserAggregateModel({
    required this.user,
    this.profile,
    this.followState,
  });

  final UserModel user;
  final UserProfileModel? profile;
  final FollowStateModel? followState;

  String get displayName {
    final profileName = profile?.name.trim() ?? '';
    if (profileName.isNotEmpty) return profileName;
    return user.name;
  }

  int get followingCount => followState?.followingCount ?? 0;
  int get followerCount => followState?.followerCount ?? 0;

  UserAggregateModel copyWith({
    UserModel? user,
    UserProfileModel? profile,
    FollowStateModel? followState,
  }) {
    return UserAggregateModel(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      followState: followState ?? this.followState,
    );
  }
}
