import 'dart:async';

import '../models/ai_classification_log.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/chat_message.dart';
import '../models/check_in.dart';
import '../models/community_alert.dart';
import '../models/community_report.dart';
import '../models/emergency_resource.dart';
import '../models/incident.dart';
import '../models/incident_update.dart';
import '../models/notification_preferences.dart';
import '../models/responder_location.dart';
import '../models/safety_zone.dart';
import '../models/sos_alert.dart';
import '../models/sos_location.dart';
import '../models/trusted_contact.dart';
import '../models/withdrawal_code.dart';
import 'repository.dart';
import 'repository_exception.dart';

/// In-memory stand-in for a `report_access` document.
class _DemoWithdrawal {
  final String incidentId;
  final String code;
  final DateTime createdAt;
  const _DemoWithdrawal({
    required this.incidentId,
    required this.code,
    required this.createdAt,
  });
}

/// In-memory implementation used when no Firebase project is configured.
class DemoRepository extends IRepository {
  static const String demoPassword = 'demo1234';

  final List<AppUser> _users = [];
  final List<Incident> _incidents = [];
  final List<SosAlert> _sosAlerts = [];
  final List<AppNotification> _notifications = [];
  final List<TrustedContact> _contacts = [];
  final List<CommunityAlert> _alerts = [];
  final List<ChatMessage> _messages = [];
  final List<CheckIn> _checkIns = [];
  final List<SafetyZone> _zones = [];
  final List<ResponderLocation> _responderLocations = [];
  final List<IncidentUpdate> _incidentUpdates = [];
  final List<CommunityReport> _communityReports = [];
  final List<AiClassificationLog> _aiLogs = [];
  final List<EmergencyResource> _resources = [];
  final Map<String, String> _passwords = {};
  final Map<String, String> _pendingOtps = {};
  final Map<String, _DemoWithdrawal> _withdrawalCodes = {};
  final Map<String, NotificationPreferences> _prefs = {};
  final Map<String, List<SosLocationUpdate>> _sosTrails = {};

  AppUser? _currentUser;
  int _id = 100;

  final _usersCtrl = StreamController<List<AppUser>>.broadcast();
  final _incidentsCtrl = StreamController<List<Incident>>.broadcast();
  final _sosCtrl = StreamController<List<SosAlert>>.broadcast();
  final _notifCtrl = StreamController<List<AppNotification>>.broadcast();
  final _prefsCtrl = StreamController<NotificationPreferences>.broadcast();
  final _aiCtrl = StreamController<List<AiClassificationLog>>.broadcast();
  final _contactsCtrl = StreamController<List<TrustedContact>>.broadcast();
  final _alertsCtrl = StreamController<List<CommunityAlert>>.broadcast();
  final _authCtrl = StreamController<AppUser?>.broadcast();
  final _chatCtrl = StreamController<List<ChatMessage>>.broadcast();
  final _checkInCtrl = StreamController<List<CheckIn>>.broadcast();
  final _zonesCtrl = StreamController<List<SafetyZone>>.broadcast();
  final _responderLocCtrl = StreamController<List<ResponderLocation>>.broadcast();
  final Map<String, StreamController<List<SosLocationUpdate>>> _sosLocCtrls = {};
  final _incidentUpdatesCtrl = StreamController<List<IncidentUpdate>>.broadcast();
  final _communityReportsCtrl = StreamController<List<CommunityReport>>.broadcast();
  final _resourcesCtrl = StreamController<List<EmergencyResource>>.broadcast();

  DemoRepository() {
    _seed();
  }

  static Stream<T> _replay<T>(StreamController<T> ctrl, T Function() current) {
    return Stream<T>.multi((controller) {
      controller.add(current());
      final sub = ctrl.stream.listen(controller.add, onError: controller.addError);
      controller.onCancel = () => sub.cancel();
    });
  }

  String get _nextId => (_id++).toString();

  void _seed() {
    final now = DateTime.now();
    final citizen = AppUser(
      userId: 'u_citizen',
      name: 'Amina Kato',
      phone: '+256 772 000 111',
      email: 'citizen@demo.safeguard',
      role: UserRole.citizen,
      createdDate: now.subtract(const Duration(days: 40)),
      lastLogin: now,
      status: AccountStatus.active,
    );
    final responder = AppUser(
      userId: 'u_responder',
      name: 'Brian Mugisha',
      phone: '+256 772 000 222',
      email: 'responder@demo.safeguard',
      role: UserRole.responder,
      createdDate: now.subtract(const Duration(days: 38)),
      lastLogin: now,
      status: AccountStatus.active,
    );
    final admin = AppUser(
      userId: 'u_admin',
      name: 'Sarah Nankya',
      phone: '+256 772 000 333',
      email: 'admin@demo.safeguard',
      role: UserRole.administrator,
      createdDate: now.subtract(const Duration(days: 45)),
      lastLogin: now,
      status: AccountStatus.active,
    );

    _users.addAll([citizen, responder, admin]);
    for (final user in _users) {
      _passwords[user.email] = demoPassword;
    }

    _incidents.addAll([
      Incident(
        incidentId: 'inc_001',
        reporterId: citizen.userId,
        reporterName: citizen.name,
        category: IncidentCategory.robbery,
        priority: IncidentPriority.urgent,
        description: 'Two men on a motorcycle snatched a bag at Nyaikona market.',
        location: const IncidentLocation(
          latitude: -0.6087,
          longitude: 30.6690,
          label: 'Nyaikona Market',
        ),
        locationLabel: 'Nyaikona Market',
        photoUrls: const [],
        status: IncidentStatus.inProgress,
        assignedResponderId: responder.userId,
        assignedResponderName: responder.name,
        reportedDate: now.subtract(const Duration(minutes: 90)),
        updatedDate: now.subtract(const Duration(minutes: 40)),
      ),
      Incident(
        incidentId: 'inc_002',
        reporterId: citizen.userId,
        reporterName: citizen.name,
        category: IncidentCategory.fire,
        priority: IncidentPriority.urgent,
        description: 'Smoke is coming from a hardware shop near the main junction.',
        location: const IncidentLocation(
          latitude: -0.6198,
          longitude: 30.6612,
          label: 'Ruharo Junction',
        ),
        locationLabel: 'Ruharo Junction',
        photoUrls: const [],
        status: IncidentStatus.pending,
        reportedDate: now.subtract(const Duration(hours: 2)),
        updatedDate: now.subtract(const Duration(hours: 1)),
      ),
      Incident(
        incidentId: 'inc_003',
        reporterId: citizen.userId,
        reporterName: citizen.name,
        category: IncidentCategory.medical,
        priority: IncidentPriority.high,
        description: 'Elderly man collapsed while crossing the street.',
        location: const IncidentLocation(
          latitude: -0.6111,
          longitude: 30.6580,
          label: 'Mbaga Road',
        ),
        locationLabel: 'Mbaga Road',
        photoUrls: const [],
        status: IncidentStatus.resolved,
        assignedResponderId: responder.userId,
        assignedResponderName: responder.name,
        reportedDate: now.subtract(const Duration(days: 1)),
        updatedDate: now.subtract(const Duration(hours: 3)),
        resolvedDate: now.subtract(const Duration(hours: 1)),
      ),
    ]);

    _sosAlerts.add(SosAlert(
      sosId: 'sos_001',
      userId: citizen.userId,
      userName: citizen.name,
      latitude: -0.6132,
      longitude: 30.6651,
      note: 'Please help, someone is following me.',
      status: SosStatus.acknowledged,
      triggeredAt: now.subtract(const Duration(days: 2)),
      notifiedContacts: const ['Mama Grace (+256 772 100 101)'],
      notifiedResponders: const ['Brian Mugisha'],
    ));

    _contacts.addAll([
      TrustedContact(
        id: 'ct_001',
        userId: citizen.userId,
        contactName: 'Mama Grace',
        contactPhone: '+256 772 100 101',
        createdDate: now.subtract(const Duration(days: 30)),
        confirmationStatus: ContactConfirmation.confirmed,
      ),
      TrustedContact(
        id: 'ct_002',
        userId: citizen.userId,
        contactName: 'Uncle Juma',
        contactPhone: '+256 772 100 202',
        createdDate: now.subtract(const Duration(days: 25)),
        confirmationStatus: ContactConfirmation.confirmed,
      ),
    ]);

    _alerts.addAll([
      CommunityAlert(
        alertId: 'al_001',
        title: 'Motorcycle thefts on the rise',
        body: 'Three bikes were stolen around Nyaikona over the weekend.',
        area: 'Nyaikona',
        severity: AlertSeverity.warning,
        issuedBy: admin.userId,
        issuedByName: admin.name,
        issuedAt: now.subtract(const Duration(hours: 26)),
        expiresAt: now.add(const Duration(days: 3)),
        active: true,
      ),
      CommunityAlert(
        alertId: 'al_002',
        title: 'Kakoba Market closure',
        body: 'Kakoba Market will close at 7:00 PM today for routine sanitation.',
        area: 'Whole Division',
        severity: AlertSeverity.info,
        issuedBy: admin.userId,
        issuedByName: admin.name,
        issuedAt: now.subtract(const Duration(hours: 5)),
        expiresAt: now.add(const Duration(hours: 20)),
        active: true,
      ),
    ]);

    _messages.addAll([
      ChatMessage(
        messageId: 'm_001',
        incidentId: 'inc_001',
        senderId: citizen.userId,
        senderName: citizen.name,
        senderRole: citizen.role.value,
        text: 'Hello, I just reported the bag snatching at the market.',
        sentAt: now.subtract(const Duration(minutes: 95)),
      ),
      ChatMessage(
        messageId: 'm_002',
        incidentId: 'inc_001',
        senderId: responder.userId,
        senderName: responder.name,
        senderRole: responder.role.value,
        text: 'On our way. Did you see which direction they went?',
        sentAt: now.subtract(const Duration(minutes: 88)),
      ),
    ]);

    _checkIns.add(CheckIn(
      checkInId: 'ck_001',
      userId: citizen.userId,
      userName: citizen.name,
      destination: 'Kikoni',
      startedAt: now.subtract(const Duration(minutes: 20)),
      expectedMinutes: 45,
      status: CheckInStatus.active,
      waypoints: const [GeoPoint(-0.6101, 30.6662), GeoPoint(-0.6118, 30.6679)],
    ));

    _zones.addAll([
      SafetyZone(
        zoneId: 'z_001',
        name: 'Nyaikona Market late-night watch',
        latitude: -0.6087,
        longitude: 30.6690,
        radiusMeters: 400,
        risk: ZoneRisk.high,
        note: 'Bag-snatching spikes here after 7 PM.',
        createdDate: now.subtract(const Duration(days: 14)),
      ),
      SafetyZone(
        zoneId: 'z_002',
        name: 'Ruharo Junction flood-prone',
        latitude: -0.6198,
        longitude: 30.6612,
        radiusMeters: 350,
        risk: ZoneRisk.normal,
        note: 'Road floods during heavy rain.',
        createdDate: now.subtract(const Duration(days: 9)),
      ),
    ]);

    _responderLocations.add(ResponderLocation(
      responderId: responder.userId,
      responderName: responder.name,
      latitude: -0.6105,
      longitude: 30.6672,
      lastSeen: now.subtract(const Duration(minutes: 2)),
      broadcasting: true,
    ));

    _resources.addAll([
      EmergencyResource(
        resourceId: 'er_001',
        type: EmergencyResourceType.hospital,
        name: 'Kakoba Health Centre',
        phone: '+256 772 900 001',
        description: 'Primary emergency care and trauma stabilization.',
        openHours: '24/7',
        latitude: -0.6120,
        longitude: 30.6550,
      ),
      EmergencyResource(
        resourceId: 'er_002',
        type: EmergencyResourceType.police,
        name: 'Kakoba Police Post',
        phone: '+256 772 900 002',
        description: 'Local police response point for incidents and theft reports.',
        openHours: '24/7',
        latitude: -0.6150,
        longitude: 30.6610,
      ),
    ]);

    _aiLogs.addAll([
      AiClassificationLog(
        logId: 'ai_001',
        incidentId: 'inc_001',
        reporterId: citizen.userId,
        model: 'keywordClassify',
        inputCategory: 'other',
        outputCategory: 'robbery',
        outputSubCategory: 'Theft / robbery',
        outputPriority: 'urgent',
        confidence: 0.79,
        summary: 'Possible robbery or theft reported — caution advised.',
        result: 'ok',
        agreedWithReporter: false,
        overridden: true,
        overriddenCategory: 'assault',
        reviewedBy: 'admin_001',
        durationMs: 412,
        createdAt: now.subtract(const Duration(hours: 9)),
      ),
      AiClassificationLog(
        logId: 'ai_002',
        incidentId: 'inc_003',
        reporterId: citizen.userId,
        model: 'keywordClassify',
        inputCategory: 'medical',
        outputCategory: 'medical',
        outputSubCategory: 'Medical emergency',
        outputPriority: 'urgent',
        confidence: 0.92,
        summary: 'Possible medical emergency — medical responders advised.',
        result: 'ok',
        agreedWithReporter: true,
        overridden: false,
        durationMs: 305,
        createdAt: now.subtract(const Duration(hours: 7)),
      ),
      AiClassificationLog(
        logId: 'ai_003',
        incidentId: 'inc_002',
        reporterId: citizen.userId,
        model: 'keywordClassify',
        inputCategory: 'flood',
        outputCategory: 'flood',
        outputSubCategory: 'Flood / storm damage',
        outputPriority: 'urgent',
        confidence: 0.66,
        summary: 'Flooding or storm damage reported — hazard assessment advised.',
        duplicateOf: 'inc_001',
        result: 'ok',
        agreedWithReporter: true,
        overridden: false,
        durationMs: 1180,
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
      ),
    ]);

    _notifications.addAll([
      AppNotification(
        notificationId: 'n_001',
        recipientId: citizen.userId,
        type: NotificationType.incidentUpdate,
        title: 'Your report is being attended to',
        body: 'Responders updated your incident to resolved.',
        relatedEntityId: 'inc_003',
        deliveryStatus: DeliveryStatus.delivered,
        sentAt: now.subtract(const Duration(hours: 7)),
      ),
      AppNotification(
        notificationId: 'n_002',
        recipientId: responder.userId,
        type: NotificationType.assignment,
        title: 'Incident assigned to you',
        body: 'Incident inc_001 is ready for review.',
        relatedEntityId: 'inc_001',
        deliveryStatus: DeliveryStatus.failed,
        sentAt: now.subtract(const Duration(hours: 3)),
      ),
    ]);
  }

  @override
  bool get isDemo => true;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> get onAuthStateChanged => _replay(_authCtrl, () => _currentUser);

  @override
  Future<AppUser?> signIn(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final match = _users.firstWhere(
      (u) => u.email.toLowerCase() == email.trim().toLowerCase(),
      orElse: () => throw const RepositoryException(
        RepositoryErrorCode.invalidCredentials,
        'No account found for this email.',
      ),
    );
    if (_passwords[match.email] != password) {
      throw const RepositoryException(
        RepositoryErrorCode.invalidCredentials,
        'Incorrect password. Please try again.',
      );
    }
    if (match.status == AccountStatus.suspended) {
      throw const RepositoryException(
        RepositoryErrorCode.accountSuspended,
        'This account has been suspended.',
      );
    }
    _currentUser = match.copyWith(lastLogin: DateTime.now());
    final index = _users.indexWhere((u) => u.userId == match.userId);
    _users[index] = _currentUser!;
    _authCtrl.add(_currentUser);
    return _currentUser;
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (password.length < 6) {
      throw const RepositoryException(
        RepositoryErrorCode.weakPassword,
        'Password must be at least 6 characters.',
      );
    }
    if (_users.any((u) => u.email.toLowerCase() == email.trim().toLowerCase())) {
      throw const RepositoryException(
        RepositoryErrorCode.emailInUse,
        'An account with this email already exists.',
      );
    }
    final user = AppUser(
      userId: 'u_$_nextId',
      name: name.trim(),
      phone: phone.trim(),
      email: email.trim(),
      role: role,
      createdDate: DateTime.now(),
      lastLogin: DateTime.now(),
      status: AccountStatus.active,
    );
    _users.add(user);
    _passwords[user.email] = password;
    _currentUser = user;
    _authCtrl.add(user);
    _emitUsers();
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authCtrl.add(null);
  }

  @override
  Future<void> resetPassword(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!_users.any((u) => u.email.toLowerCase() == email.trim().toLowerCase())) {
      throw const RepositoryException(
        RepositoryErrorCode.invalidCredentials,
        'No account found for this email.',
      );
    }
  }

  @override
  Future<void> updateProfile({String? name, String? phone}) async {
    final user = _currentUser;
    if (user == null) return;
    _currentUser = user.copyWith(name: name ?? user.name, phone: phone ?? user.phone);
    final index = _users.indexWhere((u) => u.userId == user.userId);
    if (index >= 0) _users[index] = _currentUser!;
    _authCtrl.add(_currentUser);
    _emitUsers();
  }

  @override
  Future<void> saveFcmToken(String token) async {}

  @override
  Future<String?> sendPhoneOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final code = (1000 + (_id * 17) % 9000).toString();
    _pendingOtps[phone] = code;
    return code;
  }

  @override
  Future<bool> verifyPhoneOtp(String phone, String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final expected = _pendingOtps[phone];
    if (expected == null || expected != code) return false;
    _pendingOtps.remove(phone);
    final user = _currentUser;
    if (user != null) {
      _currentUser = user.copyWith(phoneVerified: true);
      final idx = _users.indexWhere((u) => u.userId == user.userId);
      if (idx >= 0) _users[idx] = _currentUser!;
      _authCtrl.add(_currentUser);
    }
    return true;
  }

  @override
  Stream<List<AppUser>> watchUsers() => _replay(_usersCtrl, () {
        final list = List<AppUser>.of(_users)
          ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
        return list;
      });

  @override
  Future<void> setUserStatus(String userId, AccountStatus status) async {
    final idx = _users.indexWhere((u) => u.userId == userId);
    if (idx < 0) return;
    _users[idx] = _users[idx].copyWith(status: status);
    if (_currentUser?.userId == userId) {
      _currentUser = _users[idx];
      _authCtrl.add(_currentUser);
    }
    _emitUsers();
  }

  @override
  Future<void> deleteUser(String userId) async {
    _users.removeWhere((u) => u.userId == userId);
    _emitUsers();
  }

  @override
  Future<String?> responderName(String responderId) async {
    return _users.where((u) => u.userId == responderId).firstOrNull?.name;
  }

  @override
  Future<void> setResponderVerification(String userId, ResponderVerification status) async {
    final idx = _users.indexWhere((u) => u.userId == userId);
    if (idx < 0) return;
    _users[idx] = _users[idx].copyWith(verificationStatus: status);
    _emitUsers();
  }

  @override
  Stream<List<Incident>> watchMyIncidents(String reporterId) => _replay(_incidentsCtrl, () {
        final list = _incidents
            .where((i) => i.reporterId == reporterId)
            .toList()
          ..sort((a, b) => b.reportedDate.compareTo(a.reportedDate));
        return list;
      });

  @override
  Stream<List<Incident>> watchAssignedIncidents(String responderId) => _replay(_incidentsCtrl, () {
        final list = _incidents
            .where((i) => i.assignedResponderId == responderId)
            .where((i) => i.status != IncidentStatus.closed)
            .toList()
          ..sort((a, b) => b.reportedDate.compareTo(a.reportedDate));
        return list;
      });

  @override
  Stream<List<Incident>> watchAllIncidents() => _replay(_incidentsCtrl, () {
        final list = List<Incident>.of(_incidents)
          ..sort((a, b) => b.reportedDate.compareTo(a.reportedDate));
        return list;
      });

  @override
  Future<Incident> reportIncident({
    required String category,
    required String description,
    required double latitude,
    required double longitude,
    required String locationLabel,
    List<String> photoPaths = const [],
    String? subCategory,
    String? videoPath,
    String? voiceNotePath,
    bool isAnonymous = false,
  }) async {
    final user = _currentUser;
    if (user == null) {
      throw const RepositoryException(
        RepositoryErrorCode.notSignedIn,
        'You must be signed in to report.',
      );
    }
    final incident = Incident(
      incidentId: 'inc_$_nextId',
      // Matches the live repository: an anonymous report carries no uid.
      reporterId: isAnonymous ? '' : user.userId,
      reporterName: isAnonymous ? 'Anonymous resident' : user.name,
      category: IncidentCategory.fromValue(category),
      subCategory: subCategory,
      priority: _demoPriority(description),
      description: description,
      location: IncidentLocation(latitude: latitude, longitude: longitude, label: locationLabel),
      locationLabel: locationLabel,
      photoUrls: photoPaths,
      videoUrl: videoPath,
      voiceNoteUrl: voiceNotePath,
      isAnonymous: isAnonymous,
      status: IncidentStatus.pending,
      aiSuggestion: AiSuggestion(
        category: category,
        subCategory: subCategory,
        priority: _demoPriority(description).value,
        confidence: 0.8,
        summary: 'Demo AI classification.',
      ),
      reportedDate: DateTime.now(),
      updatedDate: DateTime.now(),
    );
    _incidents.insert(0, incident);
    _emitIncidents();
    return incident;
  }

  @override
  Future<void> updateIncidentStatus(String incidentId, String status, {DateTime? resolvedAt}) async {
    final idx = _incidents.indexWhere((i) => i.incidentId == incidentId);
    if (idx < 0) return;
    final current = _incidents[idx];
    _incidents[idx] = current.copyWith(
      status: IncidentStatus.fromValue(status),
      updatedDate: DateTime.now(),
      resolvedDate: resolvedAt ?? current.resolvedDate,
    );
    _emitIncidents();
  }

  @override
  Future<void> assignIncident(String incidentId, String responderId) async {
    final idx = _incidents.indexWhere((i) => i.incidentId == incidentId);
    if (idx < 0) return;
    final current = _incidents[idx];
    final name = await responderName(responderId) ?? 'Responder';
    _incidents[idx] = current.copyWith(
      assignedResponderId: responderId,
      assignedResponderName: name,
      status: IncidentStatus.assigned,
      updatedDate: DateTime.now(),
    );
    _emitIncidents();
  }

  @override
  Future<void> confirmClassification(String incidentId, {required String category, required String priority, String? subCategory}) async {
    final idx = _incidents.indexWhere((i) => i.incidentId == incidentId);
    if (idx < 0) return;
    final current = _incidents[idx];
    _incidents[idx] = current.copyWith(
      category: IncidentCategory.fromValue(category),
      priority: IncidentPriority.fromValue(priority),
      subCategory: subCategory,
      updatedDate: DateTime.now(),
    );
    _emitIncidents();
  }

  @override
  Future<void> updateIncidentDescription({
    required String incidentId,
    required String description,
  }) async {
    final idx = _incidents.indexWhere((i) => i.incidentId == incidentId);
    if (idx < 0) return;
    if (_incidents[idx].status != IncidentStatus.pending) {
      throw const RepositoryException(
        RepositoryErrorCode.invalidInput,
        'Only a pending report can be edited.',
      );
    }
    _incidents[idx] =
        _incidents[idx].copyWith(description: description, updatedDate: DateTime.now());
    _emitIncidents();
  }

  @override
  Future<WithdrawalCode> issueReportWithdrawalCode({required String incidentId}) async {
    final incident = _incidents.where((i) => i.incidentId == incidentId).firstOrNull;
    if (incident == null) {
      throw const RepositoryException(
        RepositoryErrorCode.notFound,
        'That report no longer exists.',
      );
    }
    if (!incident.isAnonymous) {
      throw const RepositoryException(
        RepositoryErrorCode.invalidInput,
        'A withdrawal code is only issued for anonymous reports.',
      );
    }
    // Reuse an existing code rather than orphaning the previous one. The map is
    // keyed by digest, so the plain code is held on the entry - a concession
    // only the in-memory demo can make, since the real store never keeps it.
    final existing = _withdrawalCodes.values
        .where((w) => w.incidentId == incidentId)
        .firstOrNull;
    if (existing != null) return WithdrawalCode.fromCode(existing.code);

    final code = WithdrawalCode.generate();
    _withdrawalCodes[code.token] = _DemoWithdrawal(
      incidentId: incidentId,
      code: code.code,
      createdAt: DateTime.now(),
    );
    return code;
  }

  @override
  Future<Incident?> findIncidentByWithdrawalCode(String code) async {
    final token = WithdrawalCode.digest(code);
    final entry = _withdrawalCodes[token];
    if (entry == null) return null;
    return _incidents.where((i) => i.incidentId == entry.incidentId).firstOrNull;
  }

  @override
  Future<void> withdrawAnonymousReport({
    required String code,
    required String incidentId,
  }) async {
    final token = WithdrawalCode.digest(code);
    final entry = _withdrawalCodes[token];
    if (entry == null || entry.incidentId != incidentId) {
      throw const RepositoryException(
        RepositoryErrorCode.permission,
        'That code does not match this report.',
      );
    }
    // Mirrors the callable: once responders have the report it is no longer
    // the reporter's to pull.
    final incident =
        _incidents.where((i) => i.incidentId == incidentId).firstOrNull;
    if (incident == null || incident.status != IncidentStatus.pending) {
      throw const RepositoryException(
        RepositoryErrorCode.permission,
        'This report is already being handled and can no longer be withdrawn.',
      );
    }
    _withdrawalCodes.remove(token);
    _incidents.removeWhere((i) => i.incidentId == incidentId);
    _emitIncidents();
  }

  @override
  Future<void> deleteIncident(String incidentId) async {
    _incidents.removeWhere((i) => i.incidentId == incidentId);
    _emitIncidents();
  }

  @override
  Stream<List<IncidentUpdate>> watchIncidentUpdates(String incidentId) => _replay(_incidentUpdatesCtrl, () {
        final list = _incidentUpdates
            .where((u) => u.incidentId == incidentId)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return list;
      });

  @override
  Future<void> recordIncidentUpdate({required String incidentId, required String action, String? detail}) async {
    _incidentUpdates.insert(0, IncidentUpdate(
      updateId: 'iu_$_nextId',
      incidentId: incidentId,
      actorId: _currentUser?.userId ?? 'system',
      actorName: _currentUser?.name ?? 'System',
      action: action,
      detail: detail,
      timestamp: DateTime.now(),
    ));
    _emitIncidentUpdates();
  }

  @override
  Stream<List<CommunityReport>> watchCommunityReports(String incidentId) => _replay(_communityReportsCtrl, () {
        final list = _communityReports
            .where((r) => r.incidentId == incidentId)
            .toList()
          ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
        return list;
      });

  @override
  Future<void> addCommunityReport({required String incidentId, required String text}) async {
    final user = _currentUser;
    if (user == null) {
      throw const RepositoryException(
        RepositoryErrorCode.notSignedIn,
        'Sign in to post a community update.',
      );
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const RepositoryException(
        RepositoryErrorCode.invalidInput,
        'Write something before posting.',
      );
    }
    if (trimmed.length > 280) {
      throw const RepositoryException(
        RepositoryErrorCode.invalidInput,
        'Updates are limited to 280 characters.',
      );
    }
    _communityReports.insert(0, CommunityReport(
      reportId: 'cr_$_nextId',
      incidentId: incidentId,
      authorId: user.userId,
      authorName: user.name,
      authorRole: user.role.label,
      text: trimmed,
      postedAt: DateTime.now(),
      verified: false,
    ));
    _emitCommunityReports();
  }

  @override
  Future<SosAlert> triggerSos({required double latitude, required double longitude, String? note}) async {
    final user = _currentUser ?? _users.first;
    final sos = SosAlert(
      sosId: 'sos_$_nextId',
      userId: user.userId,
      userName: user.name,
      latitude: latitude,
      longitude: longitude,
      note: note,
      status: SosStatus.active,
      triggeredAt: DateTime.now(),
      notifiedContacts: _contacts.where((c) => c.userId == user.userId).map((c) => '${c.contactName} (${c.contactPhone})').toList(),
      notifiedResponders: _users.where((u) => u.role == UserRole.responder).map((u) => u.name).toList(),
    );
    _sosAlerts.insert(0, sos);
    _emitSos();
    return sos;
  }

  @override
  Future<void> verifyCommunityReport(String reportId, {bool verified = true}) async {
    final idx = _communityReports.indexWhere((c) => c.reportId == reportId);
    if (idx < 0) return;
    final c = _communityReports[idx];
    _communityReports[idx] = CommunityReport(
      reportId: c.reportId,
      incidentId: c.incidentId,
      authorId: c.authorId,
      authorName: c.authorName,
      authorRole: c.authorRole,
      text: c.text,
      postedAt: c.postedAt,
      verified: verified,
    );
    _emitCommunityReports();
  }

  @override
  Stream<List<SosAlert>> watchSosAlerts() => _replay(_sosCtrl, () {
        final list = List<SosAlert>.of(_sosAlerts)
          ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
        return list;
      });

  @override
  Stream<List<SosLocationUpdate>> watchSosLocations(String sosId) {
    final ctrl = _sosLocCtrls.putIfAbsent(
      sosId,
      () => StreamController<List<SosLocationUpdate>>.broadcast(),
    );
    return _replay(ctrl, () => List<SosLocationUpdate>.of(_sosTrails[sosId] ?? const []));
  }

  @override
  Future<void> updateSosLocation(String sosId, {required double latitude, required double longitude}) async {
    final trail = _sosTrails.putIfAbsent(sosId, () => []);
    trail.add(SosLocationUpdate(
      sosId: sosId,
      latitude: latitude,
      longitude: longitude,
      capturedAt: DateTime.now(),
    ));
    _emitSosLocations(sosId);
  }

  @override
  Future<void> updateSosStatus(String sosId, String status) async {
    final idx = _sosAlerts.indexWhere((s) => s.sosId == sosId);
    if (idx < 0) return;
    _sosAlerts[idx] = _sosAlerts[idx].copyWith(status: SosStatus.fromValue(status));
    _emitSos();
  }

  @override
  Stream<List<EmergencyResource>> watchEmergencyResources() => _replay(_resourcesCtrl, () => List<EmergencyResource>.of(_resources));

  @override
  Stream<List<AppNotification>> watchNotifications() => _replay(_notifCtrl, () {
        final uid = _currentUser?.userId;
        final list = _notifications
            .where((n) => uid == null || n.recipientId == uid)
            .toList()
          ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
        return list;
      });

  @override
  Future<void> markNotificationRead(String notificationId) async {
    final idx = _notifications.indexWhere((n) => n.notificationId == notificationId);
    if (idx < 0) return;
    _notifications[idx] = _notifications[idx].copyWith(readAt: DateTime.now());
    _emitNotifications();
  }

  @override
  Future<void> addNotification(AppNotification notification, {bool push = false}) async {
    _notifications.insert(0, notification);
    _emitNotifications();
  }

  @override
  Future<void> resendNotification(String notificationId) async {
    final idx = _notifications.indexWhere((n) => n.notificationId == notificationId);
    if (idx < 0) return;
    // Demo delivery always succeeds on the second attempt.
    _notifications[idx] = AppNotification(
      notificationId: _notifications[idx].notificationId,
      recipientId: _notifications[idx].recipientId,
      type: _notifications[idx].type,
      title: _notifications[idx].title,
      body: _notifications[idx].body,
      relatedEntityId: _notifications[idx].relatedEntityId,
      deliveryStatus: DeliveryStatus.delivered,
      sentAt: _notifications[idx].sentAt,
      readAt: _notifications[idx].readAt,
    );
    _emitNotifications();
  }

  @override
  Stream<NotificationPreferences> watchNotificationPreferences() => _replay(_prefsCtrl, () {
        final uid = _currentUser?.userId ?? '';
        return _prefs[uid] ?? const NotificationPreferences();
      });

  @override
  Future<void> saveNotificationPreferences(NotificationPreferences prefs) async {
    _prefs[_currentUser?.userId ?? ''] = prefs;
    _prefsCtrl.add(prefs);
  }

  // ---- AI audit trail (administrators) ----
  @override
  Stream<List<AiClassificationLog>> watchAiClassificationLogs({int limit = 100}) =>
      _replay(_aiCtrl, () {
        final list = List<AiClassificationLog>.of(_aiLogs)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list.take(limit).toList();
      });

  @override
  Stream<List<TrustedContact>> watchTrustedContacts() => _replay(_contactsCtrl, () {
        final uid = _currentUser?.userId;
        return _contacts.where((c) => uid == null || c.userId == uid).toList();
      });

  @override
  Future<void> addTrustedContact({required String name, required String phone, String? contactUserId}) async {
    final user = _currentUser ?? _users.first;
    _contacts.add(TrustedContact(
      id: 'ct_$_nextId',
      userId: user.userId,
      contactName: name,
      contactPhone: phone,
      contactUserId: contactUserId,
      createdDate: DateTime.now(),
      confirmationStatus: ContactConfirmation.pending,
    ));
    _emitContacts();
  }

  @override
  Future<void> removeTrustedContact(String id) async {
    _contacts.removeWhere((c) => c.id == id);
    _emitContacts();
  }

  @override
  Stream<List<CommunityAlert>> watchCommunityAlerts() => _replay(_alertsCtrl, () {
        final list = _alerts.where((a) => a.active).toList()
          ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
        return list;
      });

  @override
  Future<void> broadcastCommunityAlert({required String title, required String body, required String area, required String severity, required int expiresInHours}) async {
    final sender = _currentUser ?? _users.firstWhere((u) => u.role == UserRole.administrator);
    final alert = CommunityAlert(
      alertId: 'al_$_nextId',
      title: title,
      body: body,
      area: area,
      severity: AlertSeverity.fromValue(severity),
      issuedBy: sender.userId,
      issuedByName: sender.name,
      issuedAt: DateTime.now(),
      expiresAt: DateTime.now().add(Duration(hours: expiresInHours)),
      active: true,
    );
    _alerts.insert(0, alert);
    _emitAlerts();
  }

  @override
  Stream<List<ChatMessage>> watchIncidentChat(String incidentId) => _replay(_chatCtrl, () {
        final list = _messages
            .where((m) => m.incidentId == incidentId)
            .toList()
          ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
        return list;
      });

  @override
  Future<void> sendChatMessage({required String incidentId, required String text}) async {
    final user = _currentUser;
    if (user == null || text.trim().isEmpty) return;
    _messages.add(ChatMessage(
      messageId: 'm_$_nextId',
      incidentId: incidentId,
      senderId: user.userId,
      senderName: user.name,
      senderRole: user.role.value,
      text: text.trim(),
      sentAt: DateTime.now(),
    ));
    _emitChat();
  }

  @override
  Stream<List<CheckIn>> watchCheckIns() => _replay(_checkInCtrl, () {
        final list = List<CheckIn>.of(_checkIns)
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        return list;
      });

  @override
  Future<CheckIn> startCheckIn({required String destination, required double latitude, required double longitude, required int expectedMinutes}) async {
    final user = _currentUser ?? _users.first;
    final checkIn = CheckIn(
      checkInId: 'ck_$_nextId',
      userId: user.userId,
      userName: user.name,
      destination: destination,
      startedAt: DateTime.now(),
      expectedMinutes: expectedMinutes,
      status: CheckInStatus.active,
      waypoints: [GeoPoint(latitude, longitude)],
    );
    _checkIns.insert(0, checkIn);
    _emitCheckIns();
    return checkIn;
  }

  @override
  Future<void> updateCheckInLocation(String checkInId, {required double latitude, required double longitude}) async {
    final idx = _checkIns.indexWhere((c) => c.checkInId == checkInId);
    if (idx < 0) return;
    final current = _checkIns[idx];
    _checkIns[idx] = current.copyWith(
      waypoints: [...current.waypoints, GeoPoint(latitude, longitude)],
    );
    _emitCheckIns();
  }

  @override
  Future<void> completeCheckIn(String checkInId, {required bool arrived}) async {
    final idx = _checkIns.indexWhere((c) => c.checkInId == checkInId);
    if (idx < 0) return;
    final current = _checkIns[idx];
    _checkIns[idx] = current.copyWith(
      status: arrived ? CheckInStatus.arrived : CheckInStatus.cancelled,
      completedAt: DateTime.now(),
    );
    _emitCheckIns();
  }

  @override
  Stream<List<SafetyZone>> watchSafetyZones() => _replay(_zonesCtrl, () {
        final list = List<SafetyZone>.of(_zones)
          ..sort((a, b) => b.createdDate.compareTo(a.createdDate));
        return list;
      });

  @override
  Future<void> addSafetyZone({required String name, required double latitude, required double longitude, required double radiusMeters, required String risk, String? note}) async {
    _zones.insert(0, SafetyZone(
      zoneId: 'z_$_nextId',
      name: name,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      risk: ZoneRisk.fromValue(risk),
      note: note,
      createdDate: DateTime.now(),
    ));
    _emitZones();
  }

  @override
  Future<void> removeSafetyZone(String zoneId) async {
    _zones.removeWhere((z) => z.zoneId == zoneId);
    _emitZones();
  }

  @override
  Stream<List<ResponderLocation>> watchResponderLocations() => _replay(_responderLocCtrl, () {
        final uid = _currentUser?.userId;
        return _responderLocations
            .where((r) => r.broadcasting && !r.isStale)
            .where((r) => uid == null || r.responderId != uid)
            .toList();
      });

  @override
  Future<void> updateResponderLocation({required bool broadcasting, required double latitude, required double longitude}) async {
    final user = _currentUser ?? _users.first;
    final entry = ResponderLocation(
      responderId: user.userId,
      responderName: user.name,
      latitude: latitude,
      longitude: longitude,
      lastSeen: DateTime.now(),
      broadcasting: broadcasting,
    );
    final idx = _responderLocations.indexWhere((r) => r.responderId == user.userId);
    if (idx >= 0) {
      _responderLocations[idx] = entry;
    } else if (broadcasting) {
      _responderLocations.add(entry);
    }
    _emitResponderLocations();
  }

  /// Mirrors `keywordClassify()` in `functions/index.js` closely enough for
  /// demo mode: the Cloud Function overwrites this on a live project.
  static const List<String> _urgentWords = [
    'rob', 'robbed', 'robbery', 'thief', 'stolen', 'steal', 'snatch',
    'fire', 'burning', 'smoke',
    'unconscious', 'bleeding', 'injured', 'ambulance', 'heart attack',
    'accident', 'crash', 'collision',
    'assault', 'attacked', 'beaten', 'stabbed',
    'flood', 'flooding', 'landslide',
  ];

  static const List<String> _highWords = [
    'quarrel', 'abuse', 'violence', 'fight', 'brawl', 'disturbance',
    'missing', 'lost', 'abducted', 'kidnapped',
  ];

  static IncidentPriority _demoPriority(String description) {
    final text = description.toLowerCase();
    if (_urgentWords.any(text.contains)) return IncidentPriority.urgent;
    if (_highWords.any(text.contains)) return IncidentPriority.high;
    return IncidentPriority.normal;
  }

  void _emitUsers() => _usersCtrl.add(List<AppUser>.of(_users));
  void _emitIncidents() => _incidentsCtrl.add(List<Incident>.of(_incidents));
  void _emitSos() => _sosCtrl.add(List<SosAlert>.of(_sosAlerts));
  void _emitNotifications() => _notifCtrl.add(List<AppNotification>.of(_notifications));
  void _emitContacts() => _contactsCtrl.add(List<TrustedContact>.of(_contacts));
  void _emitAlerts() => _alertsCtrl.add(List<CommunityAlert>.of(_alerts));
  void _emitChat() => _chatCtrl.add(List<ChatMessage>.of(_messages));
  void _emitCheckIns() => _checkInCtrl.add(List<CheckIn>.of(_checkIns));
  void _emitZones() => _zonesCtrl.add(List<SafetyZone>.of(_zones));
  void _emitResponderLocations() => _responderLocCtrl.add(List<ResponderLocation>.of(_responderLocations));
  void _emitIncidentUpdates() => _incidentUpdatesCtrl.add(List<IncidentUpdate>.of(_incidentUpdates));
  void _emitCommunityReports() => _communityReportsCtrl.add(List<CommunityReport>.of(_communityReports));
  void _emitSosLocations(String sosId) {
    final ctrl = _sosLocCtrls[sosId];
    if (ctrl == null) return;
    ctrl.add(List<SosLocationUpdate>.of(_sosTrails[sosId] ?? const []));
  }
}
