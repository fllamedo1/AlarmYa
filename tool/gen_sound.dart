// Genera tonos de alarma propios (sin material de terceros).
// Uso: dart run tool/gen_sound.dart <salida.wav> <tipo>
// tipos: klaxon (bip doble), campana (campana con decaimiento),
// beep (pulso corto), radar (barrido de frecuencia), sirena, despertador,
// campanario, ascendente, urgente, suave, digital2, clasico
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sampleRate = 22050;

List<int> u32LE(int v) =>
    [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];

List<int> u16LE(int v) => [v & 0xFF, (v >> 8) & 0xFF];

double envolvente(double tLocal, double largo, double ataque, double cola) {
  if (tLocal < ataque) return tLocal / ataque;
  if (tLocal > largo - cola) return max(0.0, (largo - tLocal) / cola);
  return 1.0;
}

List<int> generar(String tipo) {
  // Duración total < 30 s (límite iOS para sonidos de notificación).
  // 'silencio' es un track digital callado para el guardián de fondo.
  final duracion = tipo == 'silencio' ? 2.0 : 24.0;
  final n = (sampleRate * duracion).toInt();
  final fases = <double>[0.0, 0.0, 0.0];
  final data = Uint8List(n * 2);
  var idx = 0;

  for (var i = 0; i < n; i++) {
    final t = i / sampleRate;
    double s = 0.0;

    switch (tipo) {
      case 'klaxon':
        // 8 bips alternando 1046/1568 Hz, 0,35 s c/u, pausa 3,4 s
        const ciclo = 0.35 * 8 + 3.4;
        final p = t % ciclo;
        if (p < 0.35 * 8) {
          final b = (p / 0.35).floor();
          final f = b % 2 == 0 ? 1046.0 : 1568.0;
          final env = envolvente(p % 0.35, 0.35, 0.015, 0.05);
          fases[0] += 2 * pi * f / sampleRate;
          s = (sin(fases[0]) * 0.6 + sin(fases[0] * 2) * 0.15) * env * 0.85;
        }
        break;
      case 'campana':
        // Campanadas cada 2,5 s con decaimiento largo
        const ciclo = 2.5;
        final p = t % ciclo;
        if (p < 1.8) {
          final env = exp(-3.2 * p);
          fases[0] += 2 * pi * 880.0 / sampleRate;
          fases[1] += 2 * pi * 1320.0 / sampleRate;
          s = (sin(fases[0]) * 0.7 + sin(fases[1]) * 0.2) * env;
          fases[2] += 2 * pi * 44.0 / sampleRate;
          s += sin(fases[2]) * 0.05 * env;
        }
        break;
      case 'beep':
        // Pulso corto cada 1 s (estilo despertador digital)
        const ciclo = 1.0;
        final p = t % ciclo;
        if (p < 0.18) {
          const f = 1000.0;
          final env = envolvente(p, 0.18, 0.005, 0.02);
          fases[0] += 2 * pi * f / sampleRate;
          s = sin(fases[0]) * 0.9 * env;
        }
        break;
      case 'radar':
        // Barrido sube-baja cada 1,5 s (estilo radar militar)
        const ciclo = 1.5;
        final p = t % ciclo;
        final u = p / ciclo;
        final f = 500.0 + 1000.0 * (0.5 - (u - 0.5).abs()) * 2;
        final env = envolvente(p, ciclo, 0.02, 0.1);
        fases[0] += 2 * pi * f / sampleRate;
        s = sin(fases[0]) * 0.8 * env;
        break;
      case 'sirena':
        const ciclo = 2.2;
        final p = t % ciclo;
        final u = p / ciclo;
        final f = 520.0 + 760.0 * (0.5 - (u - 0.5).abs()) * 2;
        final env = envolvente(p, ciclo, 0.03, 0.12);
        fases[0] += 2 * pi * f / sampleRate;
        s = (sin(fases[0]) + 0.25 * sin(fases[0] * 2)) * 0.72 * env;
        break;
      case 'despertador':
        const ciclo = 2.4;
        final p = t % ciclo;
        if (p < 0.7) {
          final env = envolvente(p, 0.7, 0.015, 0.08);
          fases[0] += 2 * pi * 880.0 / sampleRate;
          fases[1] += 2 * pi * 1320.0 / sampleRate;
          s = (sin(fases[0]) + 0.35 * sin(fases[1])) * 0.72 * env;
        }
        break;
      case 'campanario':
        const ciclo = 3.0;
        final p = t % ciclo;
        if (p < 2.0) {
          final env = exp(-2.2 * p);
          fases[0] += 2 * pi * 660.0 / sampleRate;
          fases[1] += 2 * pi * 990.0 / sampleRate;
          fases[2] += 2 * pi * 1320.0 / sampleRate;
          s = (sin(fases[0]) * 0.62 +
                  sin(fases[1]) * 0.28 +
                  sin(fases[2]) * 0.12) *
              env;
        }
        break;
      case 'ascendente':
        const ciclo = 2.0;
        final p = t % ciclo;
        final f = 420.0 + 1100.0 * (p / ciclo);
        final env = envolvente(p, ciclo, 0.02, 0.1);
        fases[0] += 2 * pi * f / sampleRate;
        s = (sin(fases[0]) + 0.2 * sin(fases[0] * 2)) * 0.78 * env;
        break;
      case 'urgente':
        const ciclo = 1.1;
        final p = t % ciclo;
        if (p < 0.84) {
          final bloque = (p / 0.28).floor();
          final local = p % 0.28;
          final f = bloque.isEven ? 1250.0 : 930.0;
          final env = envolvente(local, 0.28, 0.008, 0.035);
          fases[0] += 2 * pi * f / sampleRate;
          s = (sin(fases[0]) + 0.18 * sin(fases[0] * 2)) * 0.82 * env;
        }
        break;
      case 'suave':
        const ciclo = 4.0;
        final p = t % ciclo;
        if (p < 1.8) {
          final f = 440.0 + 440.0 * min(1.0, p / 1.6);
          final env = envolvente(p, 1.8, 0.08, 0.35);
          fases[0] += 2 * pi * f / sampleRate;
          fases[1] += 2 * pi * f * 1.5 / sampleRate;
          s = (sin(fases[0]) + 0.3 * sin(fases[1])) * 0.58 * env;
        }
        break;
      case 'digital2':
        const ciclo = 1.0;
        final p = t % ciclo;
        if (p < 0.16 || (p >= 0.32 && p < 0.48)) {
          final local = p < 0.16 ? p : p - 0.32;
          final env = envolvente(local, 0.16, 0.004, 0.025);
          fases[0] += 2 * pi * 1180.0 / sampleRate;
          s = sin(fases[0]) * 0.82 * env;
        }
        break;
      case 'clasico':
        const ciclo = 3.0;
        final p = t % ciclo;
        if (p < 0.5 || (p >= 0.8 && p < 1.3)) {
          final local = p < 0.5 ? p : p - 0.8;
          final env = envolvente(local, 0.5, 0.012, 0.06);
          fases[0] += 2 * pi * 740.0 / sampleRate;
          fases[1] += 2 * pi * 1110.0 / sampleRate;
          s = (sin(fases[0]) + 0.28 * sin(fases[1])) * 0.78 * env;
        }
        break;
    }

    final v = (s.clamp(-1.0, 1.0) * 32767).round();
    data[idx++] = v & 0xFF;
    data[idx++] = (v >> 8) & 0xFF;
  }

  final bytes = <int>[];
  bytes.addAll('RIFF'.codeUnits);
  bytes.addAll(u32LE(36 + data.length));
  bytes.addAll('WAVE'.codeUnits);
  bytes.addAll('fmt '.codeUnits);
  bytes.addAll(u32LE(16));
  bytes.addAll(u16LE(1));
  bytes.addAll(u16LE(1));
  bytes.addAll(u32LE(sampleRate));
  bytes.addAll(u32LE(sampleRate * 2));
  bytes.addAll(u16LE(2));
  bytes.addAll(u16LE(16));
  bytes.addAll('data'.codeUnits);
  bytes.addAll(u32LE(data.length));
  bytes.addAll(data);
  return bytes;
}

void main(List<String> args) {
  final salida = args.isNotEmpty ? args[0] : 'alarm.wav';
  final tipo = args.length > 1 ? args[1] : 'klaxon';
  File(salida).writeAsBytes(generar(tipo), flush: true);
  stdout.writeln('Generado $salida (tipo $tipo)');
}
