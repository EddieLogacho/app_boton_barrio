import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergenciasScreen extends StatelessWidget {
  const EmergenciasScreen({super.key});

  Future<void> _confirmarLlamada(
      BuildContext context, String titulo, String numero) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Llamar a $titulo'),
        content: Text('¿Deseas llamar al $numero ahora?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Llamar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final uri = Uri(scheme: 'tel', path: numero);
      final pudoAbrir = await launchUrl(uri);

      if (!pudoAbrir && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el marcador telefónico')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const azulMarino = Color(0xFF0D2B5E);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      appBar: AppBar(
        title: const Text('Emergencias'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Toca una opción para llamar de inmediato',
              style: TextStyle(fontSize: 15, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            _tarjetaEmergencia(
              context,
              icono: Icons.local_police,
              texto: 'Policía',
              numero: '911',
              color: azulMarino,
            ),
            const SizedBox(height: 16),
            _tarjetaEmergencia(
              context,
              icono: Icons.local_fire_department,
              texto: 'Bomberos',
              numero: '911',
              color: Colors.red.shade700,
            ),
            const SizedBox(height: 16),
            _tarjetaEmergencia(
              context,
              icono: Icons.medical_services,
              texto: 'Ambulancia (ECU 911)',
              numero: '911',
              color: Colors.green.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaEmergencia(
    BuildContext context, {
    required IconData icono,
    required String texto,
    required String numero,
    required Color color,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _confirmarLlamada(context, texto, numero),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}