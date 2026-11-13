import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'cubits/login_cubit.dart';
import 'router/app_router.dart';
import 'services/push_notification_service.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SessionService.prepareRestore();
  runApp(const CrowdRadarApp());
  unawaited(SessionService.restore());
  // La disponibilidad de Firebase no bloquea la validación de la sesión ni
  // la pantalla de reintento. Push observa también la sesión al inicializar.
  unawaited(PushNotificationService.instance.initialize());
}

class CrowdRadarApp extends StatelessWidget {
  const CrowdRadarApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider(create: (_) => AuthCubit())],
      child: MaterialApp.router(
        title: 'CrowdRadar',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
      ),
    );
  }
}
