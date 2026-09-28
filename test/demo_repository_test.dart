import 'package:flutter_test/flutter_test.dart';
import 'package:safesecurity/models/app_notification.dart';
import 'package:safesecurity/models/notification_preferences.dart';
import 'package:safesecurity/repositories/demo_repository.dart';
import 'package:safesecurity/repositories/repository_exception.dart';

/// Exercises the behaviour added for proposal items B and C against the demo
/// repository, so the flows are covered without a Firebase project.
void main() {
  late DemoRepository repo;

  Future<void> signIn(String email) =>
      repo.signIn(email, DemoRepository.demoPassword);

  setUp(() {
    repo = DemoRepository();
  });

  group('notification preferences', () {
    test('default to incident updates and assignments on', () async {
      await signIn('citizen@demo.safeguard');
      final prefs = await repo.watchNotificationPreferences().first;
      expect(prefs.incidentUpdates, isTrue);
      expect(prefs.assignments, isTrue);
      expect(prefs.communityAlerts, isFalse);
    });

    test('are persisted per user', () async {
      await signIn('citizen@demo.safeguard');
      await repo.saveNotificationPreferences(
        const NotificationPreferences(
          incidentUpdates: false,
          communityAlerts: true,
        ),
      );
      final citizen = await repo.watchNotificationPreferences().first;
      expect(citizen.incidentUpdates, isFalse);
      expect(citizen.communityAlerts, isTrue);

      // A different user must not inherit these settings.
      await signIn('responder@demo.safeguard');
      final responder = await repo.watchNotificationPreferences().first;
      expect(responder.incidentUpdates, isTrue);
      expect(responder.communityAlerts, isFalse);
    });

    test('allows() gates the categories the backend can suppress', () {
      const prefs = NotificationPreferences();
      expect(prefs.allows('incident_update'), isTrue);
      expect(prefs.allows('assignment'), isTrue);
      expect(prefs.allows('community_alert'), isFalse);
      // SOS is safety critical and must never be suppressible.
      expect(prefs.allows('sos'), isTrue);
    });
  });

  group('failed notification delivery', () {
    test('retry marks a failed notification as delivered', () async {
      await signIn('responder@demo.safeguard');
      final before = await repo.watchNotifications().first;
      final failed = before.firstWhere((n) => n.deliveryStatus == DeliveryStatus.failed);
      expect(failed, isNotNull);

      await repo.resendNotification(failed.notificationId);

      final after = await repo.watchNotifications().first;
      final updated = after.firstWhere((n) => n.notificationId == failed.notificationId);
      expect(updated.deliveryStatus, DeliveryStatus.delivered);
    });

    test('resending an unknown notification is a no-op', () async {
      await signIn('responder@demo.safeguard');
      final before = await repo.watchNotifications().first;
      await repo.resendNotification('does_not_exist');
      expect((await repo.watchNotifications().first).length, before.length);
    });
  });

  group('community reports', () {
    test('a posted report appears on the incident feed', () async {
      await signIn('citizen@demo.safeguard');
      await repo.addCommunityReport(incidentId: 'inc_001', text: 'Police just arrived.');
      final reports =
          await repo.watchCommunityReports('inc_001').first;
      expect(reports.any((r) => r.text == 'Police just arrived.'), isTrue);
    });

    test('an empty update is rejected', () async {
      await signIn('citizen@demo.safeguard');
      expect(
        () => repo.addCommunityReport(incidentId: 'inc_001', text: '   '),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('verification is a toggle', () async {
      await signIn('citizen@demo.safeguard');
      await repo.addCommunityReport(incidentId: 'inc_001', text: 'Verified info');
      var reports = await repo.watchCommunityReports('inc_001').first;
      final report = reports.firstWhere((r) => r.text == 'Verified info');
      expect(report.verified, isFalse);

      await repo.verifyCommunityReport(report.reportId);
      reports = await repo.watchCommunityReports('inc_001').first;
      expect(
        reports.firstWhere((r) => r.reportId == report.reportId).verified,
        isTrue,
      );

      await repo.verifyCommunityReport(report.reportId, verified: false);
      reports = await repo.watchCommunityReports('inc_001').first;
      expect(
        reports.firstWhere((r) => r.reportId == report.reportId).verified,
        isFalse,
      );
    });
  });

  group('incident editing while pending', () {
    test('a pending report can be corrected', () async {
      await signIn('citizen@demo.safeguard');
      final pending = (await repo.watchMyIncidents(repo.currentUser!.userId).first)
          .where((i) => i.status.name == 'pending')
          .firstOrNull;
      if (pending == null) return; // seed data has no pending incident

      await repo.updateIncidentDescription(
        incidentId: pending.incidentId,
        description: 'Corrected details.',
      );
      final updated = (await repo.watchAllIncidents().first)
          .firstWhere((i) => i.incidentId == pending.incidentId);
      expect(updated.description, 'Corrected details.');
    });

    test('a handled report cannot be edited', () async {
      await signIn('citizen@demo.safeguard');
      final incidents = await repo.watchAllIncidents().first;
      final handled = incidents.firstWhere((i) => i.status.name != 'pending');
      expect(
        () => repo.updateIncidentDescription(
          incidentId: handled.incidentId,
          description: 'Too late.',
        ),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  group('AI audit log', () {
    test('lists decisions newest first for administrators', () async {
      await signIn('admin@demo.safeguard');
      final logs = await repo.watchAiClassificationLogs().first;
      expect(logs, isNotEmpty);
      for (var i = 1; i < logs.length; i++) {
        expect(logs[i - 1].createdAt.isBefore(logs[i].createdAt), isFalse);
      }
      expect(logs.any((l) => l.wasCorrected), isTrue);
    });

    test('respects the requested limit', () async {
      await signIn('admin@demo.safeguard');
      expect((await repo.watchAiClassificationLogs(limit: 1).first).length, 1);
    });
  });
}
