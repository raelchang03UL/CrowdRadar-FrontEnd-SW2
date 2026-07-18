import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'cubits/login_cubit.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

void main() => runApp(const CrowdRadarApp());

class CrowdRadarApp extends StatelessWidget {
  const CrowdRadarApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [ BlocProvider(create: (_) => AuthCubit()) ],
      child: MaterialApp.router(
        title: 'CrowdRadar',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
      ),
    );
  }
}
