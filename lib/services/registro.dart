/// Registro en memoria de eventos de la alarma, para la pantalla de
/// diagnóstico. Se pierde al cerrar la app (es a propósito: nos dice
/// si el proceso sobrevivió hasta la hora programada).
class Registro {
  Registro._();
  static final Registro instancia = Registro._();

  /// Momento en que arrancó este proceso (para detectar si iOS mató
  /// la app durante la noche).
  DateTime? inicioSesion;

  final List<String> entradas = <String>[];

  void add(String texto) {
    final t = DateTime.now();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    entradas.add('$hh:$mm:$ss  $texto');
    if (entradas.length > 120) entradas.removeAt(0);
  }

  void limpiar() => entradas.clear();

  /// Última entrada (null si no hay).
  String? get ultima => entradas.isEmpty ? null : entradas.last;
}
