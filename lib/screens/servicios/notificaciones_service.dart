import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class Notificacion {
  final String id;
  final String titulo;
  final String descripcion;
  final String tipo; // 'pedido_hoy', 'pedido_manana', 'inventario', 'cobranza'
  final DateTime fecha;
  final bool esCritica;

  Notificacion({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.tipo,
    required this.fecha,
    this.esCritica = false,
  });
}

class NotificacionesService {
  final _supabase = Supabase.instance.client;

  Future<List<Notificacion>> obtenerNotificaciones(String rol) async {
    List<Notificacion> notificaciones = [];
    final hoy = DateTime.now();
    final hoyStr = DateFormat('yyyy-MM-dd').format(hoy);
    
    final manana = hoy.add(const Duration(days: 1));
    final mananaStr = DateFormat('yyyy-MM-dd').format(manana);

    try {
      // 1. OBTENER PEDIDOS PARA HOY Y MAÑANA (Aplica para ambos roles)
      final pedidos = await _supabase
          .from('pedidos')
          .select('id_pedido, folio, fecha_entrega, restante, estado, clientes(nombre)')
          .inFilter('estado', ['pendiente', 'hecho'])
          .gte('fecha_entrega', hoyStr)
          .lte('fecha_entrega', mananaStr);

      for (var p in pedidos) {
        final fechaEntrega = p['fecha_entrega']?.toString() ?? '';
        final folio = p['folio']?.toString() ?? 'S/F';
        final cliente = p['clientes'] != null ? p['clientes']['nombre'] : 'Cliente';
        final restante = double.tryParse(p['restante']?.toString() ?? '0') ?? 0;

        if (fechaEntrega.startsWith(hoyStr)) {
          // Es para hoy
          notificaciones.add(Notificacion(
            id: 'ped_${p['id_pedido']}',
            titulo: 'Entrega para HOY: $folio',
            descripcion: 'Pedido de $cliente. ¡Prepáralo!',
            tipo: 'pedido_hoy',
            fecha: hoy,
            esCritica: true,
          ));

          // Si el administrador necesita saber si falta cobrar
          if (rol == 'administrador' && restante > 0) {
            notificaciones.add(Notificacion(
              id: 'cobro_${p['id_pedido']}',
              titulo: 'Saldo por cobrar hoy: \$$restante',
              descripcion: 'Folio: $folio ($cliente).',
              tipo: 'cobranza',
              fecha: hoy,
              esCritica: false,
            ));
          }
        } else if (fechaEntrega.startsWith(mananaStr)) {
          // Es para mañana
          notificaciones.add(Notificacion(
            id: 'ped_${p['id_pedido']}',
            titulo: 'Entrega para MAÑANA: $folio',
            descripcion: 'Pedido de $cliente. Ve adelantando la producción.',
            tipo: 'pedido_manana',
            fecha: manana,
            esCritica: false,
          ));
        }
      }

      // 2. OBTENER ALERTAS DE INVENTARIO
      // Hacemos una consulta a los ingredientes que tengan stock bajo (menor o igual a 5 por defecto si no hay mínimo)
      final insumosBajos = await _supabase
          .from('ingredientes')
          .select('id_ingrediente, nombre, stock_actual, unidad_medida')
          .lte('stock_actual', 5);

      for (var insumo in insumosBajos) {
        final nombre = insumo['nombre']?.toString() ?? 'Insumo';
        final stock = insumo['stock_actual']?.toString() ?? '0';
        final unidad = insumo['unidad_medida']?.toString() ?? '';
        
        notificaciones.add(Notificacion(
          id: 'inv_${insumo['id_ingrediente']}',
          titulo: 'Stock bajo: $nombre',
          descripcion: rol == 'administrador' 
              ? 'Quedan solo $stock $unidad. Se recomienda comprar pronto.'
              : 'Quedan solo $stock $unidad. Avísale al administrador.',
          tipo: 'inventario',
          fecha: hoy,
          esCritica: (double.tryParse(stock) ?? 0) <= 2,
        ));
      }

    } catch (e) {
      print('Error al cargar notificaciones: $e');
    }

    // Ordenar notificaciones: Primero las críticas, luego por fecha
    notificaciones.sort((a, b) {
      if (a.esCritica && !b.esCritica) return -1;
      if (!a.esCritica && b.esCritica) return 1;
      return a.fecha.compareTo(b.fecha);
    });

    return notificaciones;
  }
}
