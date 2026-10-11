import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docscamer/views/auth/login_screen.dart';

void main() {
  group('Interface Tests - Login Screen Functionality', () {
    testWidgets('Should display login form elements correctly initially', (WidgetTester tester) async {
      // Configure larger screen surface for the test environment to avoid layout truncation
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Verify header and fields presence
      expect(find.text('Connexion'), findsOneWidget);
      expect(find.text('Email ou Téléphone'), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
      expect(find.text('SE CONNECTER'), findsOneWidget);

      // Reset test surface view configuration
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('Should trigger validation error messages when fields are empty and submitted', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Ensure button is visible inside SingleChildScrollView and click it
      final loginButtonFinder = find.text('SE CONNECTER');
      await tester.ensureVisible(loginButtonFinder);
      await tester.tap(loginButtonFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify that validation warning message triggers
      expect(find.text('Champ requis'), findsAtLeastNWidgets(2));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
