import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'crear_evento.dart';

class EventosScreen extends StatefulWidget {
  const EventosScreen({super.key});

  @override
  State<EventosScreen> createState() => _EventosScreenState();
}

class _EventosScreenState extends State<EventosScreen> {
  List<dynamic> _eventos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarEventos();
  }

  Future<void> _cargarEventos() async {
    setState(() => _cargando = true);
    try {
      final respuesta = await http.get(
        Uri.parse('http://localhost:3001/eventos'),
      );

      final datos = jsonDecode(respuesta.body);

      if (respuesta.statusCode == 200 && datos['exito'] == true) {
        setState(() {
          _eventos = datos['eventos'];
          _cargando = false;
        });
      } else {
        setState(() {
          _error = 'No se pudieron cargar los eventos';
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

  Future<void> _irACrearEvento() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CrearEventoScreen()),
    );

    // Si se creó un evento nuevo, recargamos la lista
    if (resultado == true) {
      _cargarEventos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos comunitarios'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _irACrearEvento,
        child: const Icon(Icons.add),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _eventos.isEmpty
                  ? const Center(child: Text('No hay eventos por ahora'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _eventos.length,
                      itemBuilder: (context, index) {
                        final evento = _eventos[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(Icons.event, color: Colors.deepPurple),
                            title: Text(
                              evento['titulo'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(evento['descripcion'] ?? ''),
                                const SizedBox(height: 4),
                                Text('📅 ${evento['fecha'].toString().substring(0, 10)}'),
                                if (evento['lugar'] != null)
                                  Text('📍 ${evento['lugar']}'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}