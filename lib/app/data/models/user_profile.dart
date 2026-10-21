import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.username,
    required this.countryCode,
    required this.countryName,
    required this.createdAt,
    this.birthDate,
    this.gender = '',
    this.bio = '',
    this.photoUrl = '',
    this.isGuest = false,
    this.emailVerified = false,
    this.isVerified = false,
    this.isOfficialDeveloper = false,
    this.privacy = const UserPrivacy(),
  });

  final String uid;
  final String email;
  final String displayName;
  final String username;
  final String countryCode;
  final String countryName;
  final DateTime createdAt;
  final DateTime? birthDate;
  final String gender;
  final String bio;
  final String photoUrl;
  final bool isGuest;
  final bool emailVerified;
  final bool isVerified;
  final bool isOfficialDeveloper;
  final UserPrivacy privacy;

  factory UserProfile.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return UserProfile(
      uid: doc.id,
      email: '${data['email'] ?? ''}',
      displayName: '${data['displayName'] ?? ''}',
      username: '${data['username'] ?? ''}',
      countryCode: '${data['countryCode'] ?? ''}',
      countryName: '${data['countryName'] ?? ''}',
      createdAt: _date(data['createdAt']) ?? DateTime.now(),
      birthDate: _date(data['birthDate']),
      gender: '${data['gender'] ?? ''}',
      bio: '${data['bio'] ?? ''}',
      photoUrl: '${data['photoUrl'] ?? ''}',
      isGuest: data['isGuest'] == true,
      emailVerified: data['emailVerified'] == true,
      isVerified: data['isVerified'] == true,
      isOfficialDeveloper: data['isOfficialDeveloper'] == true,
      privacy: UserPrivacy.fromMap(data['privacy']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'username': username,
        'countryCode': countryCode,
        'countryName': countryName,
        'createdAt': Timestamp.fromDate(createdAt),
        'birthDate': birthDate == null ? null : Timestamp.fromDate(birthDate!),
        'gender': gender,
        'bio': bio,
        'photoUrl': photoUrl,
        'isGuest': isGuest,
        'emailVerified': emailVerified,
        'isVerified': isVerified,
        'isOfficialDeveloper': isOfficialDeveloper,
        'privacy': privacy.toMap(),
      };

  UserProfile copyWith({
    String? displayName,
    String? username,
    String? bio,
    UserPrivacy? privacy,
    bool? emailVerified,
  }) => UserProfile(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        username: username ?? this.username,
        countryCode: countryCode,
        countryName: countryName,
        createdAt: createdAt,
        birthDate: birthDate,
        gender: gender,
        bio: bio ?? this.bio,
        photoUrl: photoUrl,
        isGuest: isGuest,
        emailVerified: emailVerified ?? this.emailVerified,
        isVerified: isVerified,
        isOfficialDeveloper: isOfficialDeveloper,
        privacy: privacy ?? this.privacy,
      );

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse('$value');
  }
}

class UserPrivacy {
  const UserPrivacy({
    this.bio = true,
    this.country = false,
    this.statistics = false,
    this.lists = false,
    this.bookmarks = false,
    this.completed = false,
    this.activity = false,
    this.achievements = false,
    this.customLists = false,
  });

  final bool bio;
  final bool country;
  final bool statistics;
  final bool lists;
  final bool bookmarks;
  final bool completed;
  final bool activity;
  final bool achievements;
  final bool customLists;

  factory UserPrivacy.fromMap(dynamic value) {
    final map = value is Map ? Map<String, dynamic>.from(value) : const <String, dynamic>{};
    return UserPrivacy(
      bio: map['bio'] != false,
      country: map['country'] == true,
      statistics: map['statistics'] == true,
      lists: map['lists'] == true,
      bookmarks: map['bookmarks'] == true,
      completed: map['completed'] == true,
      activity: map['activity'] == true,
      achievements: map['achievements'] == true,
      customLists: map['customLists'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'bio': bio,
        'country': country,
        'statistics': statistics,
        'lists': lists,
        'bookmarks': bookmarks,
        'completed': completed,
        'activity': activity,
        'achievements': achievements,
        'customLists': customLists,
      };
}
