import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Mensaje {
  final String texto;
  final bool esUsuario;
  Mensaje(this.texto, this.esUsuario);
}

class AsistenteScreen extends StatefulWidget {
  const AsistenteScreen({super.key});

  @override
  State<AsistenteScreen> createState() => _AsistenteScreenState();
}

class _AsistenteScreenState extends State<AsistenteScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Mensaje> _mensajes = [
    Mensaje(
        '¡Hola! Soy tu asistente de seguridad. Pregúntame sobre qué hacer ante robos, emergencias o consejos de prevención en tu barrio.',
        false),
  ];
  bool _cargando = false;

  Future<void> _enviarPregunta() async {
    final pregunta = _controller.text.trim();
    if (pregunta.isEmpty) return;

    setState(() {
      _mensajes.add(Mensaje(pregunta, true));
      _cargando = true;
      _controller.clear();
    });

    try {
      final respuesta = await http.post(
        Uri.parse('http://localhost:3001/asistente'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pregunta': pregunta}),
      );

      final datos = jsonDecode(respuesta.body);

      setState(() {
        if (respuesta.statusCode == 200 && datos['exito'] == true) {
          _mensajes.add(Mensaje(datos['respuesta'], false));
        } else {
          _mensajes.add(Mensaje('No pude responder en este momento.', false));
        }
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _mensajes.add(Mensaje('No se pudo conectar al servidor: $e', false));
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const azulMarino = Color(0xFF0D2B5E);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      appBar: AppBar(
        title: const Text('Asistente de Seguridad'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _mensajes.length,
              itemBuilder: (context, index) {
                final mensaje = _mensajes[index];
                return Align(
                  alignment: mensaje.esUsuario
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: mensaje.esUsuario ? azulMarino : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      mensaje.texto,
                      style: TextStyle(
                        color: mensaje.esUsuario ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu pregunta...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: azulMarino,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _cargando ? null : _enviarPregunta,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}