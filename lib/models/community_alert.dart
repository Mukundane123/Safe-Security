import '../utils/datetime_util.dart';

enum AlertSeverity {
  info('info', 'Info'),
  warning('warning', 'Warning'),
  critical('critical', 'Critical');

  const AlertSeverity(this.value, this.label);
  final String value;
  final String label;

  static AlertSeverity fromValue(Object? value) {
    return AlertSeverity.values.firstWhere(
      (s) => s.value == value,
      orElse: () => AlertSeverity.info,
    );
  }
}

class CommunityAlert {
  final String alertId;
  final String title;
  final String body;
  final String area;
  final AlertSeverity severity;
  final String issuedBy;
  final String issuedByName;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final bool active;

  const CommunityAlert({
    required this.alertId,
    required this.title,
    required this.body,
    required this.area,
    required this.severity,
    required this.issuedBy,
    required this.issuedByName,
    required this.issuedAt,
    required this.expiresAt,
    required this.active,
  });

  Map<String, dynamic> toMap() {
    return {
      'alertId': alertId,
      'title': title,
      'body': body,
      'area': area,
      'severity': severity.value,
      'issuedBy': issuedBy,
      'issuedByName': issuedByName,
      'issuedAt': issuedAt,
      'expiresAt': expiresAt,
      'active': active,
    };
  }

  factory CommunityAlert.fromMap(Map<String, dynamic> map) {
    return CommunityAlert(
      alertId: (map['alertId'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      area: (map['area'] as String?) ?? '',
      severity: AlertSeverity.fromValue(map['severity']),
      issuedBy: (map['issuedBy'] as String?) ?? '',
      issuedByName: (map['issuedByName'] as String?) ?? '',
      issuedAt: DateTimeUtil.parse(map['issuedAt']) ?? DateTime.now(),
      expiresAt: DateTimeUtil.parse(map['expiresAt']) ?? DateTime.now(),
      active: (map['active'] as bool?) ?? true,
    );
  }
}