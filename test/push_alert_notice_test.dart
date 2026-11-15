import 'package:crowdradar/components/push_alert_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'aviso push en cola se cancela sin cerrar ni sustituir aviso ajeno',
    (tester) async {
      final messenger = GlobalKey<ScaffoldMessengerState>();
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: messenger,
          home: Scaffold(
            body: Builder(
              builder: (value) {
                context = value;
                return const Text('Contenido');
              },
            ),
          ),
        ),
      );
      final other = messenger.currentState!.showSnackBar(
        const SnackBar(content: Text('Aviso ajeno antes'), persist: true),
      );
      await tester.pumpAndSettle();
      final notice = PushAlertNotice.show(
        context,
        text: 'Push en espera',
        onOpen: () {},
      );
      notice!.close();
      await tester.pumpAndSettle();
      expect(find.text('Aviso ajeno antes'), findsOneWidget);
      expect(find.text('Push en espera'), findsNothing);
      expect(find.text('Ver lugar'), findsNothing);
      other.close();
      await tester.pumpAndSettle();
      expect(find.text('Push en espera'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('controller push terminado no cierra aviso ajeno posterior', (
    tester,
  ) async {
    final messenger = GlobalKey<ScaffoldMessengerState>();
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messenger,
        home: Scaffold(
          body: Builder(
            builder: (value) {
              context = value;
              return const Text('Contenido');
            },
          ),
        ),
      ),
    );
    final notice = PushAlertNotice.show(
      context,
      text: 'Push anterior',
      onOpen: () {},
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver lugar'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    messenger.currentState!.showSnackBar(
      const SnackBar(content: Text('Aviso ajeno después'), persist: true),
    );
    await tester.pumpAndSettle();
    notice!.close();
    await tester.pumpAndSettle();
    expect(find.text('Aviso ajeno después'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
