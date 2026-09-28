import 'dart:math';

import '../models/safety_zone.dart';

/// Great-circle distance between two coordinates in kilometres.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = pow(sin(dLat / 2), 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * r * asin(sqrt(a));
}

/// Distance between a coordinate pair and a [SafetyZone]'s center, in kilometres.
double distanceKmToZone(double lat, double lon, SafetyZone zone) =>
    haversineKm(lat, lon, zone.latitude, zone.longitude);

/// True when [lat]/[lon] fall inside [zone]'s radius.
bool isWithinZone(double lat, double lon, SafetyZone zone) =>
    distanceKmToZone(lat, lon, zone) <= zone.radiusMeters / 1000;

double _rad(double deg) => deg * pi / 180;