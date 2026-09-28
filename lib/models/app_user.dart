import '../utils/datetime_util.dart';

enum UserRole {
  citizen('citizen'),
  responder('responder'),
  administrator('administrator');

  const UserRole(this.value);
  final String value;

  static UserRole fromValue(String? value) {
    return UserRole.values.firstWhere(
      (r) => r.value == value,
      orElse: () => UserRole.citizen,
    );
  }

  String get label => switch (this) {
        UserRole.citizen => 'Citizen',
        UserRole.responder => 'Responder',
        UserRole.administrator => 'Administrator',
      };
}

enum AccountStatus {
  active('active'),
  suspended('suspended');

  const AccountStatus(this.value);
  final String value;

  static AccountStatus fromValue(String? value) {
    return value == AccountStatus.suspended.value
        ? AccountStatus.suspended
        : AccountStatus.active;
  }

  String get label => this == AccountStatus.active ? 'active' : 'suspended';
}

/// Vetting state for responder accounts. A responder may only claim / receive
/// assignments after an administrator approves their application.
enum ResponderVerification {
  none('none', 'Not a responder'),
  pending('pending', 'Pending review'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected');

  const ResponderVerification(this.value, this.label);
  final String value;
  final String label;

  static ResponderVerification fromValue(String? value) {
    return ResponderVerification.values.firstWhere(
      (v) => v.value == value,
      orElse: () => ResponderVerification.none,
    );
  }
}

class AppUser {
  final String userId;
  final String name;
  final String phone;
  final String email;
  final UserRole role;
  final DateTime createdDate;
  final DateTime lastLogin;
  final AccountStatus status;
  final String? profilePhotoUrl;
  final bool phoneVerified;
  final ResponderVerification verificationStatus;

  const AppUser({
    required this.userId,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    required this.createdDate,
    required this.lastLogin,
    required this.status,
    this.profilePhotoUrl,
    this.phoneVerified = false,
    this.verificationStatus = ResponderVerification.none,
  });

  AppUser copyWith({
    String? name,
    String? phone,
    String? email,
    UserRole? role,
    DateTime? lastLogin,
    AccountStatus? status,
    String? profilePhotoUrl,
    bool? phoneVerified,
    ResponderVerification? verificationStatus,
  }) {
    return AppUser(
      userId: userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      createdDate: createdDate,
      lastLogin: lastLogin ?? this.lastLogin,
      status: status ?? this.status,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role.value,
      'createdAt': createdDate,
      'lastLogin': lastLogin,
      'status': status.value,
      'profilePhotoUrl': profilePhotoUrl,
      'phoneVerified': phoneVerified,
      'verificationStatus': verificationStatus.value,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      userId: map['userId'] as String,
      name: (map['name'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      role: UserRole.fromValue(map['role'] as String?),
      createdDate: DateTimeUtil.parse(map['createdAt']) ?? DateTime.now(),
      lastLogin: DateTimeUtil.parse(map['lastLogin']) ?? DateTime.now(),
      status: AccountStatus.fromValue(map['status'] as String?),
      profilePhotoUrl: map['profilePhotoUrl'] as String?,
      phoneVerified: (map['phoneVerified'] as bool?) ?? false,
      verificationStatus: ResponderVerification.fromValue(
          map['verificationStatus'] as String?),
    );
  }
}