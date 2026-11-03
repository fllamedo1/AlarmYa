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

  test('persiste el sonido y volumen propios de cada alarma', () {
    final original = Alarma(
      id: 'alarma-sonido',
      hora: 8,
      minuto: 15,
      sonido: 'radar',
      volumen: 0.4,
    );

    final restaurada = Alarma.decode(original.encode());

    expect(restaurada.sonido, 'radar');
    expect(restaurada.volumen, closeTo(0.4, 0.001));
  });

  test('corrige valores inválidos de sonido y volumen antiguos', () {
    final alarma = Alarma.fromMap({
      'id': 'alarma-antigua',
      'hora': 8,
      'minuto': 15,
      'sonido': 'inexistente',
      'volumen': 4,
    });

    expect(alarma.sonido, 'klaxon');
    expect(alarma.volumen, 1.0);
  });

  test('ofrece sonidos completos y válidos para notificaciones iOS', () {
    expect(Alarma.sonidos.length, 12);
    for (final nombre in Alarma.sonidos.keys) {
      expect(nombre, matches(RegExp(r'^[a-z0-9]+$')));
    }
  });

  test('ofrece nombres útiles para alarmas', () {
    expect(Alarma.nombresSugeridos, contains('Trabajo'));
    expect(Alarma.nombresSugeridos, contains('Medicamento'));
  });
}
