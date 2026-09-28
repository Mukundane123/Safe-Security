/// Per-user push notification preferences.
///
/// Stored on the user profile (`users/{uid}/notificationPreferences`) so the
/// backend can honour them before dispatching. SOS alerts are always on: the
/// app is a safety tool, so that switch is intentionally not offered.
class NotificationPreferences {
  final bool incidentUpdates;
  final bool assignments;
  final bool communityAlerts;
  final bool emailDigest;

  const NotificationPreferences({
    this.incidentUpdates = true,
    this.assignments = true,
    this.communityAlerts = false,
    this.emailDigest = false,
  });

  /// Whether a notification of [type] should be pushed for this user.
  bool allows(String type) => switch (type) {
        'incident_update' => incidentUpdates,
        'assignment' => assignments,
        'community_alert' => communityAlerts,
        _ => true,
      };

  NotificationPreferences copyWith({
    bool? incidentUpdates,
    bool? assignments,
    bool? communityAlerts,
    bool? emailDigest,
  }) {
    return NotificationPreferences(
      incidentUpdates: incidentUpdates ?? this.incidentUpdates,
      assignments: assignments ?? this.assignments,
      communityAlerts: communityAlerts ?? this.communityAlerts,
      emailDigest: emailDigest ?? this.emailDigest,
    );
  }

  Map<String, dynamic> toMap() => {
        'incidentUpdates': incidentUpdates,
        'assignments': assignments,
        'communityAlerts': communityAlerts,
        'emailDigest': emailDigest,
      };

  factory NotificationPreferences.fromMap(Object? raw) {
    if (raw is! Map) return const NotificationPreferences();
    bool flag(String key, bool fallback) {
      final v = raw[key];
      return v is bool ? v : fallback;
    }

    return NotificationPreferences(
      incidentUpdates: flag('incidentUpdates', true),
      assignments: flag('assignments', true),
      communityAlerts: flag('communityAlerts', false),
      emailDigest: flag('emailDigest', false),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.incidentUpdates == incidentUpdates &&
      other.assignments == assignments &&
      other.communityAlerts == communityAlerts &&
      other.emailDigest == emailDigest;

  @override
  int get hashCode => Object.hash(
      incidentUpdates, assignments, communityAlerts, emailDigest);
}
