import 'package:flutter/material.dart';

import '../models/alarma.dart';
import '../services/almacenamiento.dart';
import '../services/servicio_notificaciones.dart';
import 'pantalla_edicion.dart';

const _diasTexto = <int, String>{
  1: 'Lun',
  2: 'Mar',
  3: 'Mié',
  4: 'Jue',
  5: 'Vie',
  6: 'Sáb',
  7: 'Dom',
};

String _textoMision(TipoMision m) {
  switch (m) {
    case TipoMision.matematica:
      return '🧮 Misión matemática';
    case TipoMision.sacudir:
      return '📱 Misión sacudir';
    case TipoMision.ninguna:
      return '';
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
    if (mounted) setState(() {});
  }

  Future<void> _aplicarCambios() async {
    await Almacenamiento.instancia.guardar(_alarmas);
    await ServicioNotificaciones.instancia.reprogramar(_alarmas);
    if (mounted) setState(() {});
  }

  Future<void> _editarAlarma([Alarma? alarma]) async {
    final resultado = await Navigator.of(context).push<Alarma>(
      MaterialPageRoute(
        builder: (_) => PantallaEdicion(alarma: alarma),
      ),
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

  Future<void> _borrar(Alarma a, int index) async {
    _alarmas.removeAt(index);
    await _aplicarCambios();
  }

  @override
  Widget build(BuildContext context) {
    final sinAlarmas = _alarmas.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AlarmYa ⏰'),
        backgroundColor: Colors.transparent,
      ),
      body: sinAlarmas
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay alarmas todavía.\nToca + para crear la primera.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _alarmas.length,
              itemBuilder: (context, i) {
                final a = _alarmas[i];
                return Dismissible(
                  key: Key(a.id),
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _borrar(a, i),
                  child: Card(
                    child: ListTile(
                      onTap: () => _editarAlarma(a),
                      title: Text(
                        a.horaTexto,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            a.titulo.isEmpty ? 'Alarma' : a.titulo,
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (a.dias.isNotEmpty)
                            Text(
                              a.dias.map((d) => _diasTexto[d] ?? '').join(' '),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70),
                            ),
                          if (a.mision != TipoMision.ninguna)
                            Text(
                              _textoMision(a.mision),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.amberAccent,
                              ),
                            ),
                        ],
                      ),
                      trailing: Switch(
                        value: a.activa,
                        onChanged: (v) {
                          a.activa = v;
                          _aplicarCambios();
                        },
                      ),
                      leading: const Icon(Icons.access_time),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editarAlarma(),
        tooltip: 'Nueva alarma',
        child: const Icon(Icons.add),
      ),
    );
  }
}
