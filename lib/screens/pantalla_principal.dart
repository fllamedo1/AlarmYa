import 'package:flutter/material.dart';

import '../models/alarma.dart';
import '../services/almacenamiento.dart';
import '../services/servicio_audio.dart';
import '../services/servicio_notificaciones.dart';
import 'pantalla_ajustes.dart';
import 'pantalla_diagnostico.dart';
import 'pantalla_edicion.dart';

const _diasCortos = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

String _textoMision(TipoMision m) {
  switch (m) {
    case TipoMision.matematica:
      return 'Matemática';
    case TipoMision.sacudir:
      return 'Sacudir';
    case TipoMision.ninguna:
      return 'Sin misión';
  }
}

IconData _iconoMision(TipoMision m) {
  switch (m) {
    case TipoMision.matematica:
      return Icons.calculate_outlined;
    case TipoMision.sacudir:
      return Icons.vibration_outlined;
    case TipoMision.ninguna:
      return Icons.alarm;
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  List<Alarma> _alarmas = <Alarma>[];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _alarmas = await Almacenamiento.instancia.cargar();
    // Vigilante: dispara la alarma por sí mismo a la hora programada.
    ServicioNotificaciones.instancia.iniciarVigilante();
    // Guardián: audio silencioso en bucle para que iOS no suspenda la
    // app en segundo plano. Solo si hay alguna alarma activa.
    if (_alarmas.any((a) => a.activa)) {
      await ServicioAudio.instancia.iniciarGuardian();
    } else {
      await ServicioAudio.instancia.detenerGuardian();
    }
    if (mounted) setState(() {});
  }

  Future<void> _aplicarCambios() async {
    await Almacenamiento.instancia.guardar(_alarmas);
    await ServicioNotificaciones.instancia.reprogramar(_alarmas);
    // Actualizamos el guardián según haya alarmas activas o no.
    if (_alarmas.any((a) => a.activa)) {
      await ServicioAudio.instancia.iniciarGuardian();
    } else {
      await ServicioAudio.instancia.detenerGuardian();
    }
    if (mounted) setState(() {});
  }

  Future<void> _editarAlarma([Alarma? alarma]) async {
    final resultado = await Navigator.of(context).push<Alarma>(
      MaterialPageRoute(builder: (_) => PantallaEdicion(alarma: alarma)),
    );
    if (resultado == null) return;
    final i = _alarmas.indexWhere((a) => a.id == resultado.id);
    if (i >= 0) {
      _alarmas[i] = resultado;
    } else {
      _alarmas.add(resultado);
    }
    await _aplicarCambios();
  }

  Future<void> _abrirAjustes() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PantallaAjustes()),
    );
    // Al volver: recarga ajustes y reprograma (el tono puede haber cambiado).
    await ServicioNotificaciones.instancia.reprogramarDesdeGuardado();
    await _cargar();
  }

  Future<void> _omitirSiguiente(Alarma a) async {
    final mensaje = await ServicioNotificaciones.instancia
        .omitirSiguiente(a, _alarmas);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), duration: const Duration(seconds: 3)),
      );
    }
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm'),
        actions: [
          IconButton(
            tooltip: 'Diagnóstico',
            icon: const Icon(Icons.monitor_heart_outlined),
            color: const Color(0xFF666666),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const PantallaDiagnostico()),
            ),
          ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            color: const Color(0xFF666666),
            onPressed: _abrirAjustes,
          ),
        ],
      ),
      body: _alarmas.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay alarmas todavía.\n\nTocá el botón + para crear la primera.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, color: Colors.black38, height: 1.5),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
              itemCount: _alarmas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _TarjetaAlarma(
                alarma: _alarmas[i],
                onToggle: (v) {
                  _alarmas[i].activa = v;
                  _aplicarCambios();
                },
                onOpen: () => _editarAlarma(_alarmas[i]),
                onDelete: () {
                  _alarmas.removeAt(i);
                  _aplicarCambios();
                },
                onOmitir: () => _omitirSiguiente(_alarmas[i]),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editarAlarma(),
        backgroundColor: const Color(0xFFFFB300),
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        tooltip: 'Nueva alarma',
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _TarjetaAlarma extends StatelessWidget {
  const _TarjetaAlarma({
    required this.alarma,
    required this.onToggle,
    required this.onOpen,
    required this.onDelete,
    required this.onOmitir,
  });

  final Alarma alarma;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onOmitir;

  @override
  Widget build(BuildContext context) {
    final activo = alarma.activa;
    final colorHora = activo ? const Color(0xFF222222) : const Color(0xFF9E9E9E);
    final texto =
        alarma.titulo.isEmpty ? 'Alarma' : (alarma.titulo);
    final omitir = alarma.omitirHasta;
    final omitidoProximo = omitir != null && omitir.isAfter(DateTime.now());

    return Dismissible(
      key: Key(alarma.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFE57373),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alarma.horaTexto,
                        style: TextStyle(
                          fontSize: 40,
                          height: 1.0,
                          fontWeight: FontWeight.w600,
                          color: colorHora,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        texto,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF888888),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (var d = 1; d <= 7; d++)
                            Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: _ChipDia(
                                letra: _diasCortos[d - 1],
                                activo: alarma.dias.contains(d) && activo,
                              ),
                            ),
                          const SizedBox(width: 6),
                          Icon(
                            _iconoMision(alarma.mision),
                            size: 16,
                            color: activo
                                ? const Color(0xFFFFB300)
                                : const Color(0xFFBBBBBB),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _textoMision(alarma.mision),
                            style: TextStyle(
                              fontSize: 12,
                              color: activo
                                  ? const Color(0xFFE5A100)
                                  : const Color(0xFFBBBBBB),
                            ),
                          ),
                        ],
                      ),
                      if (omitidoProximo && activo)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            '⏸ Omitida: no suena el próximo disparo',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF999999)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Switch(
                  value: alarma.activa,
                  onChanged: onToggle,
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert,
                      color: Color(0xFF999999)),
                  onPressed: () => _menu(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.block_outlined,
                  color: Color(0xFFFFB300)),
              title: const Text('Omitir próxima alarma'),
              onTap: () => Navigator.pop(ctx, 'omitir'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              onTap: () => Navigator.pop(ctx, 'editar'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Color(0xFFE57373)),
              title: const Text('Eliminar',
                  style: TextStyle(color: Color(0xFFE57373))),
              onTap: () => Navigator.pop(ctx, 'eliminar'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (accion == 'omitir') onOmitir();
    if (accion == 'editar') onOpen();
    if (accion == 'eliminar') onDelete();
  }
}

class _ChipDia extends StatelessWidget {
  const _ChipDia({required this.letra, required this.activo});

  final String letra;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 21,
      height: 21,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: activo ? const Color(0xFFFFB300) : const Color(0xFFEEEEEE),
      ),
      child: Text(
        letra,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: activo ? Colors.white : const Color(0xFFAAAAAA),
        ),
      ),
    );
  }
}
