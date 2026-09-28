import '../utils/datetime_util.dart';

enum ContactConfirmation {
  pending('pending'),
  confirmed('confirmed'),
  declined('declined');

  const ContactConfirmation(this.value);
  final String value;

  static ContactConfirmation fromValue(Object? value) {
    return ContactConfirmation.values.firstWhere(
      (c) => c.value == value,
      orElse: () => ContactConfirmation.pending,
    );
  }
}

class TrustedContact {
  final String id;
  final String userId;
  final String contactName;
  final String contactPhone;
  final String? contactUserId;
  final DateTime createdDate;
  final ContactConfirmation confirmationStatus;

  const TrustedContact({
    required this.id,
    required this.userId,
    required this.contactName,
    required this.contactPhone,
    this.contactUserId,
    required this.createdDate,
    required this.confirmationStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'contactUserId': contactUserId,
      'createdAt': createdDate,
      'confirmationStatus': confirmationStatus.value,
    };
  }

  factory TrustedContact.fromMap(Map<String, dynamic> map) {
    return TrustedContact(
      id: (map['id'] as String?) ?? '',
      userId: (map['userId'] as String?) ?? '',
      contactName: (map['contactName'] as String?) ?? '',
      contactPhone: (map['contactPhone'] as String?) ?? '',
      contactUserId: map['contactUserId'] as String?,
      createdDate: DateTimeUtil.parse(map['createdAt']) ?? DateTime.now(),
      confirmationStatus:
          ContactConfirmation.fromValue(map['confirmationStatus']),
    );
  }
}