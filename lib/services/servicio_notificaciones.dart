import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'almacenamiento.dart';
import '../models/alarma.dart';

/// Gestor central de notificaciones (las alarmas reales del sistema iOS).
class ServicioNotificaciones {
  ServicioNotificaciones._();
  static final ServicioNotificaciones instancia = ServicioNotificaciones._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _listo = false;

  /// Cada cuánto vuelve a sonar el "bip" hasta que se abre la misión.
  static const _reintentos = 10;
  static const _reintentoCadaSec = 30;

  /// Callback que la app registra; se invoca con el id de la alarma cuando
  /// el usuario toca la notificación de alarma.
  void Function(String idAlarma)? alAbrirMision;

  Future<void> inicializar() async {
    if (_listo) return;

    tzdata.initializeTimeZones();
    try {
      final zona = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zona.identifier));
    } catch (_) {
      // Si falla, tz.local queda con la zona por defecto (UTC+0).
      // La app sigue funcionando; las horas programadas usarán tz.local.
    }

    const ajustes = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _plugin.initialize(
      settings: ajustes,
      onDidReceiveNotificationResponse: _alTocar,
    );

    // Detalle si la app arrancó desde una notificación (apagada → tap).
    final arranque = await _plugin.getNotificationAppLaunchDetails();
    if (arranque?.didNotificationLaunchApp ?? false) {
      final payload = arranque?.notificationResponse?.payload;
      if (payload != null) _abrirMision(payload);
    }

    _listo = true;
  }

  void _alTocar(NotificationResponse r) {
    if (r.payload != null && r.payload!.isNotEmpty) {
      _abrirMision(r.payload!);
    }
  }

  void _abrirMision(String payload) async {
    try {
      final mapa = jsonDecode(payload) as Map<String, dynamic>;
      final id = (mapa['id'] ?? '').toString();
      if (id.isNotEmpty) {
        debugPrint('Notificación de alarma abierta: $id');
        // Matamos los "bip" de reintento pendientes y dejamos armados los
        // disparos de las próximas semanas (para alarmas que se repiten).
        await reprogramarDesdeGuardado();
        alAbrirMision?.call(id);
      }
    } catch (_) {}
  }

  Future<bool> pedirPermiso() async {
    final concedidos = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return concedidos ?? true;
  }

  /// Borra todas las alarmas programadas y reprograma las activas.
  Future<void> reprogramar(List<Alarma> alarmas) async {
    await _plugin.cancelAllPendingNotifications();
    for (final a in alarmas) {
      if (a.activa) await _programar(a);
    }
  }

  /// Cancels los bips de reintento y reactiva los disparos futuros.
  Future<void> reprogramarDesdeGuardado() async {
    final alarmas = await Almacenamiento.instancia.cargar();
    await reprogramar(alarmas);
  }

  Future<void> _programar(Alarma a) async {
    final ahora = tz.TZDateTime.now(tz.local);

    final detalles = const NotificationDetails(
      iOS: DarwinNotificationDetails(
        sound: 'alarm.wav',
        interruptionLevel: InterruptionLevel.timeSensitive,
        presentAlert: true,
        presentSound: true,
      ),
    );

    final payload = jsonEncode(<String, dynamic>{'id': a.id});
    final titulo = '⏰ ${a.titulo.isEmpty ? 'Alarma' : a.titulo}';
    final cuerpo = 'Es hora de despertarte';

    if (a.dias.isEmpty) {
      var fecha = tz.TZDateTime(
          tz.local, ahora.year, ahora.month, ahora.day, a.hora, a.minuto);
      if (!fecha.isAfter(ahora)) {
        fecha = fecha.add(const Duration(days: 1));
      }
      await _notificar(id: _idBase(a.hashCode.abs(), 0), title: titulo, body: cuerpo, fecha: fecha, detalles: detalles, payload: payload);
      await _programarReintentos(a, fecha, 0, titulo, cuerpo, detalles, payload);
    } else {
      for (final dia in a.dias) {
        // Próxima fecha con ese día de semana (1 = lunes ... 7 = domingo)
        var fecha = tz.TZDateTime(
            tz.local, ahora.year, ahora.month, ahora.day, a.hora, a.minuto);
        // DateTime.weekday: 1 = lunes ... 7 = domingo (igual a nuestra codificación)
        while (fecha.weekday != dia || !fecha.isAfter(ahora)) {
          fecha = fecha.add(const Duration(days: 1));
        }
        await _notificar(id: _idBase(a.hashCode.abs(), dia), title: titulo, body: cuerpo, fecha: fecha, detalles: detalles, payload: payload, semanal: true);
        await _programarReintentos(a, fecha, dia, titulo, cuerpo, detalles, payload);
      }
    }
  }

  Future<void> _notificar({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime fecha,
    required NotificationDetails detalles,
    required String payload,
    bool semanal = false,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      payload: payload,
      scheduledDate: fecha,
      notificationDetails: detalles,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents:
          semanal ? DateTimeComponents.dayOfWeekAndTime : null,
    );
  }

  /// Bips de reintento: mismo sonido cada N segundos hasta que la app abra
  /// la misión (se cancelan en ese momento) o se apague/desactive la alarma.
  Future<void> _programarReintentos(
    Alarma a,
    tz.TZDateTime fechaBase,
    int dia,
    String titulo,
    String cuerpo,
    NotificationDetails detalles,
    String payload,
  ) async {
    for (var n = 1; n <= _reintentos; n++) {
      final fecha = fechaBase.add(Duration(seconds: _reintentoCadaSec * n));
      if (a.dias.isEmpty) {
        await _notificar(
          id: _idReintento(a.hashCode.abs(), dia, n),
          title: titulo,
          body: cuerpo,
          fecha: fecha,
          detalles: detalles,
          payload: payload,
        );
      } else {
        // Para alarmas semanales, repetir cada semana en el mismo horario
        // (los reintentos dentro de esta fecha son "una sola vez").
        await _notificar(
          id: _idReintento(a.hashCode.abs(), dia, n),
          title: titulo,
          body: cuerpo,
          fecha: fecha,
          detalles: detalles,
          payload: payload,
          semanal: true,
        );
      }
    }
  }

  int _idBase(int idAlarma, int dia) => '${idAlarma}b$dia'.hashCode.abs();
  int _idReintento(int idAlarma, int dia, int n) => '${idAlarma}r$dia$n'.hashCode.abs();
}
