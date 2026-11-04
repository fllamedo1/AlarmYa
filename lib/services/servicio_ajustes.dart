import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarma.dart';

/// Ajustes de la app estilo Alarmy, guardados localmente.
class ServicioAjustes {
  ServicioAjustes._();
  static final ServicioAjustes instancia = ServicioAjustes._();

  static const _clave = 'ajustes_v1';

  static const sonidos = Alarma.sonidos;

  String sonido = 'amanecer_suave';
  bool subirVolumen = true;
  bool reintentarBeep = true;
  int nReintentos = 10; // cada 30 s
  int snoozeMin = 5;

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final bruto = prefs.getString(_clave);
    if (bruto == null) return;
    try {
      final m = jsonDecode(bruto) as Map<String, dynamic>;
      final s = (m['sonido'] ?? '').toString();
      if (s == 'alarm') {
        sonido = 'amanecer_suave';
      } else if (sonidos.containsKey(s)) {
        sonido = s;
      }
      subirVolumen = m['subirVolumen'] is bool ? m['subirVolumen'] as bool : true;
      reintentarBeep =
          m['reintentarBeep'] is bool ? m['reintentarBeep'] as bool : true;
      nReintentos = (m['nReintentos'] is int) ? m['nReintentos'] as int : 10;
      nReintentos = nReintentos.clamp(3, 30);
      snoozeMin = (m['snoozeMin'] is int) ? m['snoozeMin'] as int : 5;
      snoozeMin = snoozeMin.clamp(2, 20);
    } catch (_) {}
  }

  Future<void> guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clave,
      jsonEncode(<String, dynamic>{
        'sonido': sonido,
        'subirVolumen': subirVolumen,
        'reintentarBeep': reintentarBeep,
        'nReintentos': nReintentos,
        'snoozeMin': snoozeMin,
      }),
    );
  }
}
