import 'package:flutter/material.dart';
import 'screens/splash.dart';

void main() {
  runApp(const BotonDeBarrioApp());
}

class BotonDeBarrioApp extends StatelessWidget {
  const BotonDeBarrioApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Azul marino, tomado del logo
    const azulMarino = Color(0xFF0D2B5E);
    // Celeste muy claro, para el fondo
    const celesteClaro = Color(0xFFEAF6FF);

    return MaterialApp(
      title: 'Botón de Barrio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: azulMarino,
        scaffoldBackgroundColor: celesteClaro,
        colorScheme: ColorScheme.fromSeed(
          seedColor: azulMarino,
          primary: azulMarino,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: azulMarino,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: azulMarino,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        useMaterial3: true,
      ),
      home: const SplashDecider(),
    );
  }
}