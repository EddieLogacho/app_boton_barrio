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

  void _abrirComentarios(dynamic alerta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _ComentariosSheet(
        alertaId: alerta['id'],
        correo: widget.correo,
        onTotal: (total) {
          if (mounted) setState(() => alerta['total_comentarios'] = total);
        },
      ),
    );
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
                              Wrap(
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _abrirEnMaps(
                                      double.parse(
                                          alerta['latitud'].toString()),
                                      double.parse(
                                          alerta['longitud'].toString()),
                                    ),
                                    icon: const Icon(Icons.location_on,
                                        size: 18),
                                    label: const Text('Ver ubicación en Maps'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _abrirComentarios(alerta),
                                    icon: const Icon(
                                        Icons.chat_bubble_outline,
                                        size: 18),
                                    label: Text(
                                        'Comentarios (${alerta['total_comentarios'] ?? 0})'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

// ------------------- COMENTARIOS -------------------

class _ComentariosSheet extends StatefulWidget {
  final dynamic alertaId;
  final String correo;
  final void Function(int total) onTotal;

  const _ComentariosSheet({
    required this.alertaId,
    required this.correo,
    required this.onTotal,
  });

  @override
  State<_ComentariosSheet> createState() => _ComentariosSheetState();
}

class _ComentariosSheetState extends State<_ComentariosSheet> {
  final TextEditingController _controller = TextEditingController();

  List<dynamic> _comentarios = [];
  bool _cargando = true;
  bool _enviando = false;
  String? _error;
  String? _mensaje;

  String get _base =>
      'http://localhost:3001/alertas/${widget.alertaId}/comentarios';
  String get _correoQuery => Uri.encodeQueryComponent(widget.correo);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final respuesta = await http
          .get(Uri.parse('$_base?correo=$_correoQuery'))
          .timeout(const Duration(seconds: 10));
      final datos = jsonDecode(respuesta.body);

      if (!mounted) return;

      if (respuesta.statusCode == 200 && datos['exito'] == true) {
        setState(() {
          _comentarios = datos['comentarios'];
          _cargando = false;
          _error = null;
        });
        widget.onTotal(_comentarios.length);
      } else {
        setState(() {
          _error = 'No se pudieron cargar los comentarios';
          _cargando = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Sin conexión al servidor';
        _cargando = false;
      });
    }
  }

  Future<void> _enviar() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty || _enviando) return;

    setState(() {
      _enviando = true;
      _mensaje = null;
    });

    try {
      final respuesta = await http
          .post(
            Uri.parse(_base),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'correo': widget.correo, 'texto': texto}),
          )
          .timeout(const Duration(seconds: 10));
      final datos = jsonDecode(respuesta.body);

      if (!mounted) return;

      if (respuesta.statusCode == 200 && datos['exito'] == true) {
        _controller.clear();
        FocusScope.of(context).unfocus();
        await _cargar();
      } else {
        setState(() =>
            _mensaje = datos['mensaje'] ?? 'No se pudo enviar el comentario');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _mensaje = 'Sin conexión al servidor');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _borrar(dynamic comentarioId) async {
    try {
      final respuesta = await http
          .delete(Uri.parse('$_base/$comentarioId?correo=$_correoQuery'))
          .timeout(const Duration(seconds: 10));
      final datos = jsonDecode(respuesta.body);

      if (!mounted) return;

      if (respuesta.statusCode == 200 && datos['exito'] == true) {
        setState(() => _mensaje = null);
        await _cargar();
      } else {
        setState(() =>
            _mensaje = datos['mensaje'] ?? 'No se pudo borrar el comentario');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _mensaje = 'Sin conexión al servidor');
    }
  }

  String _formatearFecha(dynamic valor) {
    final fecha = DateTime.tryParse(valor?.toString() ?? '')?.toLocal();
    if (fecha == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(fecha.day)}/${dos(fecha.month)} ${dos(fecha.hour)}:${dos(fecha.minute)}';
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_comentarios.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aún no hay comentarios. Sé el primero en aportar información.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _comentarios.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final c = _comentarios[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c['nombre']?.toString() ?? 'Vecino',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatearFecha(c['fecha']),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(c['texto']?.toString() ?? ''),
                  ],
                ),
              ),
              if (c['es_mio'] == true)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Borrar',
                  onPressed: () => _borrar(c['id']),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Comentarios',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Aporta, corrige o amplía la información de esta alerta.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ),
            const Divider(height: 20),
            Expanded(child: _cuerpo()),
            if (_mensaje != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  _mensaje!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 300,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un comentario...',
                          border: OutlineInputBorder(),
                          counterText: '',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: _enviando ? null : _enviar,
                      icon: _enviando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}