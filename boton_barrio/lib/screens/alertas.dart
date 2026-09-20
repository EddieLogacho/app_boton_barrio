import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'crear_alerta.dart';

class AlertasScreen extends StatefulWidget {
  final String correo;

  const AlertasScreen({super.key, required this.correo});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  List<dynamic> _alertas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarAlertas();
  }

  Future<void> _cargarAlertas() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final respuesta = await http.get(
        Uri.parse('http://localhost:3001/alertas'),
      );

      final datos = jsonDecode(respuesta.body);

      if (respuesta.statusCode == 200 && datos['exito'] == true) {
        setState(() {
          _alertas = datos['alertas'];
          _cargando = false;
        });
      } else {
        setState(() {
          _error = 'No se pudieron cargar las alertas';
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

  Future<void> _abrirEnMaps(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _irACrearAlerta() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => CrearAlertaScreen(correo: widget.correo)),
    );

    if (resultado == true) {
      _cargarAlertas();
    }
  }

  bool _tieneFoto(dynamic alerta) {
    final foto = alerta['foto'];
    return foto != null && foto.toString().isNotEmpty;
  }

  Widget _fotoAlerta(String fotoBase64) {
    try {
      final bytes = base64Decode(fotoBase64);
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              child: InteractiveViewer(
                child: Image.memory(bytes),
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            bytes,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => const Text(
              'No se pudo mostrar la foto',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ),
      );
    } catch (_) {
      return const Text(
        'No se pudo mostrar la foto',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const azulMarino = Color(0xFF0D2B5E);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      appBar: AppBar(
        title: const Text('Alertas del barrio'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: azulMarino,
        onPressed: _irACrearAlerta,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _alertas.isEmpty
                  ? const Center(child: Text('No hay alertas por ahora'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _alertas.length,
                      itemBuilder: (context, index) {
                        final alerta = _alertas[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.report_problem,
                                      color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      alerta['tipo'] ?? 'Alerta',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              if (alerta['mensaje'] != null &&
                                  alerta['mensaje'].toString().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(alerta['mensaje']),
                              ],
                              if (_tieneFoto(alerta)) ...[
                                const SizedBox(height: 10),
                                _fotoAlerta(alerta['foto'].toString()),
                              ],
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () => _abrirEnMaps(
                                  double.parse(alerta['latitud'].toString()),
                                  double.parse(alerta['longitud'].toString()),
                                ),
                                icon: const Icon(Icons.location_on, size: 18),
                                label: const Text('Ver ubicación en Maps'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}