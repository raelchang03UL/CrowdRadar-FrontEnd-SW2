import 'dart:async';

import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/login/login_page.dart';
import 'package:crowdradar/services/auth_service.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingLogin extends AuthService {
  final response = Completer<GenericResponse<UserModel>>();

  @override
  Future<GenericResponse<UserModel>> login(String email, String password) =>
      response.future;
}

void main() {
  setUp(SessionService.clear);
  tearDown(SessionService.clear);

  for (final scale in [1.0, 2.0]) {
    testWidgets('login conserva posición al cargar con texto $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = _PendingLogin();
      final cubit = AuthCubit(authService: service);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const LoginPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'citizen@example.invalid');
      await tester.enterText(fields.last, 'synthetic-password');
      final submit = find.byType(ElevatedButton);
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      final originalButton = tester.getRect(submit);
      final originalEmail = tester.getRect(fields.first);

      await tester.tap(submit);
      await tester.pump();

      expect(tester.getRect(submit), originalButton);
      expect(tester.getRect(fields.first), originalEmail);
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);
      expect(find.text('Conectando con el servidor…'), findsOneWidget);
      expect(tester.takeException(), isNull);

      service.response.complete(
        const GenericResponse(
          success: false,
          message: AuthService.connectionError,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AuthService.connectionError), findsOneWidget);
      expect(find.text('citizen@example.invalid'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
