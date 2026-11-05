/// Estado de las alertas en esta sesión/dispositivo; no contiene credenciales.
enum PushAlertStatus {
  inactive,
  enabling,
  active,
  disabling,
  disableUnconfirmed;

  bool get isBusy => this == enabling || this == disabling;
}
