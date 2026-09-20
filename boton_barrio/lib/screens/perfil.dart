import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PerfilScreen extends StatefulWidget {
  final String correo;

  const PerfilScreen({super.key, required this.correo});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  Map<String, dynamic>? _usuario;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    try {
      final respuesta = await http.get(
        Uri.parse('http://localhost:3001/usuario/${widget.correo}'),
      );

      final datos = jsonDecode(respuesta.body);

      if (respuesta.statusCode == 200 && datos['exito'] == true) {
        setState(() {
          _usuario = datos['usuario'];
          _cargando = false;
        });
      } else {
        setState(() {
          _error = datos['mensaje'] ?? 'No se pudo cargar el perfil';
          _cargando = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'No se pudo conectar al servidor: $e';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const azulMarino = Color(0xFF0D2B5E);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : CustomScrollView(
                  slivers: [
                    // Cabecera azul con avatar
                    SliverAppBar(
                      backgroundColor: azulMarino,
                      expandedHeight: 220,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          color: azulMarino,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 30),
                              CircleAvatar(
                                radius: 44,
                                backgroundColor: Colors.white,
                                child: Text(
                                  _usuario!['nombre'][0].toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: azulMarino),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${_usuario!['nombre']} ${_usuario!['apellido']}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _usuario!['correo'],
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Tarjeta con los datos, superpuesta
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _filaDato(
                                icono: Icons.badge_outlined,
                                etiqueta: 'Nombre completo',
                                valor:
                                    '${_usuario!['nombre']} ${_usuario!['apellido']}',
                                color: azulMarino,
                              ),
                              const Divider(height: 28),
                              _filaDato(
                                icono: Icons.email_outlined,
                                etiqueta: 'Correo electrónico',
                                valor: _usuario!['correo'],
                                color: azulMarino,
                              ),
                              const Divider(height: 28),
                              _filaDato(
                                icono: Icons.calendar_today_outlined,
                                etiqueta: 'Miembro desde',
                                valor: _usuario!['fecha_registro']
                                    .toString()
                                    .substring(0, 10),
                                color: azulMarino,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _filaDato({
    required IconData icono,
    required String etiqueta,
    required String valor,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icono, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                etiqueta,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}