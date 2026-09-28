import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:safesecurity/main.dart';
import 'package:safesecurity/repositories/demo_repository.dart';
import 'package:safesecurity/screens/auth/login_screen.dart';
import 'package:safesecurity/state/settings_controller.dart';

void main() {
  testWidgets('SafeGuard boots into the login screen (demo mode)',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await SettingsController.load();
    await tester
        .pumpWidget(SafeGuardApp(repo: DemoRepository(), settings: settings));
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('SafeGuard'), findsOneWidget);
    expect(find.text('Citizen demo'), findsOneWidget);
  });
}