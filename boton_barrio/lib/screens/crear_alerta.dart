import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';

class CrearAlertaScreen extends StatefulWidget {
  final String correo;

  const CrearAlertaScreen({super.key, required this.correo});

  @override
  State<CrearAlertaScreen> createState() => _CrearAlertaScreenState();
}

class _CrearAlertaScreenState extends State<CrearAlertaScreen> {
  final TextEditingController _tipoController = TextEditingController();
  final TextEditingController _mensajeController = TextEditingController();

  Position? _ubicacion;
  bool _obteniendoUbicacion = false;
  String? _mensajeUbicacion;

  File? _foto;
  bool _obteniendoFoto = false;
  String? _mensajeFoto;

  bool _guardando = false;

  // ------------------- UBICACIÓN -------------------

  Future<void> _pedirUbicacion() async {
    // 1. Explicación previa, ANTES de pedir el permiso
    final continuar = await _mostrarExplicacion(
      titulo: 'Acceso a tu ubicación',
      mensaje:
          'Botón de Barrio necesita tu ubicación para marcar en el mapa exactamente dónde ocurre el problema que vas a reportar.',
    );
    if (continuar != true) return;

    setState(() {
      _obteniendoUbicacion = true;
      _mensajeUbicacion = null;
    });

    // 2. Verifica que el servicio de GPS del equipo esté encendido (condición aparte del permiso)
    final servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) {
      setState(() {
        _obteniendoUbicacion = false;
        _mensajeUbicacion = 'El GPS está apagado.';
      });
      _mostrarDialogoAjustes(
        titulo: 'Activa el GPS',
        mensaje: 'El servicio de ubicación de tu dispositivo está desactivado.',
        onIrAAjustes: () => Geolocator.openLocationSettings(),
      );
      return;
    }

    // 3. Estado actual del permiso
    LocationPermission permiso = await Geolocator.checkPermission();

    // Estado: no decidido todavía -> lo solicitamos
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }

    // Estado: denegado (el usuario dijo que no, pero puede volver a preguntar)
    if (permiso == LocationPermission.denied) {
      setState(() {
        _obteniendoUbicacion = false;
        _mensajeUbicacion =
            'Sin acceso a tu ubicación no podemos ubicar el reporte en el mapa.';
      });
      return;
    }

    // Estado: denegado permanentemente ("no volver a preguntar")
    if (permiso == LocationPermission.deniedForever) {
      setState(() {
        _obteniendoUbicacion = false;
        _mensajeUbicacion = 'Ubicación bloqueada permanentemente.';
      });
      _mostrarDialogoAjustes(
        titulo: 'Permiso bloqueado',
        mensaje:
            'Bloqueaste el permiso de ubicación permanentemente. Actívalo desde los ajustes de la app para poder reportar la ubicación.',
        onIrAAjustes: () => Geolocator.openAppSettings(),
      );
      return;
    }

    // Estado: concedido -> obtenemos la posición
    try {
      final posicion = await Geolocator.getCurrentPosition();
      setState(() {
        _ubicacion = posicion;
        _obteniendoUbicacion = false;
        _mensajeUbicacion = null;
      });
    } catch (e) {
      setState(() {
        _obteniendoUbicacion = false;
        _mensajeUbicacion = 'No se pudo obtener la ubicación: $e';
      });
    }
  }

  // ------------------- CÁMARA -------------------

  Future<void> _pedirFoto() async {
    final continuar = await _mostrarExplicacion(
      titulo: 'Acceso a tu cámara',
      mensaje:
          'Botón de Barrio necesita la cámara para adjuntar una foto como evidencia del problema que estás reportando.',
    );
    if (continuar != true) return;

    setState(() {
      _obteniendoFoto = true;
      _mensajeFoto = null;
    });

    final estado = await Permission.camera.status;

    PermissionStatus estadoFinal = estado;

    // Estado: no decidido todavía -> lo solicitamos
    if (estado.isDenied) {
      estadoFinal = await Permission.camera.request();
    }

    if (estadoFinal.isGranted) {
      final picker = ImagePicker();
      final imagen = await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
      if (imagen != null) {
        setState(() {
          _foto = File(imagen.path);
          _obteniendoFoto = false;
        });
      } else {
        setState(() => _obteniendoFoto = false);
      }
      return;
    }

    if (estadoFinal.isPermanentlyDenied) {
      setState(() {
        _obteniendoFoto = false;
        _mensajeFoto = 'Cámara bloqueada permanentemente.';
      });
      _mostrarDialogoAjustes(
        titulo: 'Permiso bloqueado',
        mensaje:
            'Bloqueaste el permiso de cámara permanentemente. Actívalo desde los ajustes de la app para poder adjuntar fotos.',
        onIrAAjustes: () => openAppSettings(),
      );
      return;
    }

    // Denegado (pero se puede volver a pedir)
    setState(() {
      _obteniendoFoto = false;
      _mensajeFoto = 'Puedes reportar sin foto, o intenta de nuevo.';
    });
  }

  // ------------------- UTILIDADES DE UI -------------------

  Future<bool?> _mostrarExplicacion({required String titulo, required String mensaje}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoAjustes({
    required String titulo,
    required String mensaje,
    required VoidCallback onIrAAjustes,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onIrAAjustes();
            },
            child: const Text('Ir a Ajustes'),
          ),
        ],
      ),
    );
  }

  // ------------------- GUARDAR -------------------

  Future<void> _guardarAlerta() async {
    if (_tipoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe qué tipo de problema es')),
      );
      return;
    }
    if (_ubicacion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero obtén tu ubicación')),
      );
      return;
    }

    setState(() => _guardando = true);

    String? fotoBase64;
    if (_foto != null) {
      final bytes = await _foto!.readAsBytes();
      fotoBase64 = base64Encode(bytes);
    }

    try {
      final respuesta = await http.post(
        Uri.parse('http://localhost:3001/alertas'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tipo': _tipoController.text,
          'mensaje': _mensajeController.text,
          'latitud': _ubicacion!.latitude,
          'longitud': _ubicacion!.longitude,
          'creado_por': widget.correo,
          'foto': fotoBase64,
        }),
      );

      final datos = jsonDecode(respuesta.body);

      if (respuesta.statusCode == 200 && datos['exito'] == true) {
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(datos['mensaje'] ?? 'Error al guardar la alerta')),
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
      backgroundColor: const Color(0xFFEAF6FF),
      appBar: AppBar(
        title: const Text('Reportar problema'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _tipoController,
              decoration: const InputDecoration(
                labelText: 'Tipo de problema (ej: bache, robo, tubería rota)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _mensajeController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Detalles (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            OutlinedButton.icon(
              onPressed: _obteniendoUbicacion ? null : _pedirUbicacion,
              icon: _obteniendoUbicacion
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
              label: Text(_ubicacion == null
                  ? 'Obtener mi ubicación'
                  : 'Ubicación obtenida ✓'),
            ),
            if (_mensajeUbicacion != null) ...[
              const SizedBox(height: 6),
              Text(_mensajeUbicacion!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            if (_ubicacion != null) ...[
              const SizedBox(height: 6),
              Text(
                'Lat: ${_ubicacion!.latitude.toStringAsFixed(5)}, Lng: ${_ubicacion!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],

            const SizedBox(height: 20),

            OutlinedButton.icon(
              onPressed: _obteniendoFoto ? null : _pedirFoto,
              icon: _obteniendoFoto
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.camera_alt),
              label: Text(_foto == null ? 'Adjuntar foto (opcional)' : 'Foto adjuntada ✓'),
            ),
            if (_mensajeFoto != null) ...[
              const SizedBox(height: 6),
              Text(_mensajeFoto!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            if (_foto != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(_foto!, height: 150, fit: BoxFit.cover, width: double.infinity),
              ),
            ],

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardarAlerta,
                child: _guardando
                    ? const CircularProgressIndicator()
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Reportar'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}