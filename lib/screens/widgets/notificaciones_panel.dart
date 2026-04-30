import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../servicios/notificaciones_service.dart';
import 'package:intl/intl.dart';
import '../servicios/whatsapp_bot_service.dart';

class NotificacionesPanel extends StatefulWidget {
  final String rol;

  const NotificacionesPanel({super.key, required this.rol});

  @override
  State<NotificacionesPanel> createState() => _NotificacionesPanelState();
}

class _NotificacionesPanelState extends State<NotificacionesPanel> {
  final NotificacionesService _service = NotificacionesService();
  List<Notificacion> _notificaciones = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final notas = await _service.obtenerNotificaciones(widget.rol);
    if (mounted) {
      setState(() {
        _notificaciones = notas;
        _cargando = false;
      });
    }
  }

  IconData _getIcono(String tipo) {
    switch (tipo) {
      case 'pedido_hoy':
        return Icons.shopping_basket_rounded;
      case 'pedido_manana':
        return Icons.schedule_rounded;
      case 'inventario':
        return Icons.warning_amber_rounded;
      case 'cobranza':
        return Icons.attach_money_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColor(String tipo, bool esCritica) {
    if (esCritica) return Colors.red.shade600;
    switch (tipo) {
      case 'pedido_hoy':
        return Colors.orange.shade600;
      case 'pedido_manana':
        return Colors.blue.shade600;
      case 'inventario':
        return Colors.amber.shade700;
      case 'cobranza':
        return Colors.green.shade600;
      default:
        return const Color(0xFF8C5535);
    }
  }

  Future<void> _enviarAWhatsapp() async {
    if (_notificaciones.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay notificaciones para enviar.'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    final buffer = StringBuffer();
    final fechaFormateada = DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now());
    
    buffer.writeln('*🎂 RESUMEN DE TAREAS - LA ESTRELLA 🎂*');
    buffer.writeln('_Generado el: ${fechaFormateada}_\n');

    final urgentes = _notificaciones.where((n) => n.esCritica).toList();
    final normales = _notificaciones.where((n) => !n.esCritica && n.tipo != 'cobranza').toList();
    final cobranza = _notificaciones.where((n) => n.tipo == 'cobranza').toList();

    if (urgentes.isNotEmpty) {
      buffer.writeln('🚨 *URGENTE* 🚨');
      for (var n in urgentes) {
        buffer.writeln('• *${n.titulo}*: ${n.descripcion}');
      }
      buffer.writeln('');
    }

    if (normales.isNotEmpty) {
      buffer.writeln('📋 *PENDIENTES DE PRODUCCIÓN E INVENTARIO* 📋');
      for (var n in normales) {
        buffer.writeln('• *${n.titulo}*: ${n.descripcion}');
      }
      buffer.writeln('');
    }

    if (cobranza.isNotEmpty) {
      buffer.writeln('💰 *COBRANZA* 💰');
      for (var n in cobranza) {
        buffer.writeln('• *${n.titulo}*: ${n.descripcion}');
      }
    }

    final numeroTel = '5215514236028'; 
    final mensaje = buffer.toString();
    
    // Mostramos un indicador de carga
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enviando reporte mediante el bot...'), backgroundColor: Color(0xFF8C5535)),
      );
    }

    final exito = await WhatsAppBotService.sendMessage(mensaje);

    if (mounted) {
      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Reporte enviado exitosamente a tu WhatsApp! 🤖'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar el reporte. Intenta más tarde.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400, // Ancho fijo para el panel lateral
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(-5, 0)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header del Drawer
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Color(0xFF8C5535), size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Centro de Tareas',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Contenido
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8C5535)))
                : _notificaciones.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green.shade200),
                            const SizedBox(height: 16),
                            Text('¡Todo al día!', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('No hay tareas pendientes urgentes.', style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ).animate().fade().scale(),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF8C5535),
                        onRefresh: _cargar,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _notificaciones.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final n = _notificaciones[index];
                            final color = _getColor(n.tipo, n.esCritica);
                            
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: n.esCritica ? color.withOpacity(0.5) : Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(_getIcono(n.tipo), color: color, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                n.titulo,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                            ),
                                            if (n.esCritica)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade50,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.red.shade200),
                                                ),
                                                child: Text('URGENTE', style: TextStyle(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(n.descripcion, style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fade(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.1);
                          },
                        ),
                      ),
          ),

          // Botón fijo abajo para enviar reporte a WhatsApp
          if (!_cargando)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.black12)),
              ),
              child: FilledButton.icon(
                icon: const Icon(Icons.send_rounded, size: 20),
                label: const Text('Enviar reporte a WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), // Color de WhatsApp
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _enviarAWhatsapp,
              ).animate().fade().slideY(begin: 0.5),
            ),
        ],
      ),
    );
  }
}
