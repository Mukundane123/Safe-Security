import '../utils/datetime_util.dart';

enum NotificationType {
  sos('sos'),
  incidentUpdate('incident_update'),
  assignment('assignment'),
  communityAlert('community_alert');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromValue(Object? value) {
    return NotificationType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => NotificationType.incidentUpdate,
    );
  }

  String get label => switch (this) {
        NotificationType.sos => 'SOS Alert',
        NotificationType.incidentUpdate => 'Incident Update',
        NotificationType.assignment => 'Assignment',
        NotificationType.communityAlert => 'Community Alert',
      };
}

enum DeliveryStatus {
  pending('pending'),
  delivered('delivered'),
  failed('failed');

  const DeliveryStatus(this.value);
  final String value;

  static DeliveryStatus fromValue(Object? value) {
    return DeliveryStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => DeliveryStatus.delivered,
    );
  }
}

class AppNotification {
  final String notificationId;
  final String recipientId;
  final NotificationType type;
  final String title;
  final String body;
  final String? relatedEntityId;
  final DeliveryStatus deliveryStatus;
  final DateTime sentAt;
  final DateTime? readAt;

  const AppNotification({
    required this.notificationId,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.body,
    this.relatedEntityId,
    required this.deliveryStatus,
    required this.sentAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      notificationId: notificationId,
      recipientId: recipientId,
      type: type,
      title: title,
      body: body,
      relatedEntityId: relatedEntityId,
      deliveryStatus: deliveryStatus,
      sentAt: sentAt,
      readAt: readAt ?? this.readAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'recipientId': recipientId,
      'type': type.value,
      'title': title,
      'body': body,
      'relatedEntityId': relatedEntityId,
      'deliveryStatus': deliveryStatus.value,
      'sentAt': sentAt,
      'readAt': readAt,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      notificationId: (map['notificationId'] as String?) ?? '',
      recipientId: (map['recipientId'] as String?) ?? '',
      type: NotificationType.fromValue(map['type']),
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      relatedEntityId: map['relatedEntityId'] as String?,
      deliveryStatus: DeliveryStatus.fromValue(map['deliveryStatus']),
      sentAt: DateTimeUtil.parse(map['sentAt']) ?? DateTime.now(),
      readAt: DateTimeUtil.parse(map['readAt']),
    );
  }
}