import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarma.dart';
import 'registro.dart';

/// Guarda y carga la lista de alarmas en SharedPreferences.
class Almacenamiento {
  Almacenamiento._();
  static final Almacenamiento instancia = Almacenamiento._();

  static const _clave = 'alarmas_v1';

  Future<List<Alarma>> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final bruto = prefs.getString(_clave);
    if (bruto == null || bruto.isEmpty) return <Alarma>[];
    try {
      final decoded = jsonDecode(bruto);
      if (decoded is! List) {
        throw const FormatException('Las alarmas no están guardadas como lista');
      }
      final alarmas = <Alarma>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          alarmas.add(Alarma.fromMap(item));
        }
      }
      return alarmas;
    } catch (e) {
      Registro.instancia.add('Almacenamiento: ERROR al cargar alarmas -> $e');
      return <Alarma>[];
    }
  }

  Future<void> guardar(List<Alarma> alarmas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clave,
      jsonEncode(alarmas.map((a) => a.toMap()).toList()),
    );
  }
}
