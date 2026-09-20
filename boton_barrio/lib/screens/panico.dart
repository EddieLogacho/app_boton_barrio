import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import '../utils/permiso_ubicacion.dart';
import '../utils/permiso_camara.dart';

class PanicoScreen extends StatefulWidget {
  final String correo;

  const PanicoScreen({super.key, required this.correo});

  @override
  State<PanicoScreen> createState() => _PanicoScreenState();
}

class _PanicoScreenState extends State<PanicoScreen> {
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _descripcionController = TextEditingController();

  bool _sonando = false;
  String _estadoUbicacion = '';
  bool _permisoBloqueado = false;

  dynamic _alertaId;
  bool _enviandoDetalle = false;
  bool _detalleEnviado = false;

  File? _foto;
  bool _enviandoFoto = false;
  bool _fotoEnviada = false;

  Future<void> _activarSirena() async {
    setState(() {
      _sonando = true;
      _estadoUbicacion = 'Obteniendo tu ubicación...';
      _permisoBloqueado = false;
    });

    // La sirena suena de inmediato, sin esperar permisos ni ubicación
    await _player.setPlayerMode(PlayerMode.lowLatency);
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource('sounds/sirena.mp3'));

    if (!mounted) return;
    _registrarAlertaDePanico();
  }

  String _mensajeSinUbicacion(EstadoPermiso estado) {
    switch (estado) {
      case EstadoPermiso.denegadoPermanente:
        return 'Permiso de ubicación bloqueado. Actívalo en Ajustes.';
      case EstadoPermiso.denegado:
        return 'Sin permiso de ubicación. La sirena sigue activa.';
      case EstadoPermiso.noDeterminado:
        return 'Ubicación no autorizada. La sirena sigue activa.';
      case EstadoPermiso.concedido:
        return 'No se pudo obtener la ubicación.';
    }
  }

  Future<void> _registrarAlertaDePanico() async {
    try {
      // 1. Permiso: se pide aquí, en el momento de uso, con explicación previa
      final estado = await PermisoUbicacion.solicitar(context);
      if (!mounted) return;
      setState(() =>
          _permisoBloqueado = estado == EstadoPermiso.denegadoPermanente);

      double? lat;
      double? lng;
      String? aviso;
      String mensajeAlerta = 'Alarma activada, posible emergencia en curso';

      // 2. Ubicación actual (solo si hay permiso y el GPS está encendido)
      if (estado == EstadoPermiso.concedido) {
        final gpsActivo = await Geolocator.isLocationServiceEnabled();
        if (gpsActivo) {
          try {
            final posicion = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 10),
              ),
            );
            lat = posicion.latitude;
            lng = posicion.longitude;
            await PermisoUbicacion.guardarUltimaUbicacion(lat, lng);
          } catch (_) {
            aviso = 'No se pudo obtener la ubicación a tiempo.';
          }
        } else {
          aviso = 'GPS apagado. Actívalo para una ubicación exacta.';
        }
      } else {
        aviso = _mensajeSinUbicacion(estado);
      }

      // 3. Degradación: si no hay ubicación actual, usamos la última conocida
      if (lat == null || lng == null) {
        final ultima = await PermisoUbicacion.ultimaUbicacion();
        if (ultima == null) {
          if (!mounted) return;
          setState(() => _estadoUbicacion =
              '${aviso ?? 'Sin ubicación'} La alerta no se registró.');
          return;
        }
        lat = ultima.lat;
        lng = ultima.lng;
        mensajeAlerta += ' (última ubicación conocida)';
        aviso = '${aviso ?? 'Sin ubicación actual.'} Se usó la última conocida.';
      }

      // 4. Registro en el backend (con tiempo límite para no quedarse colgado)
      final respuesta = await http
          .post(
            Uri.parse('http://localhost:3001/alertas'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'tipo': 'Botón de pánico',
              'mensaje': mensajeAlerta,
              'latitud': lat,
              'longitud': lng,
              'creado_por': widget.correo,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final datos = jsonDecode(respuesta.body);

      if (!mounted) return;

      if (respuesta.statusCode == 200 && datos['exito'] == true) {
        setState(() {
          _estadoUbicacion = aviso ?? 'Ubicación registrada ✓';
          final alerta = datos['alerta'];
          _alertaId = alerta != null ? alerta['id'] : datos['id'];
        });
      } else {
        setState(() => _estadoUbicacion = 'No se pudo registrar la alerta');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _estadoUbicacion = 'Sirena sonando (sin conexión al servidor)');
    }
  }

  Future<void> _enviarDetalle() async {
    final texto = _descripcionController.text.trim();
    if (texto.isEmpty || _alertaId == null) return;

    setState(() => _enviandoDetalle = true);

    try {
      final respuesta = await http
          .put(
            Uri.parse('http://localhost:3001/alertas/$_alertaId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'mensaje': texto}),
          )
          .timeout(const Duration(seconds: 10));

      final datos = jsonDecode(respuesta.body);

      if (!mounted) return;

      if (respuesta.statusCode == 200 && datos['exito'] == true) {
        FocusScope.of(context).unfocus();
        setState(() {
          _enviandoDetalle = false;
          _detalleEnviado = true;
        });
      } else {
        setState(() => _enviandoDetalle = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron enviar los detalles')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviandoDetalle = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin conexión al servidor')),
      );
    }
  }

  Future<void> _tomarFoto() async {
    if (_alertaId == null) return;

    final foto = await PermisoCamara.tomarFoto(context);
    if (foto == null || !mounted) return;

    setState(() {
      _foto = foto;
      _fotoEnviada = false;
    });
    await _subirFoto();
  }

  Future<void> _subirFoto() async {
    if (_foto == null || _alertaId == null) return;

    setState(() => _enviandoFoto = true);

    try {
      final bytes = await _foto!.readAsBytes();
      final respuesta = await http
          .put(
            Uri.parse('http://localhost:3001/alertas/$_alertaId'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'foto': base64Encode(bytes)}),
          )
          .timeout(const Duration(seconds: 20));

      final datos = jsonDecode(respuesta.body);

      if (!mounted) return;

      if (respuesta.statusCode == 200 && datos['exito'] == true) {
        setState(() {
          _enviandoFoto = false;
          _fotoEnviada = true;
        });
      } else {
        setState(() => _enviandoFoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar la foto')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviandoFoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin conexión al servidor')),
      );
    }
  }

  Future<void> _detenerSirena() async {
    await _player.stop();
    _descripcionController.clear();
    setState(() {
      _sonando = false;
      _estadoUbicacion = '';
      _permisoBloqueado = false;
      _alertaId = null;
      _detalleEnviado = false;
      _enviandoDetalle = false;
      _foto = null;
      _enviandoFoto = false;
      _fotoEnviada = false;
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF6FF),
      appBar: AppBar(
        title: const Text('Botón de Pánico'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _sonando
                    ? 'Sirena activada. Toca de nuevo para detenerla.'
                    : 'Presiona el botón para activar la sirena y ahuyentar a un intruso o pedir ayuda.\nSe registrará tu ubicación automáticamente.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _sonando ? _detenerSirena : _activarSirena,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: _sonando ? Colors.grey : Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_sonando ? Colors.grey : Colors.red)
                            .withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    _sonando ? Icons.stop : Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _sonando ? 'Toca para detener' : 'Toca para activar',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              if (_estadoUbicacion.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _estadoUbicacion,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
              ],
              // Permiso bloqueado: acceso directo a los ajustes del sistema
              if (_permisoBloqueado) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings),
                  label: const Text('Abrir ajustes'),
                ),
              ],
              if (_sonando && _alertaId != null) ...[
                const SizedBox(height: 24),
                TextField(
                  controller: _descripcionController,
                  maxLines: 3,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: '¿Qué está pasando? (opcional)',
                    hintText: 'Ej: dos sujetos robando en un carro blanco',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _enviandoDetalle ? null : _enviarDetalle,
                    icon: _enviandoDetalle
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_detalleEnviado
                        ? 'Actualizar detalles'
                        : 'Enviar detalles'),
                  ),
                ),
                if (_detalleEnviado) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Detalles enviados ✓',
                    style: TextStyle(fontSize: 13, color: Colors.green),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _enviandoFoto ? null : _tomarFoto,
                    icon: _enviandoFoto
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt),
                    label: Text(_foto == null
                        ? 'Tomar foto (opcional)'
                        : 'Tomar otra foto'),
                  ),
                ),
                if (_foto != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _foto!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                if (_fotoEnviada) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Foto enviada ✓',
                    style: TextStyle(fontSize: 13, color: Colors.green),
                  ),
                ] else if (_foto != null && !_enviandoFoto) ...[
                  TextButton(
                    onPressed: _subirFoto,
                    child: const Text('Reintentar envío de la foto'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}