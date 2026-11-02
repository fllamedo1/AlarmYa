// Genera alarm.wav: tono de alarma propio (beep alternado con pausa), 24 s.
// Ejecutar: dart run tool/gen_sound.dart <salida.wav>
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sampleRate = 22050;
const double duracion = 24.0; // iOS limita sonidos de notificación a 30 s

List<int> u32LE(int v) =>
    [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];

List<int> u16LE(int v) => [v & 0xFF, (v >> 8) & 0xFF];

void main(List<String> args) {
  final salida = args.isNotEmpty ? args[0] : 'alarm.wav';
  final n = (sampleRate * duracion).toInt();

  final data = Uint8List(n * 2); // PCM 16-bit mono
  var idx = 0;
  // Patrón: 8 beeps de 0.35 s (salta entre 1046 Hz y 1568 Hz) + 3.4 s de pausa
  const beepLen = 0.35;
  const saltoBeeps = 8;
  const pausa = 3.4;
  const ciclo = beepLen * saltoBeeps + pausa;

  var fase = 0.0;

  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    final posCiclo = t % ciclo;
    double sample = 0.0;
    if (posCiclo < beepLen * saltoBeeps) {
      final beepIdx = (posCiclo / beepLen).floor();
      final f = beepIdx % 2 == 0 ? 1046.0 : 1568.0;
      final tLocal = posCiclo % beepLen;
      // Envolvente simple (ataque + decaimiento) para evitar chicharreo
      const ataque = 0.015;
      const finDecay = beepLen - 0.05;
      double env;
      if (tLocal < ataque) {
        env = tLocal / ataque;
      } else if (tLocal > finDecay) {
        env = (beepLen - tLocal) / (beepLen - finDecay);
      } else {
        env = 1.0;
      }
      fase += 2 * pi * f / sampleRate;
      // armónico suave
      final onda = sin(fase) * 0.6 + sin(fase * 2) * 0.15;
      sample = onda * env * 0.85;
      // mezcla minúscula de ruido para textura
      sample += (sin(fase * 13.7) * 0.5) * 0.02;
    }
    final v = (sample.clamp(-1.0, 1.0) * 32767).round();
    data[idx++] = v & 0xFF;
    data[idx++] = (v >> 8) & 0xFF;
  }

  // Construye el archivo WAV (header PCM + data)
  final bytes = <int>[];
  bytes.addAll('RIFF'.codeUnits);
  bytes.addAll(u32LE(36 + data.length));
  bytes.addAll('WAVE'.codeUnits);
  bytes.addAll('fmt '.codeUnits);
  bytes.addAll(u32LE(16)); // tamaño chunk fmt
  bytes.addAll(u16LE(1)); // formato PCM
  bytes.addAll(u16LE(1)); // mono
  bytes.addAll(u32LE(sampleRate));
  bytes.addAll(u32LE(sampleRate * 2)); // bytes por segundo (16-bit mono)
  bytes.addAll(u16LE(2)); // bytes por muestra
  bytes.addAll(u16LE(16)); // bits
  bytes.addAll('data'.codeUnits);
  bytes.addAll(u32LE(data.length));
  bytes.addAll(data);

  File(salida).writeAsBytes(bytes, flush: true);
  stdout.writeln('Generado $salida (${data.length} bytes de audio)');
}
