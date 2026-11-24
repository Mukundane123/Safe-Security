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

/// Unified data-access interface used by every controller.
///
/// Two implementations exist:
///  * [FirebaseRepository] - production backend (Auth, Firestore, Storage, FCM).
///  * [DemoRepository] - in-memory repository so the app is fully browsable
///    without a Firebase project configured.
abstract class IRepository {
  bool get isDemo;

  // ---- Authentication ----
  AppUser? get currentUser;
  Stream<AppUser?> get onAuthStateChanged;
  Future<AppUser?> signIn(String email, String password);
  Future<AppUser> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
    required UserRole role,
  });
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<void> updateProfile({String? name, String? phone});
  Future<void> saveFcmToken(String token);

  // ---- Phone verification (2FA at signup) ----
  /// Sends a one-time code to [phone]. Returns the code in demo mode (so the
  /// flow can be exercised without an SMS gateway) or `null` once sent via the
  /// live backend provider.
  Future<String?> sendPhoneOtp(String phone);
  Future<bool> verifyPhoneOtp(String phone, String code);

  // ---- User management (admin) ----
  Stream<List<AppUser>> watchUsers();
  Future<void> setUserStatus(String userId, AccountStatus status);
  Future<void> deleteUser(String userId);
  Future<String?> responderName(String responderId);

  /// Applies admin vetting to a responder account (approve / reject).
  Future<void> setResponderVerification(
    String userId,
    ResponderVerification status,
  );

  // ---- Incidents ----
  Stream<List<Incident>> watchMyIncidents(String reporterId);
  Stream<List<Incident>> watchAssignedIncidents(String responderId);
  Stream<List<Incident>> watchAllIncidents();
  Future<Incident> reportIncident({
    required String category,
    required String description,
    required double latitude,
    required double longitude,
    required String locationLabel,
    List<String> photoPaths,
    String? subCategory,
    String? voiceNotePath,
    String? videoPath,
    bool isAnonymous = false,
  });
  Future<void> updateIncidentStatus(
    String incidentId,
    String status, {
    DateTime? resolvedAt,
  });
  Future<void> assignIncident(String incidentId, String responderId);
  Future<void> confirmClassification(
    String incidentId, {
    required String category,
    required String priority,
    String? subCategory,
  });
  Future<void> deleteIncident(String incidentId);

  /// Lets the reporter correct their own report while it is still pending.
  Future<void> updateIncidentDescription({
    required String incidentId,
    required String description,
  });

  // ---- Anonymous reporting ----
  /// Issues the one-time capability for an anonymous report. The plain code is
  /// returned for display only; callers must show it to the reporter and never
  /// store it.
  Future<WithdrawalCode> issueReportWithdrawalCode({
    required String incidentId,
  });

  /// Resolves a withdrawal code to its report, or null when the code is
  /// unknown or expired.
  Future<Incident?> findIncidentByWithdrawalCode(String code);

  /// Withdraws an anonymous report using only the code. Nothing links this
  /// action to the account that created it.
  Future<void> withdrawAnonymousReport({
    required String code,
    required String incidentId,
  });

  // ---- Incident audit log / timeline ----
  Stream<List<IncidentUpdate>> watchIncidentUpdates(String incidentId);
  Future<void> recordIncidentUpdate({
    required String incidentId,
    required String action,
    String? detail,
  });

  // ---- Community / public incident updates ----
  Stream<List<CommunityReport>> watchCommunityReports(String incidentId);
  Future<void> addCommunityReport({
    required String incidentId,
    required String text,
  });

  /// Marks a community update as verified (administrators only).
  Future<void> verifyCommunityReport(String reportId, {bool verified = true});

  // ---- SOS alerts ----
  Future<SosAlert> triggerSos({
    required double latitude,
    required double longitude,
    String? note,
  });
  Stream<List<SosAlert>> watchSosAlerts();

  /// Live GPS trail broadcast by a citizen while an SOS is active, so
  /// responders can track them in real time.
  Stream<List<SosLocationUpdate>> watchSosLocations(String sosId);
  Future<void> updateSosLocation(
    String sosId, {
    required double latitude,
    required double longitude,
  });
  Future<void> updateSosStatus(String sosId, String status);

  // ---- Emergency resources directory ----
  /// Static facilities near Kakoba (hospitals, police posts, fire stations,
  /// safe havens and rally points) shown on the community map / directory.
  Stream<List<EmergencyResource>> watchEmergencyResources();

  // ---- Notifications ----
  Stream<List<AppNotification>> watchNotifications();
  Future<void> markNotificationRead(String notificationId);
  Future<void> addNotification(
    AppNotification notification, {
    bool push = false,
  });

  /// Re-requests push delivery for a notification that failed to arrive.
  Future<void> resendNotification(String notificationId);

  // ---- Notification preferences ----
  Stream<NotificationPreferences> watchNotificationPreferences();
  Future<void> saveNotificationPreferences(NotificationPreferences prefs);

  // ---- AI audit trail (administrators) ----
  /// Every automated classification decision, newest first. Administrators
  /// only — the backend rejects other readers.
  Stream<List<AiClassificationLog>> watchAiClassificationLogs({int limit = 100});

  // ---- Trusted contacts ----
  Stream<List<TrustedContact>> watchTrustedContacts();
  Future<void> addTrustedContact({
    required String name,
    required String phone,
    String? contactUserId,
  });
  Future<void> removeTrustedContact(String id);

  // ---- Community alerts ----
  Stream<List<CommunityAlert>> watchCommunityAlerts();
  Future<void> broadcastCommunityAlert({
    required String title,
    required String body,
    required String area,
    required String severity,
    required int expiresInHours,
  });

  // ---- Incident chat (citizen <-> responder) ----
  Stream<List<ChatMessage>> watchIncidentChat(String incidentId);
  Future<void> sendChatMessage({
    required String incidentId,
    required String text,
  });

  // ---- Safe check-in / live journey tracking ----
  Stream<List<CheckIn>> watchCheckIns();
  Future<CheckIn> startCheckIn({
    required String destination,
    required double latitude,
    required double longitude,
    required int expectedMinutes,
  });
  Future<void> updateCheckInLocation(
    String checkInId, {
    required double latitude,
    required double longitude,
  });
  Future<void> completeCheckIn(String checkInId, {required bool arrived});

  // ---- Safety zones (geofencing) ----
  Stream<List<SafetyZone>> watchSafetyZones();
  Future<void> addSafetyZone({
    required String name,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required String risk,
    String? note,
  });
  Future<void> removeSafetyZone(String zoneId);

  // ---- Responder live location ----
  Stream<List<ResponderLocation>> watchResponderLocations();
  Future<void> updateResponderLocation({
    required bool broadcasting,
    required double latitude,
    required double longitude,
  });
}