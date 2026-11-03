import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/alarma.dart';

const _diasNombre = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

class PantallaEdicion extends StatefulWidget {
  const PantallaEdicion({super.key, this.alarma});

  final Alarma? alarma;

  @override
  State<PantallaEdicion> createState() => _PantallaEdicionState();
}

class _PantallaEdicionState extends State<PantallaEdicion> {
  late final TextEditingController _titulo;
  late int _hora;
  late int _minuto;
  late TipoMision _mision;
  late Dificultad _dificultad;
  late int _cuentasMatematicas;
  late int _sacudidas;
  late bool _permitirPosponer;
  late String _sonido;
  late double _volumen;
  late Set<int> _dias;

  @override
  void initState() {
    super.initState();
    final a = widget.alarma;
    _titulo = TextEditingController(text: a?.titulo ?? '');
    _hora = a?.hora ?? 7;
    _minuto = a?.minuto ?? 30;
    _mision = a?.mision ?? TipoMision.ninguna;
    _dificultad = a?.dificultad ?? Dificultad.media;
    _cuentasMatematicas = a?.cuentasMatematicas ?? 1;
    _sacudidas = a?.sacudidasRequeridas ?? 10;
    _permitirPosponer = a?.permitirPosponer ?? true;
    _sonido = a?.sonido ?? 'klaxon';
    _volumen = a?.volumen ?? 1.0;
    _dias = Set<int>.from(a?.dias ?? <int>{});
  }

  @override
  void dispose() {
    _titulo.dispose();
    super.dispose();
  }

  Future<void> _elegirHora() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hora, minute: _minuto),
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (t != null) {
      setState(() {
        _hora = t.hour;
        _minuto = t.minute;
      });
    }
  }

  Future<void> _guardar() async {
    final a = widget.alarma ??
        Alarma(id: const Uuid().v4(), hora: _hora, minuto: _minuto);
    a.titulo = _titulo.text.trim();
    a.hora = _hora;
    a.minuto = _minuto;
    a.mision = _mision;
    a.dificultad = _dificultad;
    a.cuentasMatematicas = _cuentasMatematicas;
    a.sacudidasRequeridas = _sacudidas;
    a.permitirPosponer = _permitirPosponer;
    a.sonido = _sonido;
    a.volumen = _volumen;
    a.dias = Set<int>.from(_dias);
    // Guardar una alarma editada reactiva la ocurrencia elegida, incluso si
    // antes se había usado "Omitir próxima alarma".
    a.omitirHasta = null;
    a.activa = true;
    if (mounted) Navigator.of(context).pop(a);
  }

  @override
  Widget build(BuildContext context) {
    final nueva = widget.alarma == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(nueva ? 'Nueva alarma' : 'Editar alarma'),
        actions: [
          TextButton(
            onPressed: _guardar,
            child: const Text(
              'Guardar',
              style: TextStyle(
                color: Color(0xFFFFB300),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          // ── Hora ──
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _elegirHora,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: Column(
                  children: [
                    Text(
                      '${_hora.toString().padLeft(2, '0')}:${_minuto.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontSize: 58,
                        height: 1.0,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Toca para cambiar la hora',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFAAAAAA)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // ── Título ──
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Column(
                children: [
                  TextField(
                    controller: _titulo,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Nombre de la alarma',
                      hintStyle:
                          TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final nombre in Alarma.nombresSugeridos)
                          ActionChip(
                            label: Text(nombre),
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              _titulo.text = nombre;
                              _titulo.selection = TextSelection.collapsed(
                                offset: _titulo.text.length,
                              );
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── Misión ──
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              'PARA APAGAR LA ALARMA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9A9A9A),
                letterSpacing: 0.5,
              ),
            ),
          ),
          _OpcionMision(
            titulo: 'Botón',
            descripcion: 'Toca Detener y listos.',
            icono: Icons.touch_app_outlined,
            seleccionada: _mision == TipoMision.ninguna,
            onTap: () => setState(() => _mision = TipoMision.ninguna),
          ),
          const SizedBox(height: 8),
          _OpcionMision(
            titulo: 'Misión matemática',
            descripcion: 'Resolvé una cuenta para detenerla.',
            icono: Icons.calculate_outlined,
            seleccionada: _mision == TipoMision.matematica,
            onTap: () => setState(() => _mision = TipoMision.matematica),
            child: _mision == TipoMision.matematica
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        SegmentedButton<Dificultad>(
                          style: ButtonStyle(
                            side: WidgetStateProperty.all(
                              const BorderSide(color: Color(0xFFFFB300)),
                            ),
                          ),
                          segments: const [
                            ButtonSegment(
                                value: Dificultad.facil,
                                label: Text('Fácil')),
                            ButtonSegment(
                                value: Dificultad.media,
                                label: Text('Media')),
                            ButtonSegment(
                                value: Dificultad.dificil,
                                label: Text('Difícil')),
                          ],
                          selected: {_dificultad},
                          selectedIcon: const Icon(Icons.check),
                          onSelectionChanged: (s) =>
                              setState(() => _dificultad = s.first),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Cantidad de cuentas',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF666666)),
                            ),
                            DropdownButton<int>(
                              value: _cuentasMatematicas,
                              items: [
                                for (var n = 1; n <= 20; n++)
                                  DropdownMenuItem(
                                    value: n,
                                    child: Text('$n'),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _cuentasMatematicas = v);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          _OpcionMision(
            titulo: 'Sacudir el teléfono',
            descripcion: 'Sacudí el iPhone hasta apagarla.',
            icono: Icons.vibration_outlined,
            seleccionada: _mision == TipoMision.sacudir,
            onTap: () => setState(() => _mision = TipoMision.sacudir),
            child: _mision == TipoMision.sacudir
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sacudidas necesarias: $_sacudidas',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF666666)),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFFFB300),
                            thumbColor: const Color(0xFFFFB300),
                          ),
                          child: Slider(
                            min: 5,
                            max: 40,
                            divisions: 7,
                            value: _sacudidas.toDouble(),
                            onChanged: (v) =>
                                setState(() => _sacudidas = v.round()),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              'SONIDO DE ESTA ALARMA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9A9A9A),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _sonido,
                    decoration: const InputDecoration(
                      labelText: 'Tono',
                      border: InputBorder.none,
                    ),
                    items: [
                      for (final entry in Alarma.sonidos.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _sonido = v);
                    },
                  ),
                  Text(
                    'Volumen: ${(_volumen * 100).round()}%',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFFFFB300),
                      thumbColor: const Color(0xFFFFB300),
                    ),
                    child: Slider(
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      value: _volumen,
                      onChanged: (v) => setState(() => _volumen = v),
                    ),
                  ),
                  const Text(
                    'El volumen durante la alarma usa este valor. Con el iPhone bloqueado, iOS usa el volumen de notificaciones del sistema.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              title: const Text('Permitir posponer'),
              subtitle: const Text('Muestra el botón para posponer la alarma'),
              value: _permitirPosponer,
              activeColor: const Color(0xFFFFB300),
              onChanged: (v) => setState(() => _permitirPosponer = v),
            ),
          ),
          const SizedBox(height: 16),
          // ── Repetir ──
          const Padding(
            padding: EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              'REPETIR',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9A9A9A),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        _ChipDiaGrande(
                          letra: _diasNombre[d - 1],
                          activo: _dias.contains(d),
                          onTap: () => setState(() {
                            _dias.contains(d)
                                ? _dias.remove(d)
                                : _dias.add(d);
                          }),
                        ),
                    ],
                  ),
                  if (_dias.isEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Sin días tocados: suena una sola vez en la próxima hora.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _guardar,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              nueva ? 'CREAR ALARMA' : 'GUARDAR CAMBIOS',
              style: const TextStyle(fontSize: 16, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpcionMision extends StatelessWidget {
  const _OpcionMision({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.seleccionada,
    required this.onTap,
    this.child,
  });

  final String titulo;
  final String descripcion;
  final IconData icono;
  final bool seleccionada;
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: seleccionada ? const Color(0xFFFFFBF0) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: seleccionada ? const Color(0xFFFFB300) : Colors.transparent,
          width: 1.6,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icono,
                    color: seleccionada
                        ? const Color(0xFFFFB300)
                        : const Color(0xFF999999),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: seleccionada
                                ? const Color(0xFF222222)
                                : const Color(0xFF444444),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          descripcion,
                          style: const TextStyle(
                              fontSize: 12.5, color: Color(0xFF999999)),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    seleccionada
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: seleccionada
                        ? const Color(0xFFFFB300)
                        : const Color(0xFFCCCCCC),
                  ),
                ],
              ),
              if (child != null) child!,
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipDiaGrande extends StatelessWidget {
  const _ChipDiaGrande({
    required this.letra,
    required this.activo,
    required this.onTap,
  });

  final String letra;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: activo ? const Color(0xFFFFB300) : const Color(0xFFEEEEEE),
        ),
        child: Text(
          letra,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: activo ? Colors.white : const Color(0xFF999999),
          ),
        ),
      ),
    );
  }
}
