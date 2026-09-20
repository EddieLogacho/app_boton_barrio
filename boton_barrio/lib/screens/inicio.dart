import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'perfil.dart';
import 'eventos.dart';
import 'emergencias.dart';
import 'panico.dart';
import 'alertas.dart';
import 'asistente.dart';

class InicioScreen extends StatelessWidget {
  final String nombre;
  final String correo;

  const InicioScreen({super.key, required this.nombre, required this.correo});

  Future<void> _cerrarSesion(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('nombre_usuario');
    await prefs.remove('correo_usuario');

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const azulMarino = Color(0xFF0D2B5E);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Botón de Barrio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => _cerrarSesion(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, $nombre 👋',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: azulMarino),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tu barrio, más seguro.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),

              // Botón de pánico, grande y protagonista
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => PanicoScreen(correo: correo)),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.white, size: 44),
                      SizedBox(height: 8),
                      Text(
                        'BOTÓN DE PÁNICO',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),
              const Text(
                'Accesos rápidos',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: azulMarino),
              ),
              const SizedBox(height: 12),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.1,
                children: [
                  _tarjeta(
                    context,
                    icono: Icons.person,
                    texto: 'Mi Perfil',
                    color: azulMarino,
                    destino: PerfilScreen(correo: correo),
                  ),
                  _tarjeta(
                    context,
                    icono: Icons.event,
                    texto: 'Eventos',
                    color: azulMarino,
                    destino: const EventosScreen(),
                  ),
                  _tarjeta(
                    context,
                    icono: Icons.local_police,
                    texto: 'Emergencias',
                    color: Colors.red.shade700,
                    destino: const EmergenciasScreen(),
                  ),
                  _tarjeta(
                    context,
                    icono: Icons.report_problem,
                    texto: 'Alertas',
                    color: Colors.orange.shade800,
                    destino: AlertasScreen(correo: correo),
                  ),
                    _tarjeta(
                    context,
                    icono: Icons.smart_toy,
                    texto: 'Asistente IA',
                    color: Colors.teal.shade700,
                    destino: const AsistenteScreen(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(
    BuildContext context, {
    required IconData icono,
    required String texto,
    required Color color,
    required Widget destino,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => destino));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 36, color: color),
            const SizedBox(height: 10),
            Text(
              texto,
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}