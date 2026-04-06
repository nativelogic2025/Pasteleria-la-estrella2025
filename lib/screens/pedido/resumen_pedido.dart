import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import './dialogo_ticket.dart';

final supabase = Supabase.instance.client;

/// Llama a esta función desde cualquier parte de tu app para mostrar el resumen
void mostrarModalResumen({
  required BuildContext context,
  required Map<String, dynamic> datos,
  required Map<String, dynamic> pedido,
  required Map<String, dynamic> pedido_detalle,
  required VoidCallback alTerminar,
}) {
  showDialog(
    context: context,
    barrierDismissible: false, // 1. 👇 ESTO EVITA QUE SE CIERRE AL TOCAR FUERA DEL MODAL
    builder: (context) {
      return PopScope(
        canPop: false, // Bloquea la acción nativa de retroceder
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 400,
            height: 600,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Resumen del Pedido',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: 
                      Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50, // Fondo suave
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: SingleChildScrollView(
                        // Opcional: Le da un efecto de "rebote" nativo muy estético en móviles
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.receipt_long_outlined, color: Colors.black87),
                                const SizedBox(width: 8),
                                Text(
                                  'Detalles del Cliente',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            // Llamamos a un método auxiliar para no repetir código
                            _buildFilaDatos('Cliente', datos['cliente'] ?? 'Sin nombre'),
                            _buildFilaDatos('Teléfono', datos['telefono'] ?? 'Sin teléfono'),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                const Icon(Icons.shopping_cart_checkout, color: Colors.black87),
                                const SizedBox(width: 8),
                                Text(
                                  'Detalles del Pedido',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            _buildFilaDatos('Producto', datos['nombre_producto'] ?? 'Sin nombre del producto'),
                            _buildFilaDatos('Tamaño', datos['tamaño'] ?? 'Sin tamaño'),
                            if (pedido_detalle['sabor'].isNotEmpty)
                              _buildFilaDatos('Tipo de Pan', pedido_detalle['sabor'] ?? 'No aplica'),
                            if (datos['categoria'] == 'Pasteles') ...[
                              _buildFilaDatos('Tipo de Armado', datos['armado'] ?? 'Sin armado'),
                              _buildFilaDatos('Numero de Piso', datos['piso'] ?? 'Sin piso'),
                              _buildFilaDatos('Diseño', datos['diseno'] ?? 'Sin diseño'),
                            ],
                            _buildFilaDatos('Mensaje', pedido_detalle['dedicatoria'] ?? 'Sin mensaje'),
                            _buildFilaDatos('Notas', pedido_detalle['observaciones'] ?? 'Sin notas'),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                const Icon(Icons.home, color: Colors.black87),
                                const SizedBox(width: 8),
                                Text(
                                  'Detalles de la Entrega',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            _buildFilaDatos('Fecha de Entrega', pedido['fecha_entrega'] ?? 'Sin fecha'),
                            _buildFilaDatos('Hora de Entrega', pedido['hora_entrega'] ?? 'Sin hora'),
                            if(datos['direccion'].toString().isNotEmpty)
                              _buildFilaDatos('Dirección', datos['direccion'] ?? 'Sin dirección'),
                            if(datos['direccion'].toString().isEmpty)
                              _buildFilaDatos('', 'Entrega en sucursal'),
                            const SizedBox(height: 8),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1), // Línea separadora
                            ),

                            Row(
                              children: [
                                const Icon(Icons.payment, color: Colors.black87),
                                const SizedBox(width: 8),
                                Text(
                                  'Detalles de Pago',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),                        

                            _buildFilaDatos('Subtotal', pedido['subtotal'].toString()),
                            _buildFilaDatos('Otros Cargos', pedido['descuento'].toString()),
                            _buildFilaDatos('Flete', datos['flete'].toString()),
                            _buildFilaDatos('Anticipo', pedido['anticipo'].toString()),
                            _buildFilaDatos('Total', pedido['total'].toString()),

                            // Fila especial para el total (más grande y negrita)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Restante a Pagar',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '\$${(pedido['restante'] ?? 0.0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 20, 
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black, // O el color principal de La Estrella
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [ 
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async
                      {
                        try {
                          // 1. Buscamos al cliente (usando maybeSingle para que devuelva null pacíficamente si no existe)
                          final clienteExistente = await supabase
                              .from('clientes')
                              .select()
                              .eq('telefono', datos['telefono'].toString())
                              .maybeSingle(); // 👈 El cambio clave que evita el crash

                          int idClienteFinal; // Variable para almacenar el ID en memoria

                          if (clienteExistente != null) {
                            // ✅ EL CLIENTE EXISTE
                            idClienteFinal = clienteExistente['id_cliente']; // Guardamos su ID de inmediato

                            // Preparamos los cambios en un solo mapa para hacer una sola llamada a la BD
                            Map<String, dynamic> actualizaciones = {};
                            
                            if (clienteExistente['nombre'] != datos['cliente'].toString()) {
                              actualizaciones['nombre'] = datos['cliente'].toString();
                            }
                            if (clienteExistente['direccion'] != datos['direccion'].toString()) {
                              actualizaciones['direccion'] = datos['direccion'].toString();
                            }

                            // Si hubo algún cambio, hacemos un solo UPDATE
                            if (actualizaciones.isNotEmpty) {
                              await supabase
                                  .from('clientes')
                                  .update(actualizaciones)
                                  .eq('id_cliente', idClienteFinal);
                            }

                          } else {
                            // ❌ EL CLIENTE NO EXISTE
                            // Lo insertamos y le decimos a Supabase que nos devuelva la fila recién creada
                            // (Aquí SÍ es seguro usar .single() porque acabamos de garantizar que se insertó una fila)
                            final nuevoCliente = await supabase.from('clientes').insert({
                              'nombre': datos['cliente'].toString(),
                              'telefono': datos['telefono'].toString(),
                              'direccion': datos['direccion'].toString(),
                            }).select().single();

                            idClienteFinal = nuevoCliente['id_cliente'];
                          }

                          // 2. Asignamos el ID al pedido de forma segura
                          pedido['id_cliente'] = idClienteFinal;

                          // 3. Guardamos el pedido y obtenemos el folio
                          final respuesta = await supabase.from('pedidos').insert(
                            pedido
                          ).select().single();

                          // 2. Extraemos el folio generado
                          final folio = respuesta['folio'];
                          
                          try {
                            // 3. Guardamos el detalle del pedido
                            await supabase.from('detalle_pedido').insert(
                              pedido_detalle
                            );

                            if (context.mounted) {
                              /*ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ Pedido guardado. Folio: $folio'),
                                  backgroundColor: Colors.green,
                                ),
                              );*/
                              // 1. Cerramos el modal actual (el de Resumen)
                              Navigator.pop(context);

                              // 1. Cargar los assets pesados en el hilo principal
                              final logoData = await rootBundle.load('assets/logo_ticket.png');
                              final logoBytes = logoData.buffer.asUint8List();

                              final datosticket = {
                                'folio': folio,
                                'nombre_producto': datos['nombre_producto'].toString(),
                                'total': pedido['total'],
                                'subtotal': pedido['subtotal'],
                                'tamaño': datos['tamaño'].toString(),
                                'categoria': datos['categoria'].toString(),
                                'tipoPan': pedido_detalle['sabor'].toString(),
                                'tipoArmado': datos['armado'].toString(),
                                'numeroPisos': datos['piso'].toString(),
                                'diseño': datos['diseno'].toString(),
                                'mensaje': pedido_detalle['dedicatoria'].toString(),
                                'notasAdicionales': pedido_detalle['observaciones'].toString(),
                                'cliente': datos['cliente'].toString(),
                                'telefono': datos['telefono'].toString(),
                                'fechaEntrega': pedido['fecha_entrega'].toString(),
                                'horaEntrega': pedido['hora_entrega'].toString(),
                                'direccionEntrega': datos['direccion'].toString(),
                                'otrosCargos': pedido['descuento'],
                                'flete': datos['flete'],
                                'anticipo': pedido['anticipo'],
                                'restoPorPagar': pedido['restante'],
                                'logoBytes': logoBytes,
                              };

                              if (!context.mounted) return;

                              // 4. Mostrar el resultado
                              mostrarModalTicketConDatos(
                                context: context,
                                datosTicket: datosticket,
                                alCerrarTicket: alTerminar,
                              );
                                                      
                            }
                          } catch (e) {
                            // Si falla guardar el detalle, podríamos considerar eliminar el pedido para no dejar datos huérfanos, o manejarlo de otra forma según la lógica de negocio
                            await supabase.from('pedidos').delete().eq('id_pedido', respuesta['id_pedido']);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                          
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      child: const Text('Confirmar Pedido'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildFilaDatos(String etiqueta, String valor) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        etiqueta,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      ),
      Text(
        valor,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ],
  );
}