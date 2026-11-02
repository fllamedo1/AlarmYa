import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarmya/models/alarma.dart';
import 'package:alarmya/services/servicio_notificaciones.dart';

void main() {
  test('Smoke test: el proyecto compila', () {
    const key = ValueKey('alarmya');
    expect(key.value, 'alarmya');
  });

  test('detecta una alarma que acaba de vencer', () {
    final alarma = Alarma(
      id: 'alarma-1',
      hora: 7,
      minuto: 30,
    );
    final ahora = DateTime(2026, 11, 2, 7, 30, 5);

    expect(
      ServicioNotificaciones.ocurrenciaEnCurso(alarma, ahora),
      DateTime(2026, 11, 2, 7, 30),
    );
  });

  test('no dispara una alarma antes de su hora ni en otro día', () {
    final alarma = Alarma(
      id: 'alarma-2',
      hora: 7,
      minuto: 30,
      dias: {1},
    );

    expect(
      ServicioNotificaciones.ocurrenciaEnCurso(
        alarma,
        DateTime(2026, 11, 2, 7, 29, 59),
      ),
      isNull,
    );
    expect(
      ServicioNotificaciones.ocurrenciaEnCurso(
        alarma,
        DateTime(2026, 11, 3, 7, 30),
      ),
      isNull,
    );
  });
}
