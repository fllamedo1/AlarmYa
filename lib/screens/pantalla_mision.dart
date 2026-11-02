import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/alarma.dart';
import '../services/almacenamiento.dart';
import '../services/servicio_audio.dart';

/// Pantalla a pantalla completa que aparece cuando suena una alarma.
/// El sonido se detiene solo al completar la misión configurada.
class PantallaMision extends StatefulWidget {
  const PantallaMision({super.key, required this.idAlarma});

  final String idAlarma;

  @override
  State<PantallaMision> createState() => _PantallaMisionState();
}

class _PantallaMisionState extends State<PantallaMision> {
  Alarma? _alarma;
  // Matemática
  String _pregunta = '';
  int _respuesta = 0;
  final _controlEntrada = TextEditingController();
  String _mensaje = '';
  bool _resolviendo = false;
  // Sacudir
  int _sacudidas = 0;
  bool _enSwing = false;
  DateTime _ultimaSacudida = DateTime.fromMillisecondsSinceEpoch(0);
  StreamSubscription<AccelerometerEvent>? _sub;

  static const _thresholdoSwing = 14.0;
  static const _umbralPausaMs = 180;

  @override
  void initState() {
    super.initState();
    _cargarAlarma();
  }

  Future<void> _cargarAlarma() async {
    final alarmas = await Almacenamiento.instancia.cargar();
    final a = alarmas.where((x) => x.id == widget.idAlarma).firstOrNull;
    if (mounted) {
      setState(() {
        _alarma = a ?? (Alarma(id: widget.idAlarma, hora: 0, minuto: 0));
      });
      await ServicioAudio.instancia.sonar();
      if (_alarma!.mision == TipoMision.sacudir) _escucharSensor();
      if (_alarma!.mision == TipoMision.matematica) _nuevaPregunta();
    }
  }

  void _escucharSensor() {
    _sub = accelerometerEventStream().listen((e) {
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      final ahora = DateTime.now();
      if (!_enSwing &&
          mag > _thresholdoSwing &&
          ahora.difference(_ultimaSacudida).inMilliseconds > _umbralPausaMs) {
        _enSwing = true;
        _ultimaSacudida = ahora;
        _sacudidas++;
        if (mounted) setState(() {});
        if (_sacudidas >= (_alarma?.sacudidasRequeridas ?? 10)) {
          _completar();
        }
      } else if (mag < _thetauoPausaLibre) {
        _enSwing = false;
      }
    });
  }

  static const _thetauoPausaLibre = 11.0;

  void _nuevaPregunta() {
    final r = Random();
    switch (_alarma!.dificultad) {
      case Dificultad.facil:
        final a = r.nextInt(20) + 2;
        final b = r.nextInt(20) + 2;
        _pregunta = '$a + $b = ?';
        _respuesta = a + b;
        break;
      case Dificultad.media:
        final modo = r.nextInt(2);
        final a = r.nextInt(12) + 3;
        final b = r.nextInt(12) + 3;
        if (modo == 0) {
          _pregunta = '$a × $b = ?';
          _respuesta = a * b;
        } else {
          final mayor = max(a, b);
          final menor = min(a, b);
          _pregunta = '$mayor - $menor = ?';
          _respuesta = mayor - menor;
        }
        break;
      case Dificultad.dificil:
        final a = r.nextInt(12) + 2;
        final b = r.nextInt(12) + 2;
        final c = r.nextInt(40) + 10;
        _pregunta = '$a × $b + $c = ?';
        _respuesta = a * b + c;
        break;
    }
  }

  Future<void> _resolver() async {
    if (_resolviendo) return;
    setState(() => _resolviendo = true);
    final entrada = int.tryParse(_controlEntrada.text.trim());

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (entrada != _respuesta) {
      if (mounted) {
        setState(() {
          _mensaje = 'Incorrecto. Otra cuenta…';
          _resolviendo = false;
          _controlEntrada.clear();
        });
      }
      _nuevaPregunta();
      if (mounted) setState(() {});
      return;
    }
    await _completar();
  }

  Future<void> _completar() async {
    await ServicioAudio.instancia.parar();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controlEntrada.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final a = _alarma;
    final horaTexto =
        '${_d2(a?.hora ?? ahora.hour)}:${_d2(a?.minuto ?? ahora.minute)}';
    final mision = a?.mision ?? TipoMision.ninguna;
    final titulo = a?.titulo ?? '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7C1B1B), Color(0xFF3A0D0D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Text(
                titulo.isEmpty ? 'Alarma' : titulo,
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
              Text(horaTexto,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.w300)),
              const SizedBox(height: 8),
              Text('Misión',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 16)),
              const SizedBox(height: 24),
              Flexible(
                child: _cuerpoMision(mision),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _d2(int v) => v.toString().padLeft(2, '0');

  Widget _cuerpoMision(TipoMision mision) {
    switch (mision) {
      case TipoMision.ninguna:
        return _botonDetener('Presioná para detener');
      case TipoMision.matematica:
        return _misionMatematica();
      case TipoMision.sacudir:
        return _misionSacudir();
    }
  }

  Widget _botonDetener([String texto = 'Detener']) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            ),
            onPressed: _completar,
            icon: const Icon(Icons.stop, size: 32),
            label: const Text('DETENER', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(height: 12),
          Text(texto, style: const TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _misionMatematica() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _mensaje.isNotEmpty ? _mensaje : 'Resolvé para apagar',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              _pregunta,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: TextField(
                controller: _controlEntrada,
                keyboardType: const TextInputType.numberWithOptions(
                    signed: false, decimal: false),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, color: Colors.white),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.black26,
                ),
                onSubmitted: (_) => _resolver(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _resolviendo ? null : _resolver,
              child: const Text('Comprobar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _misionSacudir() {
    final req = _alarma?.sacudidasRequeridas ?? 10;
    final progreso = (_sacudidas / req).clamp(0.0, 1.0);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sacudí el teléfono hasta apagarla',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text('$_sacudidas / $req',
                style:
                    const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            SizedBox(
              width: 260,
              child: LinearProgressIndicator(value: progreso, minHeight: 10),
            ),
          ],
        ),
      ),
    );
  }
}
