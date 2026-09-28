import '../utils/datetime_util.dart';

enum ZoneRisk {
  low('low', 'Low'),
  normal('normal', 'Normal'),
  high('high', 'High');

  const ZoneRisk(this.value, this.label);
  final String value;
  final String label;

  static ZoneRisk fromValue(Object? value) {
    return ZoneRisk.values.firstWhere(
      (z) => z.value == value,
      orElse: () => ZoneRisk.normal,
    );
  }
}

/// A circular high-risk / watch area defined on the map. When a user's check-in
/// or incident location enters one of these zones they get a safety tip alert.
class SafetyZone {
  final String zoneId;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final ZoneRisk risk;
  final String? note;
  final DateTime createdDate;

  const SafetyZone({
    required this.zoneId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.risk,
    this.note,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() => {
        'zoneId': zoneId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radiusMeters': radiusMeters,
        'risk': risk.value,
        'note': note,
        'createdAt': createdDate,
      };

  factory SafetyZone.fromMap(Map<String, dynamic> map) {
    return SafetyZone(
      zoneId: (map['zoneId'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      radiusMeters: (map['radiusMeters'] as num?)?.toDouble() ?? 500,
      risk: ZoneRisk.fromValue(map['risk']),
      note: map['note'] as String?,
      createdDate: DateTimeUtil.parse(map['createdAt']) ?? DateTime.now(),
    );
  }
}