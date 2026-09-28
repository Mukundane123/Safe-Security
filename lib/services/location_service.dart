import 'package:geolocator/geolocator.dart';

import '../config/app_config.dart';

/// Wraps the device GPS so the rest of the app never deals with permission
/// plumbing. Falls back to the last known position (or the case-study
/// reference point) when a live fix is unavailable.
class LocationService {
  const LocationService();

  /// Requests location permission and returns the current position.
  /// Returns `null` when the user denies access.
  Future<Position?> getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return await _lastKnownOrReference();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (_) {
        return await _lastKnownOrReference();
      }
    } catch (_) {
      return await _lastKnownOrReference();
    }
  }

  Future<Position> _lastKnownOrReference() async {
    Position? last;
    try {
      last = await Geolocator.getLastKnownPosition();
    } catch (_) {}
    return last ??
        Position(
          longitude: AppConfig.kakobaLongitude,
          latitude: AppConfig.kakobaLatitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
  }
}