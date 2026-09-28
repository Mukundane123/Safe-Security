import '../utils/datetime_util.dart';

/// A responder's live position that appears on the incident map when they have
/// location broadcasting switched on.
class ResponderLocation {
  final String responderId;
  final String responderName;
  final double latitude;
  final double longitude;
  final DateTime lastSeen;
  final bool broadcasting;

  const ResponderLocation({
    required this.responderId,
    required this.responderName,
    required this.latitude,
    required this.longitude,
    required this.lastSeen,
    this.broadcasting = true,
  });

  bool get isStale =>
      DateTime.now().difference(lastSeen).inMinutes > 5;

  Map<String, dynamic> toMap() => {
        'responderId': responderId,
        'responderName': responderName,
        'latitude': latitude,
        'longitude': longitude,
        'lastSeen': lastSeen,
        'broadcasting': broadcasting,
      };

  factory ResponderLocation.fromMap(Map<String, dynamic> map) {
    return ResponderLocation(
      responderId: (map['responderId'] as String?) ?? '',
      responderName: (map['responderName'] as String?) ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      lastSeen: DateTimeUtil.parse(map['lastSeen']) ?? DateTime.now(),
      broadcasting: (map['broadcasting'] as bool?) ?? true,
    );
  }
}