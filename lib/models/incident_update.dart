import '../utils/datetime_util.dart';

/// One entry on an incident's audit timeline. Every status change, assignment,
/// classification and community update is appended so admins and responders can
/// audit what happened and when.
class IncidentUpdate {
  final String updateId;
  final String incidentId;
  final String actorId;
  final String actorName;
  final String action;
  final String? detail;
  final DateTime timestamp;

  const IncidentUpdate({
    required this.updateId,
    required this.incidentId,
    required this.actorId,
    required this.actorName,
    required this.action,
    this.detail,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'updateId': updateId,
        'incidentId': incidentId,
        'actorId': actorId,
        'actorName': actorName,
        'action': action,
        'detail': detail,
        'timestamp': timestamp,
      };

  factory IncidentUpdate.fromMap(Map<String, dynamic> map) {
    return IncidentUpdate(
      updateId: (map['updateId'] as String?) ?? '',
      incidentId: (map['incidentId'] as String?) ?? '',
      actorId: (map['actorId'] as String?) ?? '',
      actorName: (map['actorName'] as String?) ?? '',
      action: (map['action'] as String?) ?? '',
      detail: map['detail'] as String?,
      timestamp: DateTimeUtil.parse(map['timestamp']) ?? DateTime.now(),
    );
  }
}