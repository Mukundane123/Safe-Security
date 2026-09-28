import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/ai_classification_log.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/chat_message.dart';
import '../models/check_in.dart' hide GeoPoint;
import '../models/check_in.dart' as models show GeoPoint;
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
import 'repository.dart';
import 'repository_exception.dart';

/// Production implementation backed by Firebase Auth, Cloud Firestore,
/// Cloud Storage and Cloud Messaging. Notifications and AI classification are
/// produced by the Cloud Functions in the `functions/` folder.
class FirebaseRepository extends IRepository {
  final fb.FirebaseAuth fbAuth;
  final FirebaseFirestore db;
  final FirebaseStorage storage;

  AppUser? _currentUser;
  final _authCtrl = StreamController<AppUser?>.broadcast();
  final Map<String, String> _pendingOtps = {};
  StreamSubscription<fb.User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  FirebaseRepository({
    required FirebaseApp app,
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : fbAuth = auth ?? fb.FirebaseAuth.instanceFor(app: app),
        db = firestore ?? FirebaseFirestore.instanceFor(app: app),
        storage = storage ?? FirebaseStorage.instanceFor(app: app) {
    _authSub = fbAuth.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(fb.User? fbUser) async {
    _profileSub?.cancel();
    _profileSub = null;
    if (fbUser == null) {
      _currentUser = null;
      _authCtrl.add(null);
      return;
    }
    _profileSub = db
        .collection('users')
        .doc(fbUser.uid)
        .snapshots()
        .listen((snap) {
      if (snap.exists) {
        _currentUser = AppUser.fromMap(snap.data()!);
      } else {
        _currentUser = AppUser(
          userId: fbUser.uid,
          name: fbUser.displayName ?? fbUser.email ?? 'User',
          phone: fbUser.phoneNumber ?? '',
          email: fbUser.email ?? '',
          role: UserRole.citizen,
          createdDate: DateTime.now(),
          lastLogin: DateTime.now(),
          status: AccountStatus.active,
        );
      }
      _authCtrl.add(_currentUser);
    });
  }

  @override
  bool get isDemo => false;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> get onAuthStateChanged => _authCtrl.stream;

  // ---- Authentication ----
  @override
  Future<AppUser?> signIn(String email, String password) async {
    final fb.UserCredential cred;
    try {
      cred = await fbAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      throw RepositoryException.from(e);
    }
    final snap = await db.collection('users').doc(cred.user!.uid).get();
    if (snap.exists) {
      final user = AppUser.fromMap(snap.data()!);
      if (user.status == AccountStatus.suspended) {
        await fbAuth.signOut();
        throw const RepositoryException(
          RepositoryErrorCode.accountSuspended,
          'This account has been suspended.',
        );
      }
      return user;
    }
    return AppUser(
      userId: cred.user!.uid,
      name: cred.user!.displayName ?? email,
      phone: '',
      email: cred.user!.email ?? email,
      role: UserRole.citizen,
      createdDate: DateTime.now(),
      lastLogin: DateTime.now(),
      status: AccountStatus.active,
    );
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final fb.UserCredential cred;
    try {
      cred = await fbAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      throw RepositoryException.from(e);
    }
    final user = AppUser(
      userId: cred.user!.uid,
      name: name.trim(),
      phone: phone.trim(),
      email: email.trim(),
      role: role,
      createdDate: DateTime.now(),
      lastLogin: DateTime.now(),
      status: AccountStatus.active,
    );
    await db.collection('users').doc(user.userId).set(user.toMap());
    return user;
  }

  @override
  Future<void> signOut() async {
    await fbAuth.signOut();
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await fbAuth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw RepositoryException.from(e);
    }
  }

  @override
  Future<void> updateProfile({String? name, String? phone}) async {
    final user = fbAuth.currentUser;
    if (user == null) return;
    final map = <String, dynamic>{};
    if (name != null) {
      map['name'] = name.trim();
      if (user.displayName == null) await user.updateDisplayName(name.trim());
    }
    if (phone != null) map['phone'] = phone.trim();
    if (map.isNotEmpty) {
      await db.collection('users').doc(user.uid).update(map);
    }
  }

  @override
  Future<void> saveFcmToken(String token) async {
    final user = fbAuth.currentUser;
    if (user == null) return;
    await db
        .collection('users')
        .doc(user.uid)
        .set({'fcmToken': token, 'tokenUpdatedAt': DateTime.now()}, SetOptions(merge: true));
  }

  // ---- Admin / users ----
  @override
  Stream<List<AppUser>> watchUsers() {
    return db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => AppUser.fromMap(d.data())).toList());
  }

  @override
  Future<void> setUserStatus(String userId, AccountStatus status) async {
    await db.collection('users').doc(userId).update({'status': status.value});
  }

  @override
  Future<void> deleteUser(String userId) async {
    await db.collection('users').doc(userId).delete();
  }

  @override
  Future<String?> responderName(String responderId) async {
    final snap =
        await db.collection('users').doc(responderId).get();
    if (!snap.exists) return null;
    return snap.data()!['name'] as String?;
  }

  // ---- Incidents ----
  @override
  Stream<List<Incident>> watchMyIncidents(String reporterId) {
    return db
        .collection('incidents')
        .where('reporterId', isEqualTo: reporterId)
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map(_incidentsFrom);
  }

  @override
  Stream<List<Incident>> watchAssignedIncidents(String responderId) {
    return db
        .collection('incidents')
        .where('assignedResponderId', isEqualTo: responderId)
        .where('status', whereNotIn: [IncidentStatus.closed.value])
        .snapshots()
        .map(_incidentsFrom);
  }

  @override
  Stream<List<Incident>> watchAllIncidents() {
    return db
        .collection('incidents')
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map(_incidentsFrom);
  }

  List<Incident> _incidentsFrom(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map((d) => Incident.fromMap(d.data())).toList();

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
    final user = fbAuth.currentUser;
    if (user == null) {
      throw const RepositoryException(
        RepositoryErrorCode.notSignedIn,
        'You must be signed in to report.',
      );
    }
    final urls = <String>[];
    for (final path in photoPaths) {
      if (path.startsWith('http')) {
        urls.add(path);
        continue;
      }
      final ref = storage
          .ref('incidents/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      try {
        final upload = await ref.putFile(
          File(path),
          SettableMetadata(contentType: 'image/jpeg'),
        );
        urls.add(await upload.ref.getDownloadURL());
      } catch (e) {
        debugPrint('reportIncident: photo upload failed ($path): $e');
      }
    }
    String? voiceUrl;
    if (voiceNotePath != null && !voiceNotePath.startsWith('http')) {
      try {
        final ref = storage.ref(
            'incidents/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.m4a');
        final upload = await ref.putFile(
          File(voiceNotePath),
          SettableMetadata(contentType: 'audio/mp4'),
        );
        voiceUrl = await upload.ref.getDownloadURL();
      } catch (e) {
        debugPrint('reportIncident: voice note upload failed: $e');
      }
    }
    final doc = db.collection('incidents').doc();
    final incident = Incident(
      incidentId: doc.id,
      reporterId: user.uid,
      reporterName: user.displayName ?? (await _userName(user.uid)) ?? 'User',
      category: IncidentCategory.fromValue(category),
      subCategory: subCategory,
      priority: IncidentPriority.normal,
      description: description,
      location: IncidentLocation(latitude: latitude, longitude: longitude, label: locationLabel),
      locationLabel: locationLabel,
      photoUrls: urls,
      videoUrl: videoPath,
      voiceNoteUrl: voiceUrl,
      isAnonymous: isAnonymous,
      status: IncidentStatus.pending,
      reportedDate: DateTime.now(),
      updatedDate: DateTime.now(),
    );
    await doc.set(_toDb(incident.toMap()));
    return incident;
  }

  Future<String?> _userName(String uid) async {
    final snap = await db.collection('users').doc(uid).get();
    return snap.exists ? snap.data()!['name'] as String? : null;
  }

  @override
  Future<void> updateIncidentStatus(
    String incidentId,
    String status, {
    DateTime? resolvedAt,
  }) async {
    final map = <String, dynamic>{
      'status': status,
      'updatedAt': DateTime.now(),
    };
    if (resolvedAt != null) map['resolvedAt'] = resolvedAt;
    await db.collection('incidents').doc(incidentId).update(_toDb(map));
  }

  @override
  Future<void> assignIncident(String incidentId, String responderId) async {
    final admin = fbAuth.currentUser;
    await db.collection('incidents').doc(incidentId).update(_toDb({
      'assignedResponderId': responderId,
      'status': IncidentStatus.assigned.value,
      'updatedAt': DateTime.now(),
    }));
    final assignment = db.collection('assignments').doc();
    await assignment.set({
      'assignmentId': assignment.id,
      'incidentId': incidentId,
      'responderId': responderId,
      'assignedBy': admin?.uid ?? '',
      'assignedAt': DateTime.now(),
      'status': 'active',
    });
  }

  @override
  Future<void> confirmClassification(
    String incidentId, {
    required String category,
    required String priority,
    String? subCategory,
  }) async {
    final map = <String, dynamic>{
      'category': category,
      'priority': priority,
      'subCategory': subCategory,
      'updatedAt': DateTime.now(),
      // Recorded so the AI audit log can show who overrode the classifier.
      'aiSuggestionConfirmedBy': fbAuth.currentUser?.uid,
      'aiSuggestionConfirmedAt': DateTime.now(),
    };
    await db.collection('incidents').doc(incidentId).update(map);
  }

  @override
  Future<void> deleteIncident(String incidentId) async {
    await db.collection('incidents').doc(incidentId).delete();
  }

  @override
  Future<void> updateIncidentDescription({
    required String incidentId,
    required String description,
  }) async {
    final uid = fbAuth.currentUser?.uid;
    if (uid == null) {
      throw const RepositoryException(
        RepositoryErrorCode.notSignedIn,
        'You must be signed in to edit a report.',
      );
    }
    await db.collection('incidents').doc(incidentId).update({
      'description': description,
      'updatedAt': DateTime.now(),
    });
  }

  @override
  Stream<List<IncidentUpdate>> watchIncidentUpdates(String incidentId) {
    return db
        .collection('incident_updates')
        .where('incidentId', isEqualTo: incidentId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => IncidentUpdate.fromMap(d.data())).toList());
  }

  @override
  Future<void> recordIncidentUpdate({
    required String incidentId,
    required String action,
    String? detail,
  }) async {
    final user = fbAuth.currentUser;
    final doc = db.collection('incident_updates').doc();
    await doc.set(_toDb({
      'updateId': doc.id,
      'incidentId': incidentId,
      'actorId': user?.uid ?? 'system',
      'actorName': user?.displayName ?? 'System',
      'action': action,
      'detail': detail,
      'timestamp': DateTime.now(),
    }));
  }

  @override
  Future<void> verifyCommunityReport(String reportId, {bool verified = true}) async {
    await db
        .collection('community_reports')
        .doc(reportId)
        .update({'verified': verified});
  }

  @override
  Stream<List<CommunityReport>> watchCommunityReports(String incidentId) {
    return db
        .collection('community_reports')
        .where('incidentId', isEqualTo: incidentId)
        .orderBy('postedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => CommunityReport.fromMap(d.data())).toList());
  }

  @override
  Future<void> addCommunityReport({
    required String incidentId,
    required String text,
  }) async {
    final user = fbAuth.currentUser;
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
    final doc = db.collection('community_reports').doc();
    await doc.set(_toDb({
      'reportId': doc.id,
      'incidentId': incidentId,
      'authorId': user.uid,
      'authorName': user.displayName ?? 'Community member',
      'authorRole': _currentUser?.role.value ?? 'citizen',
      'text': trimmed,
      'postedAt': DateTime.now(),
      'verified': false,
    }));
  }

  @override
  Future<String?> sendPhoneOtp(String phone) async {
    final code = (1000 + DateTime.now().millisecondsSinceEpoch % 9000).toString();
    _pendingOtps[phone] = code;
    return code;
  }

  @override
  Future<bool> verifyPhoneOtp(String phone, String code) async {
    final expected = _pendingOtps[phone];
    if (expected == null || expected != code) return false;
    _pendingOtps.remove(phone);
    return true;
  }

  @override
  Future<void> setResponderVerification(
    String userId,
    ResponderVerification status,
  ) async {
    await db.collection('users').doc(userId).update({'verificationStatus': status.value});
  }

  @override
  Stream<List<SosLocationUpdate>> watchSosLocations(String sosId) {
    return db
        .collection('sos_locations')
        .where('sosId', isEqualTo: sosId)
        .orderBy('capturedAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => SosLocationUpdate.fromMap(d.data())).toList());
  }

  @override
  Future<void> updateSosLocation(
    String sosId, {
    required double latitude,
    required double longitude,
  }) async {
    final user = fbAuth.currentUser;
    if (user == null) {
      throw const RepositoryException(
        RepositoryErrorCode.notSignedIn,
        'You must be signed in to share your location.',
      );
    }
    final doc = db.collection('sos_locations').doc();
    await doc.set(_toDb({
      'sosId': sosId,
      'userId': user.uid,
      'latitude': latitude,
      'longitude': longitude,
      'capturedAt': DateTime.now(),
    }));
  }

  @override
  Future<void> updateSosStatus(String sosId, String status) async {
    await db.collection('sos_alerts').doc(sosId).update({'status': status});
  }

  @override
  Stream<List<EmergencyResource>> watchEmergencyResources() {
    return db
        .collection('emergency_resources')
        .snapshots()
        .map((s) => s.docs.map((d) => EmergencyResource.fromMap(d.data())).toList());
  }

  // ---- SOS ----
  @override
  Future<SosAlert> triggerSos({
    required double latitude,
    required double longitude,
    String? note,
  }) async {
    final user = fbAuth.currentUser;
    if (user == null) {
      throw const RepositoryException(
        RepositoryErrorCode.notSignedIn,
        'You must be signed in to send an SOS.',
      );
    }
    final doc = db.collection('sos_alerts').doc();
    final alert = SosAlert(
      sosId: doc.id,
      userId: user.uid,
      userName: user.displayName ?? (await _userName(user.uid)) ?? 'User',
      latitude: latitude,
      longitude: longitude,
      note: note,
      status: SosStatus.active,
      triggeredAt: DateTime.now(),
      notifiedContacts: const [],
      notifiedResponders: const [],
    );
    await doc.set(_toDb(alert.toMap()));
    return alert;
  }

  @override
  Stream<List<SosAlert>> watchSosAlerts() {
    return db
        .collection('sos_alerts')
        .orderBy('triggeredAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => SosAlert.fromMap(d.data())).toList());
  }

  // ---- Notifications ----
  @override
  Stream<List<AppNotification>> watchNotifications() {
    final uid = fbAuth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return db
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => AppNotification.fromMap(d.data())).toList());
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    await db
        .collection('notifications')
        .doc(notificationId)
        .update({'readAt': DateTime.now()});
  }

  @override
  Future<void> addNotification(
    AppNotification notification, {
    bool push = false,
  }) async {
    await db
        .collection('notifications')
        .doc(notification.notificationId)
        .set(_toDb(notification.toMap()));
  }

  @override
  Future<void> resendNotification(String notificationId) async {
    final uid = fbAuth.currentUser?.uid;
    if (uid == null) {
      throw const RepositoryException(
        RepositoryErrorCode.notSignedIn,
        'You must be signed in to resend a notification.',
      );
    }
    // The backend watches this field and re-attempts the FCM push.
    await db.collection('notifications').doc(notificationId).update({
      'deliveryStatus': DeliveryStatus.pending.value,
      'resendRequestedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---- Notification preferences ----
  @override
  Stream<NotificationPreferences> watchNotificationPreferences() async* {
    final uid = fbAuth.currentUser?.uid;
    if (uid == null) {
      yield const NotificationPreferences();
      return;
    }
    final ref = db.collection('users').doc(uid);
    yield NotificationPreferences.fromMap(
      (await ref.get()).data()?['notificationPreferences'],
    );
    await for (final snap in ref.snapshots()) {
      yield NotificationPreferences.fromMap(
        snap.data()?['notificationPreferences'],
      );
    }
  }

  @override
  Future<void> saveNotificationPreferences(NotificationPreferences prefs) async {
    final uid = fbAuth.currentUser?.uid;
    if (uid == null) {
      throw const RepositoryException(
        RepositoryErrorCode.notSignedIn,
        'You must be signed in to change notification settings.',
      );
    }
    await db
        .collection('users')
        .doc(uid)
        .update({'notificationPreferences': prefs.toMap()});
  }

  // ---- AI audit trail (administrators) ----
  @override
  Stream<List<AiClassificationLog>> watchAiClassificationLogs({int limit = 100}) {
    return db
        .collection('ai_classification_log')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => AiClassificationLog.fromMap(d.data())).toList());
  }

  // ---- Trusted contacts ----
  @override
  Stream<List<TrustedContact>> watchTrustedContacts() {
    final uid = fbAuth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return db
        .collection('trusted_contacts')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map((d) => TrustedContact.fromMap(d.data())).toList());
  }

  @override
  Future<void> addTrustedContact({
    required String name,
    required String phone,
    String? contactUserId,
  }) async {
    final user = fbAuth.currentUser;
    if (user == null) return;
    final doc = db.collection('trusted_contacts').doc();
    await doc.set({
      'id': doc.id,
      'userId': user.uid,
      'contactName': name.trim(),
      'contactPhone': phone.trim(),
      'contactUserId': contactUserId,
      'createdAt': DateTime.now(),
      'confirmationStatus': ContactConfirmation.pending.value,
    });
  }

  @override
  Future<void> removeTrustedContact(String id) async {
    await db.collection('trusted_contacts').doc(id).delete();
  }

  // ---- Community alerts ----
  @override
  Stream<List<CommunityAlert>> watchCommunityAlerts() {
    return db
        .collection('community_alerts')
        .where('active', isEqualTo: true)
        .orderBy('issuedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => CommunityAlert.fromMap(d.data())).toList());
  }

  @override
  Future<void> broadcastCommunityAlert({
    required String title,
    required String body,
    required String area,
    required String severity,
    required int expiresInHours,
  }) async {
    final admin = fbAuth.currentUser;
    final doc = db.collection('community_alerts').doc();
    await doc.set(_toDb({
      'alertId': doc.id,
      'title': title.trim(),
      'body': body.trim(),
      'area': area.trim(),
      'severity': severity,
      'issuedBy': admin?.uid ?? '',
      'issuedByName': _currentUser?.name ?? '',
      'issuedAt': DateTime.now(),
      'expiresAt': DateTime.now().add(Duration(hours: expiresInHours)),
      'active': true,
    }));
  }

  // ---- Incident chat ----
  @override
  Stream<List<ChatMessage>> watchIncidentChat(String incidentId) {
    return db
        .collection('incident_chat')
        .doc(incidentId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => ChatMessage.fromMap(d.data())).toList());
  }

  @override
  Future<void> sendChatMessage({
    required String incidentId,
    required String text,
  }) async {
    final user = fbAuth.currentUser;
    if (user == null || text.trim().isEmpty) return;
    final doc = db
        .collection('incident_chat')
        .doc(incidentId)
        .collection('messages')
        .doc();
    await doc.set(_toDb({
      'messageId': doc.id,
      'incidentId': incidentId,
      'senderId': user.uid,
      'senderName': user.displayName ?? (await _userName(user.uid)) ?? 'User',
      'senderRole': _currentUser?.role.value ?? 'citizen',
      'text': text.trim(),
      'sentAt': DateTime.now(),
    }));
  }

  // ---- Safe check-in ----
  @override
  Stream<List<CheckIn>> watchCheckIns() {
    final uid = fbAuth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return db
        .collection('check_ins')
        .where('userId', isEqualTo: uid)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => CheckIn.fromMap(d.data())).toList());
  }

  @override
  Future<CheckIn> startCheckIn({
    required String destination,
    required double latitude,
    required double longitude,
    required int expectedMinutes,
  }) async {
    final user = fbAuth.currentUser;
    if (user == null) {
      throw const RepositoryException(
        RepositoryErrorCode.notSignedIn,
        'Sign in to start a check-in.',
      );
    }
    final doc = db.collection('check_ins').doc();
    final checkIn = CheckIn(
      checkInId: doc.id,
      userId: user.uid,
      userName: user.displayName ?? (await _userName(user.uid)) ?? 'User',
      destination: destination.trim(),
      startedAt: DateTime.now(),
      expectedMinutes: expectedMinutes,
      status: CheckInStatus.active,
      waypoints: [models.GeoPoint(latitude, longitude)],
    );
    await doc.set(_toDb(checkIn.toMap()));
    return checkIn;
  }

  @override
  Future<void> updateCheckInLocation(
    String checkInId, {
    required double latitude,
    required double longitude,
  }) async {
    final doc = db.collection('check_ins').doc(checkInId);
    final snap = await doc.get();
    if (!snap.exists) return;
    final current = CheckIn.fromMap(snap.data()!);
    final waypoints = [...current.waypoints, models.GeoPoint(latitude, longitude)];
    await doc.update({'waypoints': _toDb(waypoints.map((w) => w.toMap()).toList())});
  }

  @override
  Future<void> completeCheckIn(String checkInId, {required bool arrived}) async {
    await db.collection('check_ins').doc(checkInId).update({
      'status': arrived ? CheckInStatus.arrived.value : CheckInStatus.cancelled.value,
      'completedAt': DateTime.now(),
    });
  }

  // ---- Safety zones ----
  @override
  Stream<List<SafetyZone>> watchSafetyZones() {
    return db
        .collection('safety_zones')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => SafetyZone.fromMap(d.data())).toList());
  }

  @override
  Future<void> addSafetyZone({
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required String risk,
    String? note,
  }) async {
    final doc = db.collection('safety_zones').doc();
    final user = fbAuth.currentUser;
    if (user == null) {
      throw const RepositoryException(
        RepositoryErrorCode.notSignedIn,
        'Sign in to save a safety zone.',
      );
    }
    await doc.set(_toDb({
      'zoneId': doc.id,
      'userId': user.uid,
      'name': name.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'risk': risk,
      'note': note,
      'createdAt': DateTime.now(),
    }));
  }

  @override
  Future<void> removeSafetyZone(String zoneId) async {
    await db.collection('safety_zones').doc(zoneId).delete();
  }

  // ---- Responder live location ----
  @override
  Stream<List<ResponderLocation>> watchResponderLocations() {
    final uid = fbAuth.currentUser?.uid;
    return db
        .collection('responder_locations')
        .where('broadcasting', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ResponderLocation.fromMap(d.data()))
            .where((r) => uid == null || r.responderId != uid)
            .toList());
  }

  @override
  Future<void> updateResponderLocation({
    required bool broadcasting,
    required double latitude,
    required double longitude,
  }) async {
    final user = fbAuth.currentUser;
    if (user == null) return;
    final doc = db.collection('responder_locations').doc(user.uid);
    final name = user.displayName ?? (await _userName(user.uid)) ?? 'Responder';
    await doc.set(_toDb({
      'responderId': user.uid,
      'responderName': name,
      'latitude': latitude,
      'longitude': longitude,
      'lastSeen': DateTime.now(),
      'broadcasting': broadcasting,
    }));
  }

  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    _authCtrl.close();
  }

  /// Recursively converts Dart-native values to Firestore-friendly values
  /// (DateTime -> Timestamp, IncidentLocation -> GeoPoint).
  static dynamic _toDb(Object value) {
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is IncidentLocation) {
      return GeoPoint(value.latitude, value.longitude);
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _toDb(v)));
    }
    if (value is List) return value.map((e) => _toDb(e)).toList();
    return value;
  }
}