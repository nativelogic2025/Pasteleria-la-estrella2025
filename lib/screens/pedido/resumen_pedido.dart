import 'package:flutter/material.dart';
import './pago_pedido_screen.dart';

// ─── COLORES ──────────────────────────────────
const _cP    = Color(0xFF8C5535);
const _cS    = Color(0xFFD4956A);
const _cSurf = Color(0xFFFCF5EE);
const _cBord = Color(0xFFE5CEB3);

/// Llama a esta función para mostrar el resumen previo al pago
void mostrarModalResumen({
  required BuildContext context,
  required Map<String, dynamic> datos,
  required Map<String, dynamic> pedido,
  required Map<String, dynamic> pedido_detalle,
  required VoidCallback alTerminar,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: _ResumenDialog(
        datos: datos,
        pedido: pedido,
        pedido_detalle: pedido_detalle,
        alTerminar: alTerminar,
      ),
    ),
  );
}

// ─── DIALOG STATEFUL ─────────────────────────
class _ResumenDialog extends StatelessWidget {
  final Map<String, dynamic> datos;
  final Map<String, dynamic> pedido;
  final Map<String, dynamic> pedido_detalle;
  final VoidCallback alTerminar;

  const _ResumenDialog({
    required this.datos,
    required this.pedido,
    required this.pedido_detalle,
    required this.alTerminar,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 430,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── HEADER ─────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.receipt_long_outlined, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text('Confirmación de Pedido',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
            ),

            // ── CONTENIDO ──────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cliente
                    _seccion('Datos del Cliente', Icons.person_outline, [
                      _fila('Cliente', datos['cliente'] ?? '—'),
                      _fila('Teléfono', datos['telefono'] ?? '—'),
                    ]),

                    // Pedido
                    _seccion('Detalles del Pedido', Icons.shopping_bag_outlined, [
                      _fila('Producto', datos['nombre_producto'] ?? '—', isHighlight: true),
                      _fila('Cantidad', '${pedido_detalle['cantidad'] ?? '1'}', isHighlight: true),
                      _fila('Tamaño',   datos['tamaño'] ?? '—'),
                      if ((pedido_detalle['sabor'] ?? '').toString().isNotEmpty)
                        _fila('Sabor/Pan', pedido_detalle['sabor']),
                      if (datos['categoria'] == 'Pasteles') ...[
                        _fila('Armado',  datos['armado'] ?? '—'),
                        _fila('Pisos',   datos['piso'] ?? '—'),
                        _fila('Diseño',  datos['diseno'] ?? '—'),
                      ],
                      if ((pedido_detalle['dedicatoria'] ?? '').toString().isNotEmpty)
                        _fila('Dedicatoria', pedido_detalle['dedicatoria']),
                      if ((pedido_detalle['observaciones'] ?? '').toString().isNotEmpty)
                        _fila('Notas', pedido_detalle['observaciones']),
                    ]),

                    // Entrega
                    _seccion('Entrega', Icons.local_shipping_outlined, [
                      _fila('Fecha', pedido['fecha_entrega'] ?? '—'),
                      _fila('Hora',  pedido['hora_entrega']  ?? '—'),
                      _fila(
                        'Tipo',
                        datos['direccion'].toString().isNotEmpty
                            ? 'Domicilio: ${datos['direccion']}'
                            : 'Recoger en sucursal',
                      ),
                    ]),

                    // Pago
                    _seccion('Resumen de Pago', Icons.attach_money, [
                      _fila('Precio Unitario', '\$${(pedido_detalle['precio_unitario'] ?? 0).toStringAsFixed(2)}'),
                      _fila('Subtotal', '\$${(pedido['subtotal'] ?? 0).toStringAsFixed(2)}'),
                      if ((datos['flete'] as num? ?? 0) > 0)
                        _fila('Flete', '\$${(datos['flete']).toStringAsFixed(2)}'),
                      if ((pedido['descuento'] as num? ?? 0) > 0)
                        _fila('Otros cargos', '\$${(pedido['descuento']).toStringAsFixed(2)}'),
                      if ((pedido['anticipo'] as num? ?? 0) > 0)
                        _fila('Anticipo registrado',
                            '\$${(pedido['anticipo']).toStringAsFixed(2)}', color: Colors.green),
                    ]),

                    // Total destacado
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                        ]
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL A PAGAR',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                          Text(
                            '\$${(pedido['total'] ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── BOTONES ────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                border: Border(top: BorderSide(color: Color(0xFFF0E8DC))),
              ),
              child: Column(
                children: [
                  // Proceder al pago
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _cP,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PagoPedidoScreen(
                              datos: datos,
                              pedido: pedido,
                              pedidoDetalle: pedido_detalle,
                              alTerminar: alTerminar,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payment_outlined, size: 20),
                      label: const Text('Proceder al Pago',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Agregar otro pedido
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _cP,
                        side: const BorderSide(color: _cBord),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.add_shopping_cart_outlined, size: 20),
                      label: const Text('Agregar otro Pedido',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────
  Widget _seccion(String titulo, IconData icon, List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 20, color: Colors.black87),
            const SizedBox(width: 8),
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _fila(String etiqueta, String valor, {bool isHighlight = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiqueta,
                style: TextStyle(
                  color: isHighlight ? Colors.black87 : Colors.grey.shade600, 
                  fontSize: 14,
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal
                )),
            const SizedBox(width: 12),
            Flexible(
              child: Text(valor,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600, 
                      fontSize: 14,
                      color: color ?? (isHighlight ? Colors.black87 : Colors.black54))),
            ),
          ],
        ),
      );
}