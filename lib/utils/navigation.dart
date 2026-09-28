import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens turn-by-turn directions to a location.
///
/// Tries the `google.navigation:` scheme first (hands off to Google Maps or
/// the platform maps app), then falls back to the Google Maps web URL. If
/// neither can be opened the failure is logged rather than thrown, because a
/// missing maps app must never interrupt an emergency workflow.
Future<void> openDirections(
  double latitude,
  double longitude, {
  String? label,
}) async {
  final query = label == null || label.isEmpty
      ? '$latitude,$longitude'
      : '$latitude,$longitude ($label)';
  final encodedQuery = Uri.encodeComponent(query);
  final uri = Uri.parse('google.navigation:q=$encodedQuery&mode=d');
  final fallback = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$encodedQuery',
  );
  try {
    if (!await launchUrl(uri) && !await launchUrl(fallback)) {
      debugPrint('No maps app available for $query');
    }
  } catch (e) {
    debugPrint('Could not open directions to $query: $e');
  }
}
