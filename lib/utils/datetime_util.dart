/// Helpers for reading/writing [DateTime] values across plain maps (demo mode,
/// string dates) and Firestore (which uses Timestamp objects).
class DateTimeUtil {
  const DateTimeUtil._();

  static DateTime? parse(Object? value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value != null) {
      try {
        final dynamic v = value;
        final date = v.toDate();
        if (date is DateTime) return date;
      } catch (_) {
        // Not a Firestore Timestamp / no toDate().
      }
    }
    return null;
  }
}