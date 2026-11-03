import 'package:flutter/material.dart';

import '../services/servicio_ajustes.dart';
import '../services/servicio_audio.dart';

/// Pantalla de Ajustes estilo Alarmy: tono de alarma, volumen gradual,
/// reintento de beeps y duración del posponer.
class PantallaAjustes extends StatefulWidget {
  const PantallaAjustes({super.key});

  @override
  State<PantallaAjustes> createState() => _PantallaAjustesState();
}

class _PantallaAjustesState extends State<PantallaAjustes> {
  final _a = ServicioAjustes.instancia;

  Future<void> _guardar() async {
    await _a.guardar();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          const _TituloSeccion('SONIDO DE ALARMA'),
          Card(
            child: Column(
              children: [
                for (final entry in ServicioAjustes.sonidos.entries)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      _a.sonido = entry.key;
                      await _guardar();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            _a.sonido == entry.key
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: _a.sonido == entry.key
                                ? const Color(0xFFFFB300)
                                : const Color(0xFFCCCCCC),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          TextButton(
                            onPressed: () => ServicioAudio.instancia.probar(
                              entry.key,
                              volumen: 1.0,
                            ),
                            child: const Text(
                              'Probar',
                              style: TextStyle(
                                  color: Color(0xFFFFB300),
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _TituloSeccion('VOLUMEN Y COMPORTAMIENTO'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Subir volumen gradualmente'),
                  subtitle: const Text(
                      'Empieza suave y sube al máximo en 8 segundos',
                      style: TextStyle(fontSize: 12.5)),
                  value: _a.subirVolumen,
                  onChanged: (v) async {
                    _a.subirVolumen = v;
                    await _guardar();
                  },
                ),
                SwitchListTile(
                  title: const Text('Repetir beep cada 30 s'),
                  subtitle: const Text(
                      'Vuelve a sonar la notificación hasta que abrís la misión',
                      style: TextStyle(fontSize: 12.5)),
                  value: _a.reintentarBeep,
                  onChanged: (v) async {
                    _a.reintentarBeep = v;
                    await _guardar();
                  },
                ),
                if (_a.reintentarBeep)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cantidad de reintentos: ${_a.nReintentos} '
                          '(≈ ${(_a.nReintentos / 2).toStringAsFixed(1)} min sonando)',
                          style: const TextStyle(
                              fontSize: 12.5, color: Color(0xFF777777)),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFFFB300),
                            thumbColor: const Color(0xFFFFB300),
                          ),
                          child: Slider(
                            min: 3,
                            max: 30,
                            divisions: 9,
                            value: _a.nReintentos.toDouble(),
                            onChanged: (v) async {
                              _a.nReintentos = v.round();
                              await _guardar();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _TituloSeccion('PONER EN PAUSA (POSPONER)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Minutos de pausa',
                      style: TextStyle(fontSize: 14.5)),
                  const SizedBox(height: 10),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 2, label: Text('2 min')),
                      ButtonSegment(value: 5, label: Text('5 min')),
                      ButtonSegment(value: 10, label: Text('10 min')),
                      ButtonSegment(value: 20, label: Text('20 min')),
                    ],
                    selected: {_a.snoozeMin},
                    onSelectionChanged: (s) async {
                      _a.snoozeMin = s.first;
                      await _guardar();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF9A9A9A),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
