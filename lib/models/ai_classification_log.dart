import '../utils/datetime_util.dart';

/// One automated classification decision, as written by the backend
/// `classifyIncident` Cloud Function. Administrators read this to answer
/// "why did the app label this report the way it did, and did a human
/// disagree?".
class AiClassificationLog {
  final String logId;
  final String incidentId;
  final String? reporterId;
  final String model;
  final String? inputCategory;
  final String outputCategory;
  final String? outputSubCategory;
  final String? outputPriority;
  final double confidence;
  final String? summary;
  final String? duplicateOf;
  final String result;
  final bool agreedWithReporter;
  final bool overridden;
  final String? overriddenCategory;
  final String? reviewedBy;
  final int durationMs;
  final DateTime createdAt;

  const AiClassificationLog({
    required this.logId,
    required this.incidentId,
    this.reporterId,
    required this.model,
    this.inputCategory,
    required this.outputCategory,
    this.outputSubCategory,
    this.outputPriority,
    required this.confidence,
    this.summary,
    this.duplicateOf,
    required this.result,
    required this.agreedWithReporter,
    required this.overridden,
    this.overriddenCategory,
    this.reviewedBy,
    required this.durationMs,
    required this.createdAt,
  });

  /// True when a human changed what the classifier decided.
  bool get wasCorrected => overridden && overriddenCategory != null;

  AiClassificationLog copyWith({bool? overridden, String? overriddenCategory}) {
    return AiClassificationLog(
      logId: logId,
      incidentId: incidentId,
      reporterId: reporterId,
      model: model,
      inputCategory: inputCategory,
      outputCategory: outputCategory,
      outputSubCategory: outputSubCategory,
      outputPriority: outputPriority,
      confidence: confidence,
      summary: summary,
      duplicateOf: duplicateOf,
      result: result,
      agreedWithReporter: agreedWithReporter,
      overridden: overridden ?? this.overridden,
      overriddenCategory: overriddenCategory ?? this.overriddenCategory,
      reviewedBy: reviewedBy,
      durationMs: durationMs,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'logId': logId,
        'incidentId': incidentId,
        'reporterId': reporterId,
        'model': model,
        'inputCategory': inputCategory,
        'outputCategory': outputCategory,
        'outputSubCategory': outputSubCategory,
        'outputPriority': outputPriority,
        'confidence': confidence,
        'summary': summary,
        'duplicateOf': duplicateOf,
        'result': result,
        'agreedWithReporter': agreedWithReporter,
        'overridden': overridden,
        'overriddenCategory': overriddenCategory,
        'reviewedBy': reviewedBy,
        'durationMs': durationMs,
        'createdAt': createdAt,
      };

  factory AiClassificationLog.fromMap(Map<String, dynamic> map) {
    final rawConfidence = map['confidence'];
    final rawDuration = map['durationMs'];
    return AiClassificationLog(
      logId: (map['logId'] as String?) ?? '',
      incidentId: (map['incidentId'] as String?) ?? '',
      reporterId: map['reporterId'] as String?,
      model: (map['model'] as String?) ?? 'unknown',
      inputCategory: map['inputCategory'] as String?,
      outputCategory: (map['outputCategory'] as String?) ?? 'other',
      outputSubCategory: map['outputSubCategory'] as String?,
      outputPriority: map['outputPriority'] as String?,
      confidence:
          rawConfidence is num ? rawConfidence.toDouble() : 0.0,
      summary: map['summary'] as String?,
      duplicateOf: map['duplicateOf'] as String?,
      result: (map['result'] as String?) ?? 'ok',
      agreedWithReporter: (map['agreedWithReporter'] as bool?) ?? true,
      overridden: (map['overridden'] as bool?) ?? false,
      overriddenCategory: map['overriddenCategory'] as String?,
      reviewedBy: map['reviewedBy'] as String?,
      durationMs: rawDuration is num ? rawDuration.toInt() : 0,
      createdAt: DateTimeUtil.parse(map['createdAt']) ?? DateTime.now(),
    );
  }
}
