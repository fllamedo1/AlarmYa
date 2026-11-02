import 'package:flutter/material.dart';

import 'screens/pantalla_mision.dart';
import 'screens/pantalla_principal.dart';
import 'services/servicio_notificaciones.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServicioNotificaciones.instancia.inicializar();
  runApp(const AlarmYaApp());
}

class AlarmYaApp extends StatefulWidget {
  const AlarmYaApp({super.key});

  @override
  State<AlarmYaApp> createState() => _AlarmYaAppState();
}

class _AlarmYaAppState extends State<AlarmYaApp> {
  @override
  void initState() {
    super.initState();
    // Cuando el usuario toca la notificación de alarma, abrimos la misión.
    ServicioNotificaciones.instancia.alAbrirMision = (id) {
      final nav = navigatorKey.currentState;
      nav?.push(
        MaterialPageRoute(builder: (_) => PantallaMision(idAlarma: id)),
      );
    };
    // Pedir permiso de notificaciones al primer arranque.
    ServicioNotificaciones.instancia.pedirPermiso();
  }

  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlarmYa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFD32F2F),
          secondary: Colors.amberAccent,
          surface: const Color(0xFF1E1E1E),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      navigatorKey: navigatorKey,
      home: const PantallaPrincipal(),
    );
  }
}
