import 'package:audioplayers/audioplayers.dart';

/// Reproduce el sonido de alarma en bucle hasta completar la misión.
/// Usa la categoría `playback` de iOS: suena aunque el iPhone esté
/// en silencio (interruptor) o bloqueado.
class ServicioAudio {
  ServicioAudio._();
  static final ServicioAudio instancia = ServicioAudio._();

  final _player = AudioPlayer();
  bool _sonando = false;

  Future<void> sonar() async {
    if (_sonando) return;
    _sonando = true;
    try {
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ));
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/alarm.wav'));
    } catch (_) {
      _sonando = false;
    }
  }

  Future<void> parar() async {
    if (!_sonando) return;
    try {
      await _player.stop();
    } finally {
      _sonando = false;
    }
  }
}
