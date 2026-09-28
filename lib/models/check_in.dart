import '../utils/datetime_util.dart';

enum CheckInStatus {
  active('active'),
  arrived('arrived'),
  cancelled('cancelled');

  const CheckInStatus(this.value);
  final String value;

  static CheckInStatus fromValue(Object? value) {
    return CheckInStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => CheckInStatus.active,
    );
  }

  String get label => switch (this) {
        CheckInStatus.active => 'In transit',
        CheckInStatus.arrived => 'Arrived safely',
        CheckInStatus.cancelled => 'Cancelled',
      };
}

/// A tracked journey a citizen broadcasts to their trusted contacts so the
/// community app can flag help when they go off-route or exceed the expected
/// arrival time.
class CheckIn {
  final String checkInId;
  final String userId;
  final String userName;
  final String destination;
  final DateTime startedAt;
  final int expectedMinutes;
  final CheckInStatus status;
  final DateTime? completedAt;
  final List<GeoPoint> waypoints;

  const CheckIn({
    required this.checkInId,
    required this.userId,
    required this.userName,
    required this.destination,
    required this.startedAt,
    required this.expectedMinutes,
    required this.status,
    this.completedAt,
    this.waypoints = const [],
  });

  DateTime get expectedArrival =>
      startedAt.add(Duration(minutes: expectedMinutes));

  bool get isOverdue =>
      status == CheckInStatus.active && DateTime.now().isAfter(expectedArrival);

  CheckIn copyWith({
    CheckInStatus? status,
    DateTime? completedAt,
    List<GeoPoint>? waypoints,
  }) {
    return CheckIn(
      checkInId: checkInId,
      userId: userId,
      userName: userName,
      destination: destination,
      startedAt: startedAt,
      expectedMinutes: expectedMinutes,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      waypoints: waypoints ?? this.waypoints,
    );
  }

  Map<String, dynamic> toMap() => {
        'checkInId': checkInId,
        'userId': userId,
        'userName': userName,
        'destination': destination,
        'startedAt': startedAt,
        'expectedMinutes': expectedMinutes,
        'status': status.value,
        'completedAt': completedAt,
        'waypoints': waypoints.map((w) => w.toMap()).toList(),
      };

  factory CheckIn.fromMap(Map<String, dynamic> map) {
    return CheckIn(
      checkInId: (map['checkInId'] as String?) ?? '',
      userId: (map['userId'] as String?) ?? '',
      userName: (map['userName'] as String?) ?? '',
      destination: (map['destination'] as String?) ?? '',
      startedAt: DateTimeUtil.parse(map['startedAt']) ?? DateTime.now(),
      expectedMinutes: (map['expectedMinutes'] as num?)?.toInt() ?? 0,
      status: CheckInStatus.fromValue(map['status']),
      completedAt: DateTimeUtil.parse(map['completedAt']),
      waypoints: _pointsFrom(map['waypoints']),
    );
  }

  static List<GeoPoint> _pointsFrom(Object? value) {
    if (value is List) {
      return value
          .map((e) => e is Map<String, dynamic>
              ? GeoPoint.fromMap(e)
              : const GeoPoint(0, 0))
          .toList();
    }
    return const [];
  }
}

/// Minimal lat/lng pair used by [CheckIn] waypoints so the model file stays
/// decoupled from any map library.
class GeoPoint {
  final double latitude;
  final double longitude;
  const GeoPoint(this.latitude, this.longitude);

  Map<String, dynamic> toMap() => {'latitude': latitude, 'longitude': longitude};

  factory GeoPoint.fromMap(Map<String, dynamic> map) => GeoPoint(
        (map['latitude'] as num?)?.toDouble() ?? 0,
        (map['longitude'] as num?)?.toDouble() ?? 0,
      );

  @override
  String toString() => '$latitude,$longitude';
}