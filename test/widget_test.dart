import 'package:flutter_test/flutter_test.dart';
import 'package:docscamer/main.dart';

void main() {
  testWidgets('Vérification du chargement de l\'application', (WidgetTester tester) async {
    // Lancement de l'application
    await tester.pumpWidget(const VerifyCamApp());

    // Vérifie que l'application est bien instanciée
    expect(find.byType(VerifyCamApp), findsOneWidget);

    // Éliminer les Timers asynchrones de l'écran Splash pour éviter l'erreur de fuite de Timer
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
