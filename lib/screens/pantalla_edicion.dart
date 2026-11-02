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
  late int _sacudidas;
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
    _sacudidas = a?.sacudidasRequeridas ?? 10;
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
    a.sacudidasRequeridas = _sacudidas;
    a.dias = Set<int>.from(_dias);
    a.activa = true;
    if (mounted) Navigator.of(context).pop(a);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.alarma == null ? 'Nueva alarma' : 'Editar alarma'),
        actions: [
          TextButton(
            onPressed: _guardar,
            child: const Text('Guardar',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hora
          InkWell(
            onTap: _elegirHora,
            child: Center(
              child: Text(
                '${_hora.toString().padLeft(2, '0')}:${_minuto.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titulo,
            decoration: const InputDecoration(
              labelText: 'Título',
              hintText: 'Ej: Despertar',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          // Misiones
          const Text('Para apagar la alarma…',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<TipoMision>(
            segments: const [
              ButtonSegment(
                value: TipoMision.ninguna,
                icon: Icon(Icons.stop),
                label: Text('Botón'),
              ),
              ButtonSegment(
                value: TipoMision.matematica,
                icon: Icon(Icons.calculate),
                label: Text('Matemática'),
              ),
              ButtonSegment(
                value: TipoMision.sacudir,
                icon: Icon(Icons.vibration),
                label: Text('Sacudir'),
              ),
            ],
            selected: {_mision},
            onSelectionChanged: (s) => setState(() => _mision = s.first),
          ),
          if (_mision == TipoMision.matematica) ...[
            const SizedBox(height: 16),
            const Text('Dificultad'),
            const SizedBox(height: 8),
            SegmentedButton<Dificultad>(
              segments: const [
                ButtonSegment(value: Dificultad.facil, label: Text('Fácil')),
                ButtonSegment(value: Dificultad.media, label: Text('Media')),
                ButtonSegment(
                    value: Dificultad.dificil, label: Text('Difícil')),
              ],
              selected: {_dificultad},
              onSelectionChanged: (s) =>
                  setState(() => _dificultad = s.first),
            ),
          ],
          if (_mision == TipoMision.sacudir) ...[
            const SizedBox(height: 16),
            Text('Sacudidas necesarias: $_sacudidas'),
            Slider(
              min: 5,
              max: 40,
              divisions: 7,
              value: _sacudidas.toDouble(),
              onChanged: (v) => setState(() => _sacudidas = v.round()),
            ),
          ],
          const SizedBox(height: 24),
          // Días de repetición
          const Text('Repetir los días',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 1; i <= 7; i++)
                FilterChip(
                  selected: _dias.contains(i),
                  label: Text(_diasNombre[i - 1]),
                  onSelected: (sel) => setState(() {
                    sel ? _dias.add(i) : _dias.remove(i);
                  }),
                ),
            ],
          ),
          if (_dias.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Sin días seleccionados: suena una sola vez en la próxima hora.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _guardar,
            icon: const Icon(Icons.save),
            label: const Text('Guardar alarma'),
          ),
        ],
      ),
    );
  }
}
