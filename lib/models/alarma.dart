import 'dart:convert';

enum TipoMision { ninguna, matematica, sacudir }

enum Dificultad { facil, media, dificil }

class Alarma {
  Alarma({
    required this.id,
    this.titulo = 'Alarma',
    required this.hora,
    required this.minuto,
    this.activa = true,
    this.mision = TipoMision.ninguna,
    this.dificultad = Dificultad.media,
    this.sacudidasRequeridas = 10,
    this.dias = const <int>{},
  });

  String id;
  String titulo;
  int hora; // 0..23
  int minuto; // 0..59
  bool activa;
  TipoMision mision;
  Dificultad dificultad;
  int sacudidasRequeridas;
  /// Días de la semana en que se repite. 1 = lunes ... 7 = domingo.
  /// Vacío = alarma de una sola vez.
  Set<int> dias;

  String get horaTexto =>
      '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'titulo': titulo,
        'hora': hora,
        'minuto': minuto,
        'activa': activa,
        'mision': TipoMision.values.indexOf(mision),
        'dificultad': Dificultad.values.indexOf(dificultad),
        'sacudidas': sacudidasRequeridas,
        'dias': dias.toList()..sort(),
      };

  factory Alarma.fromMap(Map<String, dynamic> m) => Alarma(
        id: (m['id'] ?? '').toString(),
        titulo: (m['titulo'] ?? 'Alarma').toString(),
        hora: _intDe(m['hora'], 7),
        minuto: _intDe(m['minuto'], 0),
        activa: m['activa'] is bool ? m['activa'] as bool : true,
        mision: m['mision'] is int &&
                m['mision'] >= 0 &&
                m['mision'] < TipoMision.values.length
            ? TipoMision.values[m['mision'] as int]
            : TipoMision.ninguna,
        dificultad: m['dificultad'] is int &&
                m['dificultad'] >= 0 &&
                m['dificultad'] < Dificultad.values.length
            ? Dificultad.values[m['dificultad'] as int]
            : Dificultad.media,
        sacudidasRequeridas: _intDe(m['sacudidas'], 10).clamp(3, 60),
        dias: (m['dias'] is List)
            ? (m['dias'] as List)
                .map<int>((d) => int.tryParse(d.toString()) ?? 0)
                .where((d) => d >= 1 && d <= 7)
                .toSet()
            : <int>{},
      );

  static int _intDe(Object? v, int def) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? def;
    return def;
  }

  String encode() => jsonEncode(toMap());

  static Alarma decode(String s) => Alarma.fromMap(
        jsonDecode(s) is Map<String, dynamic>
            ? jsonDecode(s) as Map<String, dynamic>
            : <String, dynamic>{},
      );
}
