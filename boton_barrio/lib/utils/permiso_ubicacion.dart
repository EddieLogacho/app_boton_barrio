import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Los 4 estados del permiso de ubicación
enum EstadoPermiso { noDeterminado, concedido, denegado, denegadoPermanente }

class PermisoUbicacion {
  static const _kYaPedido = 'permiso_ubicacion_ya_pedido';
  static const _kEstado = 'permiso_ubicacion_estado';
  static const _kLat = 'ubicacion_ultima_lat';
  static const _kLng = 'ubicacion_ultima_lng';

  /// Lee el estado real del permiso. Android no distingue "nunca pedido" de
  /// "denegado", así que lo diferenciamos con una marca guardada en local.
  static Future<EstadoPermiso> estadoActual() async {
    final status = await Permission.locationWhenInUse.status;
    EstadoPermiso estado;

    if (status.isGranted || status.isLimited) {
      estado = EstadoPermiso.concedido;
    } else if (status.isPermanentlyDenied || status.isRestricted) {
      estado = EstadoPermiso.denegadoPermanente;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final yaPedido = prefs.getBool(_kYaPedido) ?? false;
      estado = yaPedido ? EstadoPermiso.denegado : EstadoPermiso.noDeterminado;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEstado, estado.name);
    return estado;
  }

  /// Se llama en el momento de usar la ubicación. Explica para qué se necesita
  /// antes de pedir el permiso y maneja cada estado.
  static Future<EstadoPermiso> solicitar(BuildContext context) async {
    final estado = await estadoActual();
    if (estado == EstadoPermiso.concedido) return estado;
    if (!context.mounted) return estado;

    // Bloqueado: solo se puede arreglar desde los ajustes del sistema
    if (estado == EstadoPermiso.denegadoPermanente) {
      final abrir = await _dialogo(
        context,
        titulo: 'Permiso de ubicación bloqueado',
        mensaje:
            'Bloqueaste el acceso a la ubicación. Sin ella no podemos registrar '
            'dónde ocurre la emergencia. Puedes activarlo en Ajustes > Permisos.',
        textoBoton: 'Abrir ajustes',
      );
      if (abrir == true) await openAppSettings();
      return estado;
    }

    // No determinado o denegado: explicamos y luego pedimos
    final continuar = await _dialogo(
      context,
      titulo: 'Necesitamos tu ubicación',
      mensaje:
          'Botón de Barrio usa tu ubicación solo para registrar dónde ocurre '
          'una alerta y que tus vecinos puedan ubicarla en el mapa.',
      textoBoton: 'Continuar',
    );
    if (continuar != true) return estado;

    await Permission.locationWhenInUse.request();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kYaPedido, true);
    return estadoActual();
  }

  /// Guarda la última ubicación conocida (respaldo si luego falla el permiso o el GPS)
  static Future<void> guardarUltimaUbicacion(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLat, lat);
    await prefs.setDouble(_kLng, lng);
  }

  static Future<({double lat, double lng})?> ultimaUbicacion() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kLat);
    final lng = prefs.getDouble(_kLng);
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }

  static Future<bool?> _dialogo(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    required String textoBoton,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(textoBoton),
          ),
        ],
      ),
    );
  }
}