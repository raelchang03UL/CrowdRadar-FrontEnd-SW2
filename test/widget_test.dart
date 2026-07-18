import 'package:flutter_test/flutter_test.dart';

import 'package:crowdradar/main.dart';

void main() {
  testWidgets('Smoke test: la app arranca en la pantalla de login', (WidgetTester tester) async {
    await tester.pumpWidget(const CrowdRadarApp());
    await tester.pump();

    expect(find.text('Iniciar sesión'), findsWidgets);
  });
}
