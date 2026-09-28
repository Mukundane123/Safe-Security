import '../utils/datetime_util.dart';

/// A community-submitted status update on an incident - crowd-sourced, public
/// updates (e.g. "police arrived", "smoke has stopped") that other residents
/// can read on the incident's public updates wall.
class CommunityReport {
  final String reportId;
  final String incidentId;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String text;
  final DateTime postedAt;
  final bool verified;

  const CommunityReport({
    required this.reportId,
    required this.incidentId,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.text,
    required this.postedAt,
    this.verified = false,
  });

  Map<String, dynamic> toMap() => {
        'reportId': reportId,
        'incidentId': incidentId,
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': authorRole,
        'text': text,
        'postedAt': postedAt,
        'verified': verified,
      };

  factory CommunityReport.fromMap(Map<String, dynamic> map) {
    return CommunityReport(
      reportId: (map['reportId'] as String?) ?? '',
      incidentId: (map['incidentId'] as String?) ?? '',
      authorId: (map['authorId'] as String?) ?? '',
      authorName: (map['authorName'] as String?) ?? '',
      authorRole: (map['authorRole'] as String?) ?? 'citizen',
      text: (map['text'] as String?) ?? '',
      postedAt: DateTimeUtil.parse(map['postedAt']) ?? DateTime.now(),
      verified: (map['verified'] as bool?) ?? false,
    );
  }
}