import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/alarma.dart';

/// Gestor central de notificaciones (las alarmas reales del sistema iOS).
class ServicioNotificaciones {
  ServicioNotificaciones._();
  static final ServicioNotificaciones instancia = ServicioNotificaciones._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _listo = false;

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

  void _abrirMision(String payload) {
    try {
      final mapa = jsonDecode(payload) as Map<String, dynamic>;
      final id = (mapa['id'] ?? '').toString();
      if (id.isNotEmpty) {
        debugPrint('Notificación de alarma abierta: $id');
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

    if (a.dias.isEmpty) {
      var fecha = tz.TZDateTime(
          tz.local, ahora.year, ahora.month, ahora.day, a.hora, a.minuto);
      if (!fecha.isAfter(ahora)) {
        fecha = fecha.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        id: a.id.hashCode.abs(),
        title: '⏰ ${a.titulo.isEmpty ? 'Alarma' : a.titulo}',
        body: 'Es hora de despertarte',
        payload: payload,
        scheduledDate: fecha,
        notificationDetails: detalles,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } else {
      for (final dia in a.dias) {
        // Próxima fecha con ese día de semana (1 = lunes ... 7 = domingo)
        var fecha = tz.TZDateTime(
            tz.local, ahora.year, ahora.month, ahora.day, a.hora, a.minuto);
        // DateTime.weekday: 1 = lunes ... 7 = domingo (igual a nuestra codificación)
        while (fecha.weekday != dia || !fecha.isAfter(ahora)) {
          fecha = fecha.add(const Duration(days: 1));
        }
        await _plugin.zonedSchedule(
          id: '${a.id.hashCode.abs()}$dia'.hashCode.abs(),
          title: '⏰ ${a.titulo.isEmpty ? 'Alarma' : a.titulo}',
          body: 'Es hora de despertarte',
          payload: payload,
          scheduledDate: fecha,
          notificationDetails: detalles,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }
}
