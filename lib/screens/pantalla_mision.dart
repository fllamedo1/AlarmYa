import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/alarma.dart';
import '../services/almacenamiento.dart';
import '../services/servicio_audio.dart';
import '../services/servicio_notificaciones.dart';

/// Pantalla a pantalla completa estilo Alarmy: fondo amarillo a pantalla
/// completa, hora gigante y misión en tarjeta blanca. El sonido en bucle se
/// detiene solo al completar la misión (o poner en pausa 5 minutos).
class PantallaMision extends StatefulWidget {
  const PantallaMision({super.key, required this.idAlarma});

  final String idAlarma;

  @override
  State<PantallaMision> createState() => _PantallaMisionState();
}

class _PantallaMisionState extends State<PantallaMision> {
  Alarma? _alarma;
  bool _cargando = true;

  // Matemática
  String _pregunta = '';
  int _respuesta = 0;
  String _entrada = '';
  String _mensaje = '';
  bool _comprobando = false;

  // Sacudir
  int _sacudidas = 0;
  bool _enMovimiento = false;
  DateTime _ultimaDeteccion = DateTime.fromMillisecondsSinceEpoch(0);
  StreamSubscription<AccelerometerEvent>? _sub;

  static const _umbralMovimiento = 14.0;
  static const _umbralPausa = 11.0;
  static const _pausaMs = 180;

  @override
  void initState() {
    super.initState();
    _cargarAlarma();
  }

  Future<void> _cargarAlarma() async {
    final alarmas = await Almacenamiento.instancia.cargar();
    Alarma a;
    try {
      a = alarmas.firstWhere((x) => x.id == widget.idAlarma);
    } catch (_) {
      a = Alarma(id: widget.idAlarma, hora: 0, minuto: 0);
    }
    _alarma = a;

    await ServicioAudio.instancia.sonar();

    if (!mounted) return;
    setState(() => _cargando = false);

    if (a.mision == TipoMision.sacudir) _escucharSensor();
    if (a.mision == TipoMision.matematica) _nuevaPregunta();
  }

  void _escucharSensor() {
    _sub = accelerometerEventStream().listen((e) {
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      final ahora = DateTime.now();
      if (!_enMovimiento &&
          mag > _umbralMovimiento &&
          ahora.difference(_ultimaDeteccion).inMilliseconds > _pausaMs) {
        _enMovimiento = true;
        _ultimaDeteccion = ahora;
        _sacudidas++;
        if (mounted) setState(() {});
        if (_sacudidas >= (_alarma?.sacudidasRequeridas ?? 10)) {
          _completar();
        }
      } else if (mag < _umbralPausa) {
        _enMovimiento = false;
      }
    });
  }

  void _nuevaPregunta() {
    final r = Random();
    switch (_alarma!.dificultad) {
      case Dificultad.facil:
        final a = r.nextInt(20) + 2;
        final b = r.nextInt(20) + 2;
        _pregunta = '$a + $b';
        _respuesta = a + b;
        break;
      case Dificultad.media:
        final modo = r.nextInt(2);
        final a = r.nextInt(12) + 3;
        final b = r.nextInt(12) + 3;
        if (modo == 0) {
          _pregunta = '$a × $b';
          _respuesta = a * b;
        } else {
          final mayor = max(a, b);
          final menor = min(a, b);
          _pregunta = '$mayor - $menor';
          _respuesta = mayor - menor;
        }
        break;
      case Dificultad.dificil:
        final a = r.nextInt(12) + 2;
        final b = r.nextInt(12) + 2;
        final c = r.nextInt(40) + 10;
        _pregunta = '$a × $b + $c';
        _respuesta = a * b + c;
        break;
    }
  }

  Future<void> _comprobar() async {
    if (_comprobando) return;
    setState(() => _comprobando = true);
    final entrada = int.tryParse(_entrada);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (entrada != _respuesta) {
      if (mounted) {
        setState(() {
          _mensaje = 'Incorrecto. Otra cuenta…';
          _comprobando = false;
          _entrada = '';
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

  Future<void> _posponer() async {
    await ServicioAudio.instancia.parar();
    await ServicioNotificaciones.instancia.programarSnooze(widget.idAlarma);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ahora = DateTime.now();
    final a = _alarma;
    final hora = a?.hora ?? ahora.hour;
    final minuto = a?.minuto ?? ahora.minute;
    final mision = a?.mision ?? TipoMision.ninguna;
    final titulo = a?.titulo ?? '';

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFC93C), Color(0xFFFF8F00)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Text(
                titulo.isEmpty ? 'AlarmYa' : titulo,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.55),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_d2(hora)}:${_d2(minuto)}',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.85),
                  fontSize: 88,
                  height: 1.0,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Suena el despertador',
                style: TextStyle(
                  color: Colors.black.withOpacity(0.55),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
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
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    switch (mision) {
      case TipoMision.ninguna:
        return _misionBoton();
      case TipoMision.matematica:
        return _misionMatematica();
      case TipoMision.sacudir:
        return _misionSacudir();
    }
  }

  Widget _misionBoton() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cajaBlanca,
      child: Column(
        children: [
          const Text(
            'Para apagar la alarma',
            style: TextStyle(fontSize: 14, color: Color(0xFF777777)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 62,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _completar,
              child: const Text(
                'DETENER',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          _botonPosponer(),
        ],
      ),
    );
  }

  Widget _misionMatematica() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cajaBlanca,
      child: Column(
        children: [
          _mensaje.isNotEmpty
              ? Text(
                  _mensaje,
                  style: const TextStyle(
                      color: Color(0xFFD32F2F), fontWeight: FontWeight.w600),
                )
              : const Text(
                  'Resolvé para apagar la alarma',
                  style: TextStyle(fontSize: 14, color: Color(0xFF777777)),
                ),
          const SizedBox(height: 12),
          Text(
            '${_pregunta} = ${_entrada.isEmpty ? '?' : _entrada}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 12),
          for (final fila in _teclasGrupos)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final tecla in fila)
                  _Tecla(
                    etiqueta: tecla,
                    onPressed: () => _tocarTecla(tecla),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _comprobando ? null : _comprobar,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFB300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'COMPROBAR',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1),
              ),
            ),
          ),
          _botonPosponer(),
        ],
      ),
    );
  }

  static const _teclasGrupos = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['C', '0', '⌫'],
  ];

  void _tocarTecla(String tecla) {
    setState(() {
      switch (tecla) {
        case 'C':
          _entrada = '';
          break;
        case '⌫':
          if (_entrada.isNotEmpty) {
            _entrada = _entrada.substring(0, _entrada.length - 1);
          }
          break;
        default:
          if (_entrada.length < 6) _entrada += tecla;
      }
    });
  }

  Widget _misionSacudir() {
    final req = _alarma?.sacudidasRequeridas ?? 10;
    final progreso = (_sacudidas / req).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cajaBlanca,
      child: Column(
        children: [
          const Icon(Icons.vibration, size: 42, color: Color(0xFFFFB300)),
          const SizedBox(height: 8),
          const Text(
            'Sacudí el teléfono',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text('$_sacudidas / $req',
              style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF222222))),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 12,
              backgroundColor: const Color(0xFFEEEEEE),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFFFB300)),
            ),
          ),
          _botonPosponer(),
        ],
      ),
    );
  }

  Widget _botonPosponer() {
    return TextButton(
      onPressed: _posponer,
      child: const Text(
        'Posponer',
        style: TextStyle(
          color: Color(0xFF999999),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static const _cajaBlanca = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.all(Radius.circular(22)),
    boxShadow: [
      BoxShadow(
        color: Color(0x33000000),
        blurRadius: 16,
        offset: Offset(0, 8),
      ),
    ],
  );
}

class _Tecla extends StatelessWidget {
  const _Tecla({required this.etiqueta, required this.onPressed});

  final String etiqueta;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF4F4F6),
          foregroundColor: const Color(0xFF333333),
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(60, 46),
        ),
        child: Text(
          etiqueta,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
