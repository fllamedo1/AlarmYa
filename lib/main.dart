import 'package:flutter/material.dart';

import 'screens/pantalla_mision.dart';
import 'screens/pantalla_principal.dart';
import 'services/servicio_ajustes.dart';
import 'services/servicio_notificaciones.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServicioNotificaciones.instancia.inicializar();
  await ServicioAjustes.instancia.cargar();
  runApp(const AlarmYaApp());
}

class AlarmYaApp extends StatefulWidget {
  const AlarmYaApp({super.key});

  @override
  State<AlarmYaApp> createState() => _AlarmYaAppState();
}

class _AlarmYaAppState extends State<AlarmYaApp> {
  final navigatorKey = GlobalKey<NavigatorState>();

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
    // Si la app arrancó fría porque el usuario tocó la notificación de
    // alarma, abrimos la misión que quedó pendiente.
    final pendiente = ServicioNotificaciones.instancia.tomarMisionPendiente();
    if (pendiente != null) {
      ServicioNotificaciones.instancia.alAbrirMision?.call(pendiente);
    }
    // Pedir permiso de notificaciones al primer arranque.
    ServicioNotificaciones.instancia.pedirPermiso();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlarmYa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFFFFB300),      // amarillo/naranja Alarmy
          secondary: Color(0xFFFF9800),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F4F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F4F6),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF222222),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? const Color(0xFFFFB300)
                : Colors.white,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? const Color(0xFFFFB300)
                : const Color(0xFFDDDDDD),
          ),
          trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? const Color(0xFFFFB300)
                : const Color(0xFFBBBBBB),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFB300),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      navigatorKey: navigatorKey,
      home: const PantallaPrincipal(),
    );
  }
}
