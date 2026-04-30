import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../carrito/carrito_provider.dart';
import './dialogo_ticket_venta.dart';
import '../servicios/whatsapp_bot_service.dart';

final supabase = Supabase.instance.client;

/// Token alfanumérico aleatorio para folios de venta POS.
String _generarFolioPOS() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rnd   = Random.secure();
  final token = List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
  final now   = DateTime.now();
  final fecha = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
  return 'POS-$fecha-$token';
}

class PagoVentaScreen extends StatefulWidget {
  const PagoVentaScreen({super.key});

  @override
  State<PagoVentaScreen> createState() => _PagoVentaScreenState();
}

class _PagoVentaScreenState extends State<PagoVentaScreen> {
  String _metodoPago = 'efectivo'; // 'efectivo', 'tarjeta', 'transferencia', 'mixto'
  final TextEditingController _montoRecibidoController = TextEditingController();
  bool _procesando = false;

  @override
  void dispose() {
    _montoRecibidoController.dispose();
    super.dispose();
  }

  Future<void> _finalizarVenta() async {
    final carrito = Provider.of<CarritoProvider>(context, listen: false);
    if (carrito.productos.isEmpty) return;

    final total = carrito.total;
    
    // Validación Efectivo
    if (_metodoPago == 'efectivo') {
      final monto = double.tryParse(_montoRecibidoController.text) ?? 0;
      if (monto < total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El monto recibido es menor al total')),
        );
        return;
      }
    }

    setState(() => _procesando = true);

    try {
      // 1. Generar Folio aleatorio para la venta
      final folio = _generarFolioPOS();

      // 2. Crear Venta cabecera
      final ventaRes = await supabase.from('ventas').insert({
        'folio': folio,
        'subtotal': total,
        'total': total,
        'metodo_pago': _metodoPago,
        'estado': 'completada',
      }).select('id_venta').single();

      final idVenta = ventaRes['id_venta'];

      // 3. Crear Pago Venta
      await supabase.from('pagos_venta').insert({
        'id_venta': idVenta,
        'tipo_pago': _metodoPago == 'mixto' ? 'efectivo' : _metodoPago, // Simplificación temporal para mixto
        'monto': total,
      });

      // 4. Crear Detalle de Venta
      final detalles = carrito.productos.map((p) {
        return {
          'id_venta': idVenta,
          'id_producto': p.idProducto,
          'id_variante': p.idVariante,
          'cantidad': p.cantidad,
          'precio_unitario': p.precio,
          'subtotal': p.precio * p.cantidad,
        };
      }).toList();

      await supabase.from('ventas_detalle').insert(detalles);

      // 5. Restar Inventario
      for (var p in carrito.productos) {
        if (p.idVariante != null) {
          // Obtener stock actual
          final varRes = await supabase
              .from('producto_variantes')
              .select('stock')
              .eq('id_variante', p.idVariante!)
              .single();
          
          final stockActual = (varRes['stock'] as num?)?.toInt() ?? 0;
          final nuevoStock = stockActual - p.cantidad;

          await supabase
              .from('producto_variantes')
              .update({'stock': nuevoStock > 0 ? nuevoStock : 0})
              .eq('id_variante', p.idVariante!);
        }
      }

      // Venta Completada Visual (Ticket) y Notificación
      WhatsAppBotService.sendMessage('💸 *NUEVA VENTA DE MOSTRADOR*\nFolio: $folio\nTotal: \$${total.toStringAsFixed(2)}\nMétodo de pago: ${_metodoPago.toUpperCase()}');

      if (mounted) {
        // Obtenemos Logo
        final logoData = await rootBundle.load('assets/logo_ticket.png');
        final logoBytes = logoData.buffer.asUint8List();

        final datosTicket = {
          'folio': folio,
          'total': total,
          'metodoPago': _metodoPago,
          'pagoRecibido': _metodoPago == 'efectivo' ? double.tryParse(_montoRecibidoController.text) : null,
          'cambio': _metodoPago == 'efectivo' ? (double.tryParse(_montoRecibidoController.text) ?? 0) - total : null,
          'logoBytes': logoBytes,
          'productos': carrito.productos.map((p) => {
            'cantidad': p.cantidad,
            'nombre': p.nombre,
            'precio': p.precio,
          }).toList(),
        };

        if (!mounted) return;

        mostrarModalTicketVenta(
          context: context,
          datosTicket: datosTicket,
          alCerrarTicket: () {
            // Limpiamos carrito
            while(carrito.productos.isNotEmpty){
              carrito.eliminarProducto(carrito.productos.first);
            }
            if (mounted) {
              Navigator.pop(context); // salir de checkout screen
              Navigator.pop(context); // salir de carrito
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al finalizar venta: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final carrito = Provider.of<CarritoProvider>(context);
    final total = carrito.total;

    double montoRecibido = double.tryParse(_montoRecibidoController.text) ?? 0;
    double cambio = montoRecibido - total;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Checkout de Caja', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // Resumen Total
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Text('Total a Cobrar', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(
                          '\$${total.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                        ),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Artículos Totales:', style: TextStyle(fontSize: 16)),
                            Text('${carrito.cantidadTotal}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Método de Pago
                const Text('Método de Pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _BotonPago('Efectivo', Icons.money, 'efectivo'),
                    _BotonPago('Tarjeta', Icons.credit_card, 'tarjeta'),
                    _BotonPago('Transfer.', Icons.account_balance, 'transferencia'),
                  ],
                ),
                const SizedBox(height: 24),

                // Lógica Extra si es Efectivo (Calcular Cambio)
                if (_metodoPago == 'efectivo') ...[
                  TextField(
                    controller: _montoRecibidoController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Monto Recibido (\$)',
                      prefixIcon: const Icon(Icons.payments_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (v) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cambio >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Cambio a devolver:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          cambio >= 0 ? '\$${cambio.toStringAsFixed(2)}' : 'Faltan \$${(cambio * -1).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cambio >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  )
                ],

                const SizedBox(height: 40),

                // Finalizar Venta
                SizedBox(
                  height: 60,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _procesando ? null : _finalizarVenta,
                    icon: _procesando 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline, size: 28),
                    label: Text(
                      _procesando ? 'Procesando Venta...' : 'Finalizar Venta',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _BotonPago(String titulo, IconData icono, String valor) {
    final seleccionado = _metodoPago == valor;
    return InkWell(
      onTap: () => setState(() {
        _metodoPago = valor;
        _montoRecibidoController.clear();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: seleccionado ? Colors.deepPurple.shade50 : Colors.white,
          border: Border.all(
            color: seleccionado ? Colors.deepPurple : Colors.grey.shade300,
            width: seleccionado ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: seleccionado ? Colors.deepPurple : Colors.grey.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                color: seleccionado ? Colors.deepPurple : Colors.grey.shade800,
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
