import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Ajustes de la app estilo Alarmy, guardados localmente.
class ServicioAjustes {
  ServicioAjustes._();
  static final ServicioAjustes instancia = ServicioAjustes._();

  static const _clave = 'ajustes_v1';

  static const sonidos = {
    'klaxon': 'Klaxon (bip doble)',
    'campana': 'Campana',
    'beep': 'Beep digital',
    'radar': 'Radar',
  };

  String sonido = 'klaxon';
  bool subirVolumen = true;
  bool reintentarBeep = true;
  int nReintentos = 10; // cada 30 s
  int snoozeMin = 5;

  /// Canciones reales importadas del iPhone. Cada entrada es
  /// {'id': nombre de archivo en Documents, 'nombre': nombre visible}.
  List<Map<String, String>> canciones = <Map<String, String>>[];

  /// Archivo (id) de la canción activa. Vacío = usar tono generado.
  String cancionActiva = '';

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final bruto = prefs.getString(_clave);
    if (bruto == null) return;
    try {
      final m = jsonDecode(bruto) as Map<String, dynamic>;
      final s = (m['sonido'] ?? '').toString();
      if (sonidos.containsKey(s) || s == 'alarm' || s == 'musica') {
        sonido = s;
      }
      subirVolumen = m['subirVolumen'] is bool ? m['subirVolumen'] as bool : true;
      reintentarBeep =
          m['reintentarBeep'] is bool ? m['reintentarBeep'] as bool : true;
      nReintentos = (m['nReintentos'] is int) ? m['nReintentos'] as int : 10;
      nReintentos = nReintentos.clamp(3, 30);
      snoozeMin = (m['snoozeMin'] is int) ? m['snoozeMin'] as int : 5;
      snoozeMin = snoozeMin.clamp(2, 20);
      if (m['canciones'] is List) {
        canciones = (m['canciones'] as List)
            .whereType<Map>()
            .map((c) => {
                  'id': (c['id'] ?? '').toString(),
                  'nombre': (c['nombre'] ?? '').toString(),
                })
            .where((c) => c['id']!.isNotEmpty)
            .toList();
      }
      cancionActiva = (m['cancionActiva'] ?? '').toString();
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
        'canciones': canciones,
        'cancionActiva': cancionActiva,
      }),
    );
  }
}
