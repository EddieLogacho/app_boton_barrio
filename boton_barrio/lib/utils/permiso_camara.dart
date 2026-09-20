import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'permiso_ubicacion.dart';

class PermisoCamara {
  static const _kYaPedido = 'permiso_camara_ya_pedido';

  /// Android no distingue "nunca pedido" de "denegado", así que lo
  /// diferenciamos con una marca guardada en local.
  static Future<EstadoPermiso> estadoActual() async {
    final status = await Permission.camera.status;

    if (status.isGranted || status.isLimited) return EstadoPermiso.concedido;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return EstadoPermiso.denegadoPermanente;
    }

    final prefs = await SharedPreferences.getInstance();
    final yaPedido = prefs.getBool(_kYaPedido) ?? false;
    return yaPedido ? EstadoPermiso.denegado : EstadoPermiso.noDeterminado;
  }

  static Future<EstadoPermiso> solicitar(BuildContext context) async {
    final estado = await estadoActual();
    if (estado == EstadoPermiso.concedido) return estado;
    if (!context.mounted) return estado;

    if (estado == EstadoPermiso.denegadoPermanente) {
      final abrir = await _dialogo(
        context,
        titulo: 'Permiso de cámara bloqueado',
        mensaje:
            'Bloqueaste el acceso a la cámara. Sin ella no puedes adjuntar una '
            'foto de lo que ocurre. Puedes activarlo en Ajustes > Permisos.',
        textoBoton: 'Abrir ajustes',
      );
      if (abrir == true) await openAppSettings();
      return estado;
    }

    final continuar = await _dialogo(
      context,
      titulo: 'Necesitamos tu cámara',
      mensaje:
          'Botón de Barrio usa la cámara solo para que puedas adjuntar una foto '
          'de lo que está pasando y tus vecinos lo vean en la alerta.',
      textoBoton: 'Continuar',
    );
    if (continuar != true) return estado;

    await Permission.camera.request();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kYaPedido, true);
    return estadoActual();
  }

  /// Pide el permiso si hace falta y abre la cámara. Devuelve null si no
  /// hay permiso o si el usuario cancela.
  static Future<File?> tomarFoto(BuildContext context) async {
    final estado = await solicitar(context);

    if (estado != EstadoPermiso.concedido) {
      if (context.mounted && estado == EstadoPermiso.denegado) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin permiso de cámara no se puede adjuntar la foto.'),
          ),
        );
      }
      return null;
    }

    final imagen = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 1280,
    );
    if (imagen == null) return null;
    return File(imagen.path);
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