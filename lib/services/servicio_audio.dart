import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'servicio_ajustes.dart';

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

  AudioContext _contexto() => AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.mixWithOthers},
        ),
      );

  Future<void> sonar() async {
    if (_sonando) return;
    _sonando = true;
    final ajustes = ServicioAjustes.instancia;
    final archivo = ajustes.sonido == 'alarm'
        ? 'klaxon'
        : ajustes.sonido; // compatibilidad con versiones viejas
    try {
      await _player.setAudioContext(_contexto());
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/$archivo.wav'));

      if (ajustes.subirVolumen) {
        // Empieza suave y sube hasta 1.0 en ~8 s
        var nivel = 0.35;
        await _player.setVolume(nivel);
        _subidaVolumen = Timer.periodic(
          const Duration(milliseconds: 500),
          (t) async {
            if (!_sonando) {
              t.cancel();
              return;
            }
            nivel = (nivel + 0.075).clamp(0.0, 1.0);
            await _player.setVolume(nivel);
            if (nivel >= 1.0) t.cancel();
          },
        );
      }
    } catch (_) {
      _sonando = false;
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
    } catch (_) {
      _guardianActivo = false;
    }
  }

  Future<void> detenerGuardian() async {
    if (!_guardianActivo) return;
    try {
      await _keeper.stop();
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
