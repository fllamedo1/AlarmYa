import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'almacenamiento.dart';
import 'registro.dart';
import 'servicio_ajustes.dart';
import '../models/alarma.dart';

/// Gestor central de notificaciones y del vigilante de alarmas.
///
/// Además de programar notificaciones (respaldo visual), corre un
/// "vigilante" que verifica cada 10 s si toca una alarma. Como la app
/// se mantiene viva en fondo con el audio silencioso del guardián, el
/// vigilante puede disparar la alarma por sí mismo: el sonido sale de
/// la propia app (categoría `playback`) y suena aunque el iPhone esté
/// en silencio o con No Molestar.
class ServicioNotificaciones {
  ServicioNotificaciones._();
  static final ServicioNotificaciones instancia = ServicioNotificaciones._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _listo = false;
  Timer? _vigilante;
  final _disparadas = <String>{}; // claves 'id@fechaISO' ya sonadas
  String? _misionPendiente; // si la app arrancó fría tocando una notificación
  DateTime? ultimoChequeo;
  DateTime? get ultimoChequeoEn => ultimoChequeo;
  bool get vigilanteActivo => _vigilante != null;
  int _ticks = 0;

  /// Cada cuánto vuelve a sonar el "bip" hasta que se abre la misión.
  static const _reintentoCadaSec = 30;

  /// Cada cuánto chequea el vigilante.
  static const _vigilanciaCada = Duration(seconds: 5);

  static const _categoriaAlarma = 'ALARMA_CAT';

  /// Callback que la app registra; se invoca con el id de la alarma cuando
  /// toca dispararla (notificación tocada o vigilante).
  void Function(String idAlarma)? alAbrirMision;

  Future<void> _posponerDesdeNotificacion(String idAlarma) async {
    // Elimina los reintentos de la alarma que acaba de sonar antes de
    // programar el nuevo aviso de snooze.
    await reprogramarDesdeGuardado();
    await programarSnooze(idAlarma);
  }

  NotificationDetails get _detalles => NotificationDetails(
        iOS: DarwinNotificationDetails(
          // El sonido nativo permite comprobar la entrega de audio de iOS
          // sin depender de un recurso WAV personalizado.
          sound: null,
          interruptionLevel: InterruptionLevel.timeSensitive,
          categoryIdentifier: _categoriaAlarma,
          presentAlert: true,
          presentBanner: true,
          presentList: true,
          presentSound: true,
        ),
      );

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

    final ajustes = InitializationSettings(
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
        defaultPresentSound: true,
        notificationCategories: [
          DarwinNotificationCategory(
            _categoriaAlarma,
            actions: [
              DarwinNotificationAction.plain('posponer', 'Posponer 5 min'),
              DarwinNotificationAction.plain(
                'desactivar',
                'Desactivar',
                options: {DarwinNotificationActionOption.destructive},
              ),
            ],
          ),
        ],
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

  /// Enciende el vigilante: revisa cada 5 s si toca una alarma y, si sí,
  /// la dispara desde la app (sonido real, ignore silencio/No Molestar).
  void iniciarVigilante() {
    if (_vigilante != null) return;
    _vigilante = Timer.periodic(_vigilanciaCada, (_) => _vigilar());
    Registro.instancia.add('Vigilante: activo (cada ${_vigilanciaCada.inSeconds}s)');
  }

  /// Estado de permisos de notificación (para diagnóstico).
  Future<NotificationsEnabledOptions?> permisoEstado() async {
    return _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.checkPermissions();
  }

  Future<void> _vigilar() async {
    if (!_listo) return;
    ultimoChequeo = DateTime.now();
    _ticks++;
    if (_ticks % 12 == 0) {
      Registro.instancia.add('Vigilante: vivo (1 min)');
    }
    try {
      final alarmas = await Almacenamiento.instancia.cargar();
      final ahora = DateTime.now();
      for (final a in alarmas) {
        if (!a.activa) continue;
        final prox = ocurrenciaEnCurso(a, ahora);
        if (prox == null) continue;
        // Ventana normal: hasta 10 s tarde. Ventana tardía: si iOS tuvo
        // la app suspendida, igual disparamos si el usuario desbloquea
        // dentro de los 30 min siguientes a la hora programada.
        final tarde = ahora.difference(prox);
        final enVentana = !ahora.isBefore(prox) &&
            (tarde < _vigilanciaCada * 2 ||
                tarde < const Duration(minutes: 30));
        if (!enVentana) continue;
        final clave = '${a.id}@${prox.toIso8601String()}';
        if (_disparadas.contains(clave)) continue;
        _disparadas.add(clave);
        if (_disparadas.length > 200) {
          _disparadas.remove(_disparadas.first);
        }
        final retraso = tarde.inSeconds;
        Registro.instancia.add(
            'Vigilante: DISPARO alarma ${a.id} (retraso ${retraso}s)');
        // Re-arma las próximas ocurrencias (descarta la ya sonada).
        await reprogramar(alarmas);
        // Abrir la misión inmediatamente.
        if (alAbrirMision != null) {
          alAbrirMision?.call(a.id);
        } else {
          _misionPendiente = a.id;
        }
      }
    } catch (e) {
      Registro.instancia.add('Vigilante: ERROR -> $e');
    }
  }

  void _alTocar(NotificationResponse r) async {
    final id = (r.payload == null || r.payload!.isEmpty)
        ? ''
        : ((jsonDecode(r.payload!) as Map<String, dynamic>)['id'] ?? '')
            .toString();
    Registro.instancia.add(
        'Notificación tocada: acción=${r.actionId ?? "abrir"} id=$id');
    if (id.isEmpty) return;
    switch (r.actionId) {
      case 'posponer':
        await _posponerDesdeNotificacion(id);
        break;
      case 'desactivar':
        await desactivarAlarma(id);
        break;
      default:
        _abrirMision(r.payload!);
    }
  }

  /// Apaga la alarma desde el botón "Desactivar" de la notificación
  /// (y cancela sus bips pendientes).
  Future<void> desactivarAlarma(String id) async {
    final alarmas = await Almacenamiento.instancia.cargar();
    for (final a in alarmas) {
      if (a.id == id) a.activa = false;
    }
    await Almacenamiento.instancia.guardar(alarmas);
    await reprogramar(alarmas);
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
        if (alAbrirMision == null) {
          // La app arrancó fría: nadie registró el callback todavía.
          // Guardamos la misión para que se abra apenas cargue la UI.
          _misionPendiente = id;
        } else {
          alAbrirMision?.call(id);
        }
      }
    } catch (_) {}
  }

  /// Id de alarma cuya misión quedó pendiente de abrir (arranque frío
  /// desde notification tap). Devuelve el id y limpia.
  String? tomarMisionPendiente() {
    final p = _misionPendiente;
    _misionPendiente = null;
    return p;
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
    // Omisiones vencidas: se limpian y se guardan.
    final ahora = DateTime.now();
    var cambio = false;
    for (final a in alarmas) {
      if (a.omitirHasta != null && !a.omitirHasta!.isAfter(ahora)) {
        a.omitirHasta = null;
        cambio = true;
      }
    }
    if (cambio) await Almacenamiento.instancia.guardar(alarmas);

    await _plugin.cancelAllPendingNotifications();
    for (final a in alarmas) {
      if (a.activa) await _programar(a);
    }
  }

  /// Cancela los bips de reintento y reactiva los disparos futuros.
  Future<void> reprogramarDesdeGuardado() async {
    await ServicioAjustes.instancia.cargar();
    final alarmas = await Almacenamiento.instancia.cargar();
    await reprogramar(alarmas);
  }

  /// Pospone la alarma X minutos (X configurable en Ajustes). Al tocarla
  /// vuelve a abrir la misión.
  Future<void> programarSnooze(String idAlarma) async {
    final ajustes = ServicioAjustes.instancia;
    final ahora = tz.TZDateTime.now(tz.local);
    final fecha = ahora.add(Duration(minutes: ajustes.snoozeMin));
    final payload = jsonEncode(<String, dynamic>{'id': idAlarma});
    await _notificar(
      id: (DateTime.now().millisecondsSinceEpoch ~/ 1000).hashCode.abs(),
      title: '⏰ Pospuesta',
      body: 'Suena en ${ajustes.snoozeMin} min…',
      fecha: fecha,
      detalles: _detalles,
      payload: payload,
    );
  }

  Future<void> _programar(Alarma a) async {
    final ahora = tz.TZDateTime.now(tz.local);

    final payload = jsonEncode(<String, dynamic>{'id': a.id});
    final titulo = '⏰ ${a.titulo.isEmpty ? 'Alarma' : a.titulo}';
    final cuerpo = 'Es hora de despertarte';

    if (a.dias.isEmpty) {
      var fecha = tz.TZDateTime(
          tz.local, ahora.year, ahora.month, ahora.day, a.hora, a.minuto);
      if (!fecha.isAfter(ahora)) {
        fecha = fecha.add(const Duration(days: 1));
      }
      await _notificar(
        id: _idBase(a.hashCode.abs(), 0),
        title: titulo,
        body: cuerpo,
        fecha: fecha,
        detalles: _detalles,
        payload: payload,
      );
      await _programarReintentos(a, fecha, 0, titulo, cuerpo, payload);
    } else {
      final omitir = a.omitirHasta;
      for (final dia in a.dias) {
        // Próxima fecha con ese día de semana (1 = lunes ... 7 = domingo).
        // Si hay omisión vigente, arranca desde la siguiente
        // ocurrencia a la omitida.
        var fecha = tz.TZDateTime(
            tz.local, ahora.year, ahora.month, ahora.day, a.hora, a.minuto);
        // DateTime.weekday: 1 = lunes ... 7 = domingo (igual a nuestra codificación).
        // Si hay omisión vigente, salta todo disparo hasta esa fecha inclusive.
        final omitirL = omitir == null ? null : tz.TZDateTime.from(omitir, tz.local);
        while (fecha.weekday != dia ||
            !fecha.isAfter(ahora) ||
            (omitirL != null && !fecha.isAfter(omitirL))) {
          fecha = fecha.add(const Duration(days: 1));
        }
        await _notificar(
          id: _idBase(a.hashCode.abs(), dia),
          title: titulo,
          body: cuerpo,
          fecha: fecha,
          detalles: _detalles,
          payload: payload,
          semanal: true,
        );
        await _programarReintentos(a, fecha, dia, titulo, cuerpo, payload);
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
  /// La cantidad se configura en Ajustes.
  Future<void> _programarReintentos(
    Alarma a,
    tz.TZDateTime fechaBase,
    int dia,
    String titulo,
    String cuerpo,
    String payload,
  ) async {
    final ajustes = ServicioAjustes.instancia;
    if (!ajustes.reintentarBeep) return;

    for (var n = 1; n <= ajustes.nReintentos; n++) {
      final fecha = fechaBase.add(const Duration(seconds: _reintentoCadaSec) * n);
      await _notificar(
        id: _idReintento(a.hashCode.abs(), dia, n),
        title: titulo,
        body: cuerpo,
        fecha: fecha,
        detalles: _detalles,
        payload: payload,
      );
    }
  }

  int _idBase(int idAlarma, int dia) => '${idAlarma}b$dia'.hashCode.abs();
  int _idReintento(int idAlarma, int dia, int n) =>
      '${idAlarma}r$dia$n'.hashCode.abs();

  /// Próxima fecha (local) en que sonaría esta alarma.
  /// Respeta omisiones vigentes. Devuelve null si no hay próxima.
  static DateTime? proximaDe(Alarma a, DateTime ahora) {
    if (!a.activa) return null;
    final omitir = a.omitirHasta;
    if (a.dias.isEmpty) {
      var f = DateTime(ahora.year, ahora.month, ahora.day, a.hora, a.minuto);
      if (!f.isAfter(ahora)) f = f.add(const Duration(days: 1));
      if (omitir != null && !f.isAfter(omitir)) return null;
      return f;
    }
    DateTime? mejor;
    for (final dia in a.dias) {
      var f = DateTime(ahora.year, ahora.month, ahora.day, a.hora, a.minuto);
      while (f.weekday != dia ||
          !f.isAfter(ahora) ||
          (omitir != null && !f.isAfter(omitir))) {
        f = f.add(const Duration(days: 1));
      }
      if (mejor == null || f.isBefore(mejor)) mejor = f;
    }
    return mejor;
  }

  /// Ocurrencia que está sonando ahora, si la app volvió a ejecutarse dentro
  /// de la ventana de tolerancia. No usa [proximaDe] porque esa función
  /// descarta intencionalmente las horas ya vencidas.
  static DateTime? ocurrenciaEnCurso(Alarma a, DateTime ahora) {
    if (!a.activa) return null;

    final fecha = DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
      a.hora,
      a.minuto,
    );
    if (ahora.isBefore(fecha)) return null;
    if (a.dias.isNotEmpty && !a.dias.contains(fecha.weekday)) return null;
    if (a.omitirHasta != null && !fecha.isAfter(a.omitirHasta!)) return null;

    return fecha;
  }

  static const _diaCorto = ['', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

  /// "Omitir próxima alarma". Devuelve el mensaje para mostrar.
  /// Con alarmas de una sola vez, la desactiva.
  Future<String> omitirSiguiente(Alarma a, List<Alarma> todas) async {
    final ahora = DateTime.now();
    if (a.dias.isEmpty) {
      a.activa = false;
      await reprogramar(todas);
      return 'Alarma de una sola vez desactivada.';
    }

    // Si ya tenía omisión vigente, avanza a la siguiente.
    final base = a.omitirHasta != null && a.omitirHasta!.isAfter(ahora)
        ? a.omitirHasta!
        : ahora;
    var f = DateTime(base.year, base.month, base.day, a.hora, a.minuto);
    while (!f.isAfter(base) ||
        !a.dias.contains(f.weekday)) {
      f = f.add(const Duration(days: 1));
    }
    a.omitirHasta = f;

    await Almacenamiento.instancia.guardar(todas);
    await reprogramar(todas);
    final d = _diaCorto[f.weekday];
    final hh = a.hora.toString().padLeft(2, '0');
    final mm = a.minuto.toString().padLeft(2, '0');
    return 'Omitida: la próxima suena el $d ${f.day}/${f.month} a las $hh:$mm';
  }
}
