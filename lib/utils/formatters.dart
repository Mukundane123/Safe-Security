import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final DateFormat _dateTime = DateFormat('d MMM yyyy, h:mm a');
  static final DateFormat _date = DateFormat('d MMM yyyy');
  static final DateFormat _time = DateFormat('h:mm a');

  static String dateTime(DateTime dt) => _dateTime.format(dt.toLocal());
  static String date(DateTime dt) => _date.format(dt.toLocal());
  static String time(DateTime dt) => _time.format(dt.toLocal());

  /// "just now", "5m ago", "2h ago", "3d ago", then fall back to a date.
  static String relative(DateTime dt) {
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _date.format(dt.toLocal());
  }

  static String reference(String id) => id.toUpperCase().replaceFirst('INC', 'REF');

  /// Human-readable coordinate pair.
  static String coords(double lat, double lng) =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}