import 'package:crowdradar/components/citizen_points_card.dart';
import 'package:crowdradar/configs/generic_response.dart';
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/models/user_model.dart';
import 'package:crowdradar/pages/profile/profile_page.dart';
import 'package:crowdradar/pages/profile/edit_profile_page.dart';
import 'package:crowdradar/pages/register/register_page.dart';
import 'package:crowdradar/services/session_service.dart';
import 'package:crowdradar/services/user_service.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Users extends UserService {
  final UserModel user;
  _Users(this.user);
  @override
  Future<GenericResponse<UserModel>> getProfile() async =>
      GenericResponse(success: true, data: user);
}

UserModel user(int points) => UserModel(
  id: 1,
  nombre: 'Demo',
  apellido: 'Recorrido',
  email: 'citizen@example.invalid',
  telefono: '900000103',
  distrito: 'Miraflores',
  rol: 'ADMIN',
  status: 'ACTIVO',
  karmaPoints: points,
);
void main() {
  setUp(() => SessionService.start(token: 'synthetic', user: user(0)));
  tearDown(SessionService.clear);
  for (final points in [0, 1, 37]) {
    testWidgets(
      'perfil muestra saldo real $points, política y no privilegios',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: ProfilePage(userService: _Users(user(points))),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CitizenPointsCard), findsOneWidget);
        expect(
          find.text('$points ${points == 1 ? 'punto' : 'puntos'}'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Un reporte aceptado por el servidor suma 10 puntos una sola vez',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining('Empiezas en 0'),
          points == 0 ? findsOneWidget : findsNothing,
        );
        expect(find.text('Rol'), findsNothing);
        expect(find.text('Estado'), findsNothing);
        expect(find.text('ADMIN'), findsNothing);
        expect(find.text('ACTIVO'), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Distrito'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Miraflores'), findsOneWidget);
        expect(find.text('900000103'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final size in [
    const Size(360, 640),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('puntos y datos accesibles $size texto$scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: ProfilePage(userService: _Users(user(37))),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('citizen-points-balance')),
        );
        await tester.pumpAndSettle();
        expect(find.text('37 puntos').hitTestable(), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Cerrar sesión'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Cerrar sesión').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('registro y edición no ofrecen seleccionar rol/estado', (
    tester,
  ) async {
    final auth = AuthCubit();
    addTearDown(auth.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const RegisterPage(),
        ),
      ),
    );
    expect(find.byType(TextFormField), findsNWidgets(6));
    expect(find.text('Rol'), findsNothing);
    expect(find.text('Estado'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: EditProfilePage(user: user(0), userService: _Users(user(0))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(5));
    expect(find.text('Rol'), findsNothing);
    expect(find.text('Estado'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
