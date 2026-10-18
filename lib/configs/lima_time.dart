String limaDate(DateTime value) {
  final local = value.toUtc().subtract(const Duration(hours: 5));
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

String limaToday() => DateTime.now()
    .toUtc()
    .subtract(const Duration(hours: 5))
    .toIso8601String()
    .substring(0, 10);
