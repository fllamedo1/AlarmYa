import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'servicio_ajustes.dart';

/// Importa y administra canciones reales del iPhone para usarlas como
/// sonido de alarma. Los archivos se copian a la carpeta Documents de
/// la app para que sobrevivan entre sesiones.
class ServicioMusica {
  ServicioMusica._();
  static final ServicioMusica instancia = ServicioMusica._();

  /// Abre el selector de archivos del iPhone, copia la canción elegida
  /// a la app y la deja como activa. Devuelve el nombre para mostrar o
  /// null si el usuario canceló.
  Future<String?> importarCancion() async {
    final lista = await FilePicker.pickFiles(type: FileType.audio);
    if (lista.isEmpty) return null;
    final archivo = lista.first;
    final bytes = await archivo.readAsBytes();

    final docs = await _documentos();
    final nombre = archivo.name;
    final id = _idDesde(nombre);
    final destino = File('${docs.path}/$id');
    await destino.writeAsBytes(bytes, flush: true);

    final ajustes = ServicioAjustes.instancia;
    // Evita duplicados: si ya existe ese id, lo reemplaza.
    ajustes.canciones.removeWhere((c) => c['id'] == id);
    ajustes.canciones.add({'id': id, 'nombre': nombre});
    ajustes.cancionActiva = id;
    ajustes.sonido = 'musica';
    await ajustes.guardar();
    return nombre;
  }

  Future<void> eliminar(String id) async {
    try {
      final docs = await _documentos();
      final f = File('${docs.path}/$id');
      if (await f.exists()) await f.delete();
    } catch (_) {}
    final ajustes = ServicioAjustes.instancia;
    ajustes.canciones.removeWhere((c) => c['id'] == id);
    if (ajustes.cancionActiva == id) {
      ajustes.cancionActiva = '';
      ajustes.sonido = 'klaxon';
    }
    await ajustes.guardar();
  }

  /// Ruta completa del archivo de la canción activa (o null si no hay).
  Future<String?> rutaCancionActiva() async {
    final ajustes = ServicioAjustes.instancia;
    if (ajustes.sonido != 'musica' || ajustes.cancionActiva.isEmpty) {
      return null;
    }
    final docs = await _documentos();
    final f = File('${docs.path}/${ajustes.cancionActiva}');
    if (await f.exists()) return f.path;
    return null;
  }

  String _idDesde(String nombre) {
    var id = nombre.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
    if (!id.endsWith('.mp3') &&
        !id.endsWith('.m4a') &&
        !id.endsWith('.wav') &&
        !id.endsWith('.aac')) {
      id = '$id.m4a';
    }
    return 'mus_$id';
  }

  Future<Directory> _documentos() async {
    final base = await getApplicationDocumentsDirectory();
    return base;
  }
}
