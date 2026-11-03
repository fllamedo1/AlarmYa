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
    'klaxon': 'Impacto',
    'campana': 'Cristal',
    'beep': 'Pulso',
    'radar': 'Órbita',
    'sirena': 'Ascenso',
    'despertador': 'Despertador',
    'campanario': 'Campanas',
    'ascendente': 'Aurora',
    'urgente': 'Alerta',
    'suave': 'Amanecer',
    'digital2': 'Pulsar',
    'clasico': 'Resonancia',
    'tono01': 'Brillo',
    'tono02': 'Destello',
    'tono03': 'Luz de día',
    'tono04': 'Nébula',
    'tono05': 'Cometa',
    'tono06': 'Satélite',
    'tono07': 'Eclipse',
    'tono08': 'Horizonte',
    'tono09': 'Marea',
    'tono10': 'Ola',
    'tono11': 'Gota',
    'tono12': 'Lluvia',
    'tono13': 'Viento',
    'tono14': 'Breeze',
    'tono15': 'Bosque',
    'tono16': 'Pájaro',
    'tono17': 'Piano claro',
    'tono18': 'Piano cálido',
    'tono19': 'Campanita',
    'tono20': 'Círculo',
    'tono21': 'Espiral',
    'tono22': 'Eco',
    'tono23': 'Prisma',
    'tono24': 'Cobalto',
    'tono25': 'Violeta',
    'tono26': 'Rubí',
    'tono27': 'Ámbar',
    'tono28': 'Cobre',
    'tono29': 'Titanio',
    'tono30': 'Acero',
    'tono31': 'Alba',
    'tono32': 'Amanecer lento',
    'tono33': 'Primer rayo',
    'tono34': 'Mañana',
    'tono35': 'Despegue',
    'tono36': 'Elevación',
    'tono37': 'Impulso',
    'tono38': 'Motor',
    'tono39': 'Ritmo',
    'tono40': 'Latido',
    'tono41': 'Pulso doble',
    'tono42': 'Pulso triple',
    'tono43': 'Código',
    'tono44': 'Código azul',
    'tono45': 'Código rojo',
    'tono46': 'Digital suave',
    'tono47': 'Digital vivo',
    'tono48': 'Neón',
    'tono49': 'Semáforo',
    'tono50': 'Señal',
    'tono51': 'Campana grave',
    'tono52': 'Campana clara',
    'tono53': 'Gong',
    'tono54': 'Gong suave',
    'tono55': 'Metal',
    'tono56': 'Cristal alto',
    'tono57': 'Cristal grave',
    'tono58': 'Caja musical',
    'tono59': 'Caja de viento',
    'tono60': 'Reloj',
    'tono61': 'Reloj clásico',
    'tono62': 'Tic tac',
    'tono63': 'Alerta corta',
    'tono64': 'Alerta doble',
    'tono65': 'Alerta grave',
    'tono66': 'Alerta clara',
    'tono67': 'Sirena baja',
    'tono68': 'Sirena alta',
    'tono69': 'Sirena lenta',
    'tono70': 'Sirena rápida',
    'tono71': 'Radar corto',
    'tono72': 'Radar profundo',
    'tono73': 'Radar claro',
    'tono74': 'Barrido',
    'tono75': 'Barrido grave',
    'tono76': 'Barrido brillante',
    'tono77': 'Energía',
    'tono78': 'Energía suave',
    'tono79': 'Energía intensa',
    'tono80': 'Urgencia',
    'tono81': 'Urgencia grave',
    'tono82': 'Urgencia clara',
    'tono83': 'Despertar 1',
    'tono84': 'Despertar 2',
    'tono85': 'Despertar 3',
    'tono86': 'Despertar 4',
    'tono87': 'Despertar 5',
    'tono88': 'Despertar 6',
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
    this.sonido = 'klaxon',
    this.volumen = 1.0,
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
            : 'klaxon',
        volumen: _doubleDe(m['volumen'], 1.0).clamp(0.1, 1.0).toDouble(),
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
