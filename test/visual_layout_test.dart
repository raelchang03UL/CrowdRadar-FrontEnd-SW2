import 'dart:io';
import 'dart:ui' as ui;
import 'package:crowdradar/cubits/login_cubit.dart';
import 'package:crowdradar/pages/login/login_page.dart';
import 'package:crowdradar/pages/register/register_page.dart';
import 'package:crowdradar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    // Capturas optativas de widgets, no evidencia de navegador/Android.
    final font = Platform.environment['CROWDRADAR_WIDGET_FONT'];
    if (font != null) {
      for (final family in ['Roboto', 'Segoe UI']) {
        final loader = FontLoader(family)
          ..addFont(File(font).readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
    final icons = Platform.environment['CROWDRADAR_WIDGET_ICON_FONT'];
    if (icons != null) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(File(icons).readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  for (final size in [const Size(360, 800), const Size(1440, 900)]) {
    for (final registering in [false, true]) {
      testWidgets('formulario contenido $size registro=$registering', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cubit = AuthCubit();
        addTearDown(cubit.close);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: BlocProvider.value(
              value: cubit,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                home: registering ? const RegisterPage() : const LoginPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (Platform.environment['CROWDRADAR_WIDGET_CAPTURE_DIR'] != null) {
          await tester.runAsync(
            () => precacheImage(
              const AssetImage('assets/images/crowdradar-logo-transparent.png'),
              tester.element(find.byType(Scaffold)),
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        final output = Platform.environment['CROWDRADAR_WIDGET_CAPTURE_DIR'];
        if (output != null) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '$output/${registering ? 'registro' : 'login'}_${size.width.toInt()}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        // Un teclado de 300dp y texto 2x no deben esconder permanentemente la acción.
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 300),
                ),
                child: child!,
              ),
              home: registering ? const RegisterPage() : const LoginPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.byType(ElevatedButton);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
