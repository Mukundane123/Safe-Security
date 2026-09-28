import '../utils/datetime_util.dart';

/// A live GPS position pushed from a person's phone while an SOS is active.
/// Responders and the admin follow the trail on the SOS console so they can
/// converge on the exact spot instead of the last reported point.
class SosLocationUpdate {
  final String sosId;
  final double latitude;
  final double longitude;
  final DateTime capturedAt;

  const SosLocationUpdate({
    required this.sosId,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
  });

  Map<String, dynamic> toMap() => {
        'sosId': sosId,
        'latitude': latitude,
        'longitude': longitude,
        'capturedAt': capturedAt,
      };

  factory SosLocationUpdate.fromMap(Map<String, dynamic> map) {
    return SosLocationUpdate(
      sosId: (map['sosId'] as String?) ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      capturedAt: DateTimeUtil.parse(map['capturedAt']) ?? DateTime.now(),
    );
  }
}