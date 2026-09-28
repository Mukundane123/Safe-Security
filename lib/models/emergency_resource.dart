/// Type of an [EmergencyResource] shown in the directory / on the map.
enum EmergencyResourceType {
  hospital('hospital', 'Hospital'),
  police('police', 'Police post'),
  fire('fire', 'Fire station'),
  safeHaven('safe_haven', 'Safe haven'),
  rallyPoint('rally_point', 'Rally / meeting point');

  const EmergencyResourceType(this.value, this.label);
  final String value;
  final String label;

  static EmergencyResourceType fromValue(Object? value) {
    return EmergencyResourceType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => EmergencyResourceType.safeHaven,
    );
  }
}

/// A static emergency facility or meeting point around Kakoba Division:
/// hospitals, police posts, fire stations, safe havens and rally points that
/// residents can reach during an incident or community alert.
class EmergencyResource {
  final String resourceId;
  final EmergencyResourceType type;
  final String name;
  final String? phone;
  final String? description;
  final String? openHours;
  final double latitude;
  final double longitude;

  const EmergencyResource({
    required this.resourceId,
    required this.type,
    required this.name,
    this.phone,
    this.description,
    this.openHours,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toMap() => {
        'resourceId': resourceId,
        'type': type.value,
        'name': name,
        'phone': phone,
        'description': description,
        'openHours': openHours,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory EmergencyResource.fromMap(Map<String, dynamic> map) {
    return EmergencyResource(
      resourceId: (map['resourceId'] as String?) ?? '',
      type: EmergencyResourceType.fromValue(map['type']),
      name: (map['name'] as String?) ?? '',
      phone: map['phone'] as String?,
      description: map['description'] as String?,
      openHours: map['openHours'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}