import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'registro.dart';
import 'servicio_ajustes.dart';
import '../models/alarma.dart';

/// Reproduce el sonido de alarma en bucle hasta completar la misión.
/// Usa la categoría `playback` de iOS: suena aunque el iPhone esté
/// en silencio (interruptor) o bloqueado. Opcionalmente sube el volumen
/// de forma gradual, como Alarmy.
///
/// Además mantiene un "guardián": un audio digitalmente silencioso que
/// gira en segundo plano para que iOS no suspenda la app. Con la app
/// viva, el vigilante puede disparar la alarma por sí mismo a la hora
/// programada (por eso suena de verdad aunque el interruptor esté en
/// silencio o en No Molestar).
class ServicioAudio {
  ServicioAudio._();
  static final ServicioAudio instancia = ServicioAudio._();

  final _player = AudioPlayer(); // alarma real
  final _keeper = AudioPlayer(); // audio silencioso de fondo
  bool _sonando = false;
  bool _guardianActivo = false;
  Timer? _subidaVolumen;

  bool get guardianActivo => _guardianActivo;
  bool get sonando => _sonando;

  AudioContext _contexto() => AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
        ),
      );

  Future<void> sonar(Alarma alarma) async {
    if (_sonando) return;
    _sonando = true;
    final ajustes = ServicioAjustes.instancia;
    final archivo = alarma.sonido;
    try {
      await _player.setAudioContext(_contexto());
      await _player.setReleaseMode(ReleaseMode.loop);
      // Arranque directo: si subirVolumen está activo empieza en 0.35 y sube;
      // si no, va a 1.0 de golpe. Nunca fuerza 1.0 antes de tocar.
      var nivelInicial = alarma.volumen * (ajustes.subirVolumen ? 0.5 : 1.0);
      await _player.setVolume(nivelInicial);
      await _player.play(AssetSource('sounds/$archivo.wav'));
      Registro.instancia.add('Audio: alarma sonando ($archivo, vol $nivelInicial)');

      if (ajustes.subirVolumen) {
        // Sube de 0.5 a 1.0 en ~7 s
        var nivel = nivelInicial;
        _subidaVolumen = Timer.periodic(
          const Duration(milliseconds: 500),
          (t) async {
            if (!_sonando) {
              t.cancel();
              return;
            }
            nivel = (nivel + alarma.volumen * 0.08).clamp(0.0, alarma.volumen);
            await _player.setVolume(nivel);
            if (nivel >= 1.0) t.cancel();
          },
        );
      }
    } catch (e) {
      _sonando = false;
      Registro.instancia.add('Audio: ERROR al sonar -> $e');
    }
  }

  Future<void> parar() async {
    if (!_sonando) return;
    _subidaVolumen?.cancel();
    try {
      await _player.stop();
    } finally {
      _sonando = false;
    }
  }

  /// Audio silencioso en bucle para que iOS no suspenda la app en fondo.
  /// Sin esto, una app sideload muere minutos después de bloquear el
  /// teléfono y la alarma suena solo vía notificación.
  Future<void> iniciarGuardian() async {
    if (_guardianActivo) return;
    _guardianActivo = true;
    try {
      await _keeper.setAudioContext(_contexto());
      await _keeper.setReleaseMode(ReleaseMode.loop);
      await _keeper.setVolume(1.0); // el track es silencio puro
      await _keeper.play(AssetSource('sounds/silencio.wav'));
      Registro.instancia.add('Guardián: activo');
    } catch (e) {
      _guardianActivo = false;
      Registro.instancia.add('Guardián: ERROR -> $e');
    }
  }

  Future<void> detenerGuardian() async {
    if (!_guardianActivo) return;
    try {
      await _keeper.stop();
      Registro.instancia.add('Guardián: detenido');
    } finally {
      _guardianActivo = false;
    }
  }

  /// Escucha de prueba desde Ajustes (no repite en bucle).
  Future<void> probar(String archivo) async {
    await parar();
    try {
      await _player.setAudioContext(_contexto());
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/$archivo.wav'));
    } catch (_) {
      // silencio si falla
    }
  }
}
