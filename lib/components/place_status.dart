import 'package:flutter/material.dart';

class PlaceStatus extends StatelessWidget {
  final String message;
  final bool loading;
  final VoidCallback? retry;
  const PlaceStatus({
    super.key,
    required this.message,
    this.loading = false,
    this.retry,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
          ],
          Text(message, textAlign: TextAlign.center),
          if (retry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    ),
  );
}
