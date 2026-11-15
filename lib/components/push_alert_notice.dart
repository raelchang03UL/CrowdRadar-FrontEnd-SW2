import 'dart:async';

import 'package:flutter/material.dart';

/// Cancela solo este aviso, incluso si espera detrás de otro SnackBar.
class PushAlertNotice {
  final _enabled = ValueNotifier(true);
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _controller;
  bool _visible = false;
  bool _closed = false;

  PushAlertNotice._();

  static PushAlertNotice? show(
    BuildContext context, {
    required String text,
    required VoidCallback onOpen,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return null;
    final notice = PushAlertNotice._();
    final controller = messenger.showSnackBar(
      SnackBar(
        persist: true,
        content: ValueListenableBuilder<bool>(
          valueListenable: notice._enabled,
          builder: (context, enabled, _) => enabled
              ? Row(
                  children: [
                    Expanded(child: Text(text)),
                    SnackBarAction(label: 'Ver lugar', onPressed: onOpen),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        onVisible: () {
          notice._visible = true;
          if (!notice._enabled.value) notice.close();
        },
      ),
    );
    notice._controller = controller;
    unawaited(
      controller.closed.then((_) {
        notice._closed = true;
        notice._enabled.dispose();
      }),
    );
    return notice;
  }

  void close() {
    if (_closed) return;
    _enabled.value = false;
    // Flutter exige que controller.close pertenezca al aviso actual. Si está
    // en cola, su contenido ya queda vacío y onVisible lo cerrará al llegar.
    if (_visible) {
      _visible = false;
      _controller?.close();
    }
  }
}
