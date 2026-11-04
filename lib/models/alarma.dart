import 'dart:convert';

enum TipoMision { ninguna, matematica, sacudir }

enum Dificultad { facil, media, dificil }

class Alarma {
  static const nombresSugeridos = <String>[
    'Despertar',
    'Trabajo',
    'Estudio',
    'Gimnasio',
    'Medicamento',
    'Reunión',
    'Clases',
    'Viaje',
    'Salir de casa',
    'Dormir',
    'Siesta',
    'Fin de descanso',
  ];

  static const sonidos = <String, String>{
    'amanecer_suave': 'Amanecer suave',
    'despertar_luminoso': 'Despertar luminoso',
    'campana_melosa': 'Campana melosa',
    'cuenco_zen': 'Cuenco zen',
  };

  Alarma({
    required this.id,
    this.titulo = 'Alarma',
    required this.hora,
    required this.minuto,
    this.activa = true,
    this.mision = TipoMision.ninguna,
    this.dificultad = Dificultad.media,
    this.cuentasMatematicas = 1,
    this.sacudidasRequeridas = 10,
    this.permitirPosponer = true,
    this.sonido = 'amanecer_suave',
    this.volumen = 1.0,
    this.archivoSonido,
    this.fechaUnicaIso,
    this.dias = const <int>{},
    this.omitirHastaIso,
  });

  String id;
  String titulo;
  int hora; // 0..23
  int minuto; // 0..59
  bool activa;
  TipoMision mision;
  Dificultad dificultad;
  int cuentasMatematicas;
  int sacudidasRequeridas;
  bool permitirPosponer;
  String sonido;
  double volumen;
  String? archivoSonido;
  String? fechaUnicaIso;
  /// Días de la semana en que se repite. 1 = lunes ... 7 = domingo.
  /// Vacío = alarma de una sola vez.
  Set<int> dias;

  /// "Omitir próxima alarma": fecha (ISO) hasta la que no suena.
  /// Con alarmas semanales, se salta la próxima ocurrencia y el resto
  /// sigue sonando automáticamente.
  String? omitirHastaIso;

  DateTime? get omitirHasta =>
      omitirHastaIso == null ? null : DateTime.tryParse(omitirHastaIso!);

  set omitirHasta(DateTime? d) =>
      omitirHastaIso = d?.toIso8601String();

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
        'cuentasMatematicas': cuentasMatematicas,
        'sacudidas': sacudidasRequeridas,
        'permitirPosponer': permitirPosponer,
        'sonido': sonido,
        'volumen': volumen,
        if (archivoSonido != null) 'archivoSonido': archivoSonido,
        if (fechaUnicaIso != null) 'fechaUnica': fechaUnicaIso,
        'dias': dias.toList()..sort(),
        if (omitirHastaIso != null) 'omitirHasta': omitirHastaIso,
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
        cuentasMatematicas: _intDe(m['cuentasMatematicas'], 1).clamp(1, 20),
        sacudidasRequeridas: _intDe(m['sacudidas'], 10).clamp(3, 60),
        permitirPosponer: m['permitirPosponer'] is bool
            ? m['permitirPosponer'] as bool
            : true,
        sonido: sonidos.containsKey(m['sonido'])
            ? m['sonido'] as String
            : 'amanecer_suave',
        volumen: _doubleDe(m['volumen'], 1.0).clamp(0.1, 1.0).toDouble(),
        archivoSonido: (m['archivoSonido'] ?? '').toString().isEmpty
            ? null
            : (m['archivoSonido'] ?? '').toString(),
        fechaUnicaIso: (m['fechaUnica'] ?? '').toString().isEmpty
            ? null
            : (m['fechaUnica'] ?? '').toString(),
        omitirHastaIso: m['omitirHasta'] == null
            ? null
            : (m['omitirHasta'] as String),
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

  static double _doubleDe(Object? v, double def) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? def;
    return def;
  }

  String encode() => jsonEncode(toMap());

  static Alarma decode(String s) {
    final decoded = jsonDecode(s);
    return Alarma.fromMap(
      decoded is Map<String, dynamic> ? decoded : <String, dynamic>{},
    );
  }
}
