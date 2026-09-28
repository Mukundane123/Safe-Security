import '../utils/datetime_util.dart';

enum SosStatus {
  active('active'),
  acknowledged('acknowledged'),
  resolved('resolved'),
  cancelled('cancelled');

  const SosStatus(this.value);
  final String value;

  static SosStatus fromValue(Object? value) {
    return SosStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => SosStatus.active,
    );
  }
}

class SosAlert {
  final String sosId;
  final String userId;
  final String userName;
  final double latitude;
  final double longitude;
  final String? note;
  final SosStatus status;
  final DateTime triggeredAt;
  final List<String> notifiedContacts;
  final List<String> notifiedResponders;

  const SosAlert({
    required this.sosId,
    required this.userId,
    required this.userName,
    required this.latitude,
    required this.longitude,
    this.note,
    required this.status,
    required this.triggeredAt,
    required this.notifiedContacts,
    required this.notifiedResponders,
  });

  SosAlert copyWith({
    String? sosId,
    String? userId,
    String? userName,
    double? latitude,
    double? longitude,
    String? note,
    SosStatus? status,
    DateTime? triggeredAt,
    List<String>? notifiedContacts,
    List<String>? notifiedResponders,
  }) {
    return SosAlert(
      sosId: sosId ?? this.sosId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      note: note ?? this.note,
      status: status ?? this.status,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      notifiedContacts: notifiedContacts ?? this.notifiedContacts,
      notifiedResponders: notifiedResponders ?? this.notifiedResponders,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sosId': sosId,
      'userId': userId,
      'userName': userName,
      'latitude': latitude,
      'longitude': longitude,
      'note': note,
      'status': status.value,
      'triggeredAt': triggeredAt,
      'notifiedContacts': notifiedContacts,
      'notifiedResponders': notifiedResponders,
    };
  }

  factory SosAlert.fromMap(Map<String, dynamic> map) {
    return SosAlert(
      sosId: (map['sosId'] as String?) ?? '',
      userId: (map['userId'] as String?) ?? '',
      userName: (map['userName'] as String?) ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      note: map['note'] as String?,
      status: SosStatus.fromValue(map['status']),
      triggeredAt: DateTimeUtil.parse(map['triggeredAt']) ?? DateTime.now(),
      notifiedContacts: _stringList(map['notifiedContacts']),
      notifiedResponders: _stringList(map['notifiedResponders']),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }
}