import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarma.dart';

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
      final lista = jsonDecode(bruto) as List;
      return lista
          .map<Alarma>((e) => Alarma.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
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
