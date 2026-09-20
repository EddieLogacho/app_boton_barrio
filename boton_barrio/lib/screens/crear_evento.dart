import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CrearEventoScreen extends StatefulWidget {
  const CrearEventoScreen({super.key});

  @override
  State<CrearEventoScreen> createState() => _CrearEventoScreenState();
}

class _CrearEventoScreenState extends State<CrearEventoScreen> {
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _lugarController = TextEditingController();
  DateTime? _fechaSeleccionada;
  bool _guardando = false;

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (fecha != null) {
      setState(() => _fechaSeleccionada = fecha);
    }
  }

  Future<void> _guardarEvento() async {
    if (_tituloController.text.isEmpty || _fechaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falta el título o la fecha')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final respuesta = await http.post(
        Uri.parse('http://localhost:3001/eventos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'titulo': _tituloController.text,
          'descripcion': _descripcionController.text,
          'fecha': _fechaSeleccionada!.toIso8601String().substring(0, 10),
          'lugar': _lugarController.text,
        }),
      );

      final datos = jsonDecode(respuesta.body);

      if (respuesta.statusCode == 200 && datos['exito'] == true) {
        if (!mounted) return;
        Navigator.pop(context, true); // true indica que se creó uno nuevo
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(datos['mensaje'] ?? 'Error al crear el evento')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo conectar al servidor: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo evento'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descripcionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lugarController,
              decoration: const InputDecoration(
                labelText: 'Lugar',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _elegirFecha,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _fechaSeleccionada == null
                    ? 'Elegir fecha'
                    : _fechaSeleccionada!.toIso8601String().substring(0, 10),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardarEvento,
                child: _guardando
                    ? const CircularProgressIndicator()
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Guardar evento'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}