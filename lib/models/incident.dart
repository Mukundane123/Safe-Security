import '../utils/datetime_util.dart';

enum IncidentStatus {
  pending('pending'),
  assigned('assigned'),
  inProgress('in_progress'),
  resolved('resolved'),
  closed('closed'),
  duplicate('duplicate');

  const IncidentStatus(this.value);
  final String value;

  static IncidentStatus fromValue(Object? value) {
    return IncidentStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => IncidentStatus.pending,
    );
  }

  String get label => switch (this) {
        IncidentStatus.pending => 'Pending',
        IncidentStatus.assigned => 'Assigned',
        IncidentStatus.inProgress => 'In Progress',
        IncidentStatus.resolved => 'Resolved',
        IncidentStatus.closed => 'Closed',
        IncidentStatus.duplicate => 'Duplicate',
      };
}

enum IncidentPriority {
  low('low'),
  normal('normal'),
  high('high'),
  urgent('urgent');

  const IncidentPriority(this.value);
  final String value;

  static IncidentPriority fromValue(Object? value) {
    return IncidentPriority.values.firstWhere(
      (p) => p.value == value,
      orElse: () => IncidentPriority.normal,
    );
  }

  String get label => switch (this) {
        IncidentPriority.low => 'Low',
        IncidentPriority.normal => 'Normal',
        IncidentPriority.high => 'High',
        IncidentPriority.urgent => 'Urgent',
      };
}

enum IncidentCategory {
  robbery('robbery', 'Armed Robbery / Theft'),
  fire('fire', 'Fire'),
  medical('medical', 'Medical Emergency'),
  accident('accident', 'Road Accident'),
  domestic('domestic', 'Domestic Quarrel / Violence'),
  suspicious('suspicious', 'Suspicious Activity'),
  assault('assault', 'Assault'),
  fight('fight', 'Fight / Disturbance'),
  missing('missing', 'Missing Person'),
  flood('flood', 'Flood / Storm Damage'),
  other('other', 'Other');

  const IncidentCategory(this.value, this.label);
  final String value;
  final String label;

  static IncidentCategory fromValue(Object? value) {
    return IncidentCategory.values.firstWhere(
      (c) => c.value == value,
      orElse: () => IncidentCategory.other,
    );
  }
}

class IncidentLocation {
  final double latitude;
  final double longitude;
  final String? label;

  const IncidentLocation({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
      };

  factory IncidentLocation.fromMap(Object? map) {
    if (map is Map<String, dynamic>) {
      return IncidentLocation(
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
        label: map['label'] as String?,
      );
    }
    // Firestore GeoPoint / duck-typed location object.
    if (map != null) {
      try {
        final dynamic m = map;
        final lat = m.latitude;
        final lng = m.longitude;
        if (lat != null && lng != null) {
          return IncidentLocation(
            latitude: (lat as num).toDouble(),
            longitude: (lng as num).toDouble(),
          );
        }
      } catch (_) {
        // Graceful fallback below.
      }
    }
    return const IncidentLocation(latitude: 0, longitude: 0);
  }
}

class AiSuggestion {
  final String? category;
  final String? subCategory;
  final String? priority;
  final double confidence;
  final String? summary;
  final String? duplicateOf;

  const AiSuggestion({
    this.category,
    this.subCategory,
    this.priority,
    this.confidence = 0,
    this.summary,
    this.duplicateOf,
  });

  Map<String, dynamic> toMap() => {
        'category': category,
        'subCategory': subCategory,
        'priority': priority,
        'confidence': confidence,
        'summary': summary,
        'duplicateOf': duplicateOf,
      };

  factory AiSuggestion.fromMap(Object? map) {
    if (map is Map<String, dynamic>) {
      return AiSuggestion(
        category: map['category'] as String?,
        subCategory: map['subCategory'] as String?,
        priority: map['priority'] as String?,
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
        summary: map['summary'] as String?,
        duplicateOf: map['duplicateOf'] as String?,
      );
    }
    return const AiSuggestion();
  }
}

class Incident {
  final String incidentId;
  final String reporterId;
  final String reporterName;
  final IncidentCategory category;
  final String? subCategory;
  final IncidentPriority priority;
  final String description;
  final IncidentLocation location;
  final String locationLabel;
  final List<String> photoUrls;
  final String? voiceNoteUrl;
  final String? videoUrl;
  final bool isAnonymous;
  final IncidentStatus status;
  final AiSuggestion aiSuggestion;
  final String? assignedResponderId;
  final String? assignedResponderName;
  final DateTime reportedDate;
  final DateTime updatedDate;
  final DateTime? resolvedDate;

  const Incident({
    required this.incidentId,
    required this.reporterId,
    required this.reporterName,
    required this.category,
    this.subCategory,
    required this.priority,
    required this.description,
    required this.location,
    required this.locationLabel,
    required this.photoUrls,
    this.voiceNoteUrl,
    this.videoUrl,
    this.isAnonymous = false,
    required this.status,
    this.aiSuggestion = const AiSuggestion(),
    this.assignedResponderId,
    this.assignedResponderName,
    required this.reportedDate,
    required this.updatedDate,
    this.resolvedDate,
  });

  Incident copyWith({
    IncidentCategory? category,
    String? subCategory,
    IncidentPriority? priority,
    String? description,
    String? locationLabel,
    IncidentStatus? status,
    AiSuggestion? aiSuggestion,
    String? assignedResponderId,
    String? assignedResponderName,
    DateTime? updatedDate,
    DateTime? resolvedDate,
    String? videoUrl,
    bool? isAnonymous,
  }) {
    return Incident(
      incidentId: incidentId,
      reporterId: reporterId,
      reporterName: reporterName,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      priority: priority ?? this.priority,
      description: description ?? this.description,
      location: location,
      locationLabel: locationLabel ?? this.locationLabel,
      photoUrls: photoUrls,
      voiceNoteUrl: voiceNoteUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      status: status ?? this.status,
      aiSuggestion: aiSuggestion ?? this.aiSuggestion,
      assignedResponderId:
          assignedResponderId ?? this.assignedResponderId,
      assignedResponderName:
          assignedResponderName ?? this.assignedResponderName,
      reportedDate: reportedDate,
      updatedDate: updatedDate ?? this.updatedDate,
      resolvedDate: resolvedDate ?? this.resolvedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'incidentId': incidentId,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'category': category.value,
      'subCategory': subCategory,
      'priority': priority.value,
      'description': description,
      'location': location.toMap(),
      'locationLabel': locationLabel,
      'photoUrls': photoUrls,
      'voiceNoteUrl': voiceNoteUrl,
      'videoUrl': videoUrl,
      'isAnonymous': isAnonymous,
      'status': status.value,
      'aiSuggestion': aiSuggestion.toMap(),
      'assignedResponderId': assignedResponderId,
      'assignedResponderName': assignedResponderName,
      'reportedAt': reportedDate,
      'updatedAt': updatedDate,
      'resolvedAt': resolvedDate,
    };
  }

  factory Incident.fromMap(Map<String, dynamic> map) {
    final anonymous = (map['isAnonymous'] as bool?) ?? false;
    final rawName = (map['reporterName'] as String?) ?? '';
    return Incident(
      incidentId: (map['incidentId'] as String?) ?? '',
      reporterId: (map['reporterId'] as String?) ?? '',
      reporterName: anonymous ? 'Anonymous resident' : rawName,
      category: IncidentCategory.fromValue(map['category']),
      subCategory: map['subCategory'] as String?,
      priority: IncidentPriority.fromValue(map['priority']),
      description: (map['description'] as String?) ?? '',
      location: IncidentLocation.fromMap(map['location']),
      locationLabel: (map['locationLabel'] as String?) ?? '',
      photoUrls: _stringList(map['photoUrls']),
      voiceNoteUrl: map['voiceNoteUrl'] as String?,
      videoUrl: map['videoUrl'] as String?,
      isAnonymous: anonymous,
      status: IncidentStatus.fromValue(map['status']),
      aiSuggestion: AiSuggestion.fromMap(map['aiSuggestion']),
      assignedResponderId: map['assignedResponderId'] as String?,
      assignedResponderName: map['assignedResponderName'] as String?,
      reportedDate: DateTimeUtil.parse(map['reportedAt']) ?? DateTime.now(),
      updatedDate: DateTimeUtil.parse(map['updatedAt']) ?? DateTime.now(),
      resolvedDate: DateTimeUtil.parse(map['resolvedAt']),
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }
}