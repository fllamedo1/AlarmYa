import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/alarma.dart';
import '../services/almacenamiento.dart';
import '../services/registro.dart';
import '../services/servicio_audio.dart';
import '../services/servicio_ajustes.dart';
import '../services/servicio_notificaciones.dart';
import 'pantalla_mision.dart';

/// Pantalla de diagnóstico: muestra en vivo qué eslabón de la cadena de
/// alarma está funcionando y cuál no, más un registro de eventos.
class PantallaDiagnostico extends StatefulWidget {
  const PantallaDiagnostico({super.key});

  @override
  State<PantallaDiagnostico> createState() => _PantallaDiagnosticoState();
}

class _PantallaDiagnosticoState extends State<PantallaDiagnostico> {
  Timer? _refresco;
  List<Alarma> _alarmas = <Alarma>[];
  NotificationsEnabledOptions? _permiso;

  @override
  void initState() {
    super.initState();
    _cargar();
    _refresco = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresco?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    _alarmas = await Almacenamiento.instancia.cargar();
    _permiso = await ServicioNotificaciones.instancia.permisoEstado();
    if (mounted) setState(() {});
  }

  String _hora(DateTime? t) {
    if (t == null) return '—';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String _hace(DateTime? t) {
    if (t == null) return 'nunca';
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'hace ${d.inSeconds}s';
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    return 'hace ${d.inHours} h ${d.inMinutes % 60} min';
  }

  String _cuenta(DateTime? f) {
    if (f == null) return 'sin próxima';
    final d = f.difference(DateTime.now());
    if (d.isNegative) return 'atrasada ${_dur(-d)}';
    return 'en ${_dur(d)}';
  }

  String _dur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Future<void> _dispararPrueba() async {
    final conMision = _alarmas.where((a) => a.activa).toList();
    final base = conMision.isNotEmpty ? conMision.first : null;
    if (base == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creá una alarma activa primero para probar con '
              'su misión y su hora'),
        ),
      );
      return;
    }
    Registro.instancia.add('PRUEBA: disparo manual (alarma ${base.id})');
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantallaMision(idAlarma: base.id),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final audio = ServicioAudio.instancia;
    final noti = ServicioNotificaciones.instancia;
    final prox = _proximaProxima();

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          const _Titulo('ESTADO EN VIVO'),
          Card(
            child: Column(
              children: [
                _Fila(
                  'Sesión iniciada',
                  _hora(Registro.instancia.inicioSesion),
                  ok: true,
                  detalle: _hace(Registro.instancia.inicioSesion),
                ),
                _Fila(
                  'Guardián de audio',
                  audio.guardianActivo ? 'ACTIVO' : 'INACTIVO',
                  ok: audio.guardianActivo,
                  detalle: audio.guardianActivo
                      ? 'la app no debería ser suspendida'
                      : 'sin él, iOS puede matar la app en fondo',
                ),
                _Fila(
                  'Vigilante',
                  noti.vigilanteActivo ? 'ACTIVO' : 'INACTIVO',
                  ok: noti.vigilanteActivo,
                  detalle:
                      'último chequeo: ${_hora(noti.ultimoChequeoEn)} (${_hace(noti.ultimoChequeoEn)})',
                ),
                _Fila(
                  'Permiso notificaciones',
                  _permiso == null
                      ? '?'
                      : (_permiso!.isEnabled ? 'PERMITIDO' : 'DENEGADO'),
                  ok: _permiso?.isEnabled == true,
                  detalle: _permiso == null
                      ? 'sin datos'
                      : 'alertas: ${_permiso!.isAlertEnabled ? "sí" : "no"} · '
                          'sonidos: ${_permiso!.isSoundEnabled ? "sí" : "no"}',
                ),
                _Fila(
                  'Tono elegido',
                  ServicioAjustes.instancia.sonido,
                  ok: true,
                  detalle:
                      'subir volumen: ${ServicioAjustes.instancia.subirVolumen ? "sí" : "no"}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _Titulo('PRÓXIMA ALARMA'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prox == null
                        ? 'No hay alarmas activas'
                        : '${prox.hour.toString().padLeft(2, '0')}:${prox.minute.toString().padLeft(2, '0')} '
                            '· ${_cuenta(prox)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: prox == null
                          ? const Color(0xFF999999)
                          : const Color(0xFF222222),
                    ),
                  ),
                  if (prox != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${prox.day}/${prox.month}/${prox.year}  ${_hora(prox)}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF888888)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const _Titulo('PROBAR AHORA'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.play_circle_outline,
                      color: Color(0xFFFFB300)),
                  title: const Text('Disparar alarma de prueba'),
                  subtitle: const Text(
                      'Suena el tono y abre la misión, como una alarma real',
                      style: TextStyle(fontSize: 12.5)),
                  onTap: _dispararPrueba,
                ),
                ListTile(
                  leading: const Icon(Icons.volume_up_outlined,
                      color: Color(0xFFFFB300)),
                  title: const Text('Probar solo el tono'),
                  subtitle: const Text(
                      'Reproduce el tono elegido sin abrir la misión',
                      style: TextStyle(fontSize: 12.5)),
                  onTap: () {
                    Registro.instancia.add('PRUEBA: tono');
                    ServicioAudio.instancia
                        .probar(ServicioAjustes.instancia.sonido);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.mic_off_outlined,
                      color: Color(0xFF666666)),
                  title: const Text('Reiniciar guardián'),
                  subtitle: const Text(
                      'Detiene y vuelve a arrancar el audio silencioso',
                      style: TextStyle(fontSize: 12.5)),
                  onTap: () async {
                    await ServicioAudio.instancia.detenerGuardian();
                    await ServicioAudio.instancia.iniciarGuardian();
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const _Titulo('REGISTRO DE EVENTOS'),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Registro.instancia.limpiar();
                  setState(() {});
                },
                child: const Text('Limpiar',
                    style: TextStyle(color: Color(0xFF999999))),
              ),
            ],
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (Registro.instancia.entradas.isEmpty)
                    const Text('Sin eventos todavía.',
                        style: TextStyle(color: Color(0xFF999999)))
                  else
                    ...Registro.instancia.entradas.reversed.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          e,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                            color: Color(0xFF444444),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Cómo leer esto: si "Sesión iniciada" es más tarde que la hora '
            'de la alarma, iOS cerró la app durante la noche y no pudo sonar. '
            'Si el guardián está INACTIVO, la app no se está manteniendo viva. '
            'Si el permiso está DENEGADO, no habrá banner.',
            style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }

  DateTime? _proximaProxima() {
    DateTime? mejor;
    final ahora = DateTime.now();
    for (final a in _alarmas) {
      final p = ServicioNotificaciones.proximaDe(a, ahora);
      if (p == null) continue;
      if (mejor == null || p.isBefore(mejor)) mejor = p;
    }
    return mejor;
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.titulo, this.valor,
      {required this.ok, this.detalle});

  final String titulo;
  final String valor;
  final bool ok;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            ok ? Icons.circle : Icons.error_outline,
            size: 14,
            color: ok ? const Color(0xFF4CAF50) : const Color(0xFFE57373),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontSize: 14)),
                if (detalle != null)
                  Text(detalle!,
                      style: const TextStyle(
                          fontSize: 11.5, color: Color(0xFF999999))),
              ],
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ok ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
            ),
          ),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9A9A9A),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
