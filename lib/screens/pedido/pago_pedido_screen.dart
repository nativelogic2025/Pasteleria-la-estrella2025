import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import './dialogo_ticket.dart';
import '../servicios/whatsapp_bot_service.dart';

final _sb = Supabase.instance.client;

/// Genera un token aleatorio de N caracteres alfanuméricos en mayúsculas.
/// Ejemplo con n=6: 'K7M2XQ'
String _generarToken(int n) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // sin 0,O,I,1 para evitar confusión
  final rnd = Random.secure();
  return List.generate(n, (_) => chars[rnd.nextInt(chars.length)]).join();
}

/// Folio para pedidos custom: EST-YYYY-XXXXXX
String _generarFolioPedido() {
  final year = DateTime.now().year;
  return 'EST-$year-${_generarToken(6)}';
}

/// Folio para ventas POS: POS-YYYYMMDD-XXXXXX
String _generarFolioPOS() {
  final now = DateTime.now();
  final fecha = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
  return 'POS-$fecha-${_generarToken(6)}';
}

// ─── PALETA (igual que el resto de la app) ────────────────────────────────────
const _cP     = Color(0xFF8C5535);   // café principal
const _cS     = Color(0xFFD4956A);   // café secundario
const _cBg    = Color(0xFFFAFAFA);   // fondo
const _cSurf  = Color(0xFFFCF5EE);   // superficie cards
const _cBord  = Color(0xFFE5CEB3);   // bordes
const _cGreen = Color(0xFF27AE60);
const _cOrange= Color(0xFFE67E22);
const _cRed   = Color(0xFFE74C3C);

// ─── MÉTODOS DE PAGO ──────────────────────────────────────────────────────────
enum MetodoPago { efectivo, tarjeta, deposito }

extension MetodoPagoExt on MetodoPago {
  String get label {
    switch (this) {
      case MetodoPago.efectivo: return 'Efectivo';
      case MetodoPago.tarjeta:  return 'Tarjeta';
      case MetodoPago.deposito: return 'Depósito / Transferencia';
    }
  }
  IconData get icon {
    switch (this) {
      case MetodoPago.efectivo: return Icons.payments_rounded;
      case MetodoPago.tarjeta:  return Icons.credit_card_rounded;
      case MetodoPago.deposito: return Icons.account_balance_rounded;
    }
  }
  String get dbValue {
    switch (this) {
      case MetodoPago.efectivo: return 'efectivo';
      case MetodoPago.tarjeta:  return 'tarjeta';
      case MetodoPago.deposito: return 'transferencia';
    }
  }
  Color get accentColor {
    switch (this) {
      case MetodoPago.efectivo: return const Color(0xFF27AE60);
      case MetodoPago.tarjeta:  return const Color(0xFF2980B9);
      case MetodoPago.deposito: return const Color(0xFF8E44AD);
    }
  }
}

// ─── MODO DE PAGO ─────────────────────────────────────────────────────────────
enum ModoPago { total, anticipo }

// ─── PANTALLA DE PAGO ─────────────────────────────────────────────────────────
class PagoPedidoScreen extends StatefulWidget {
  final Map<String, dynamic> datos;
  final Map<String, dynamic> pedido;
  final Map<String, dynamic> pedidoDetalle;
  final VoidCallback alTerminar;

  const PagoPedidoScreen({
    super.key,
    required this.datos,
    required this.pedido,
    required this.pedidoDetalle,
    required this.alTerminar,
  });

  @override
  State<PagoPedidoScreen> createState() => _PagoPedidoScreenState();
}

class _PagoPedidoScreenState extends State<PagoPedidoScreen>
    with SingleTickerProviderStateMixin {

  bool _guardando = false;
  ModoPago _modoPago = ModoPago.total;

  // Métodos de pago activos y sus montos
  final Set<MetodoPago> _metodosActivos = {MetodoPago.efectivo};
  final Map<MetodoPago, double> _montosPorMetodo = {
    MetodoPago.efectivo:  0.0,
    MetodoPago.tarjeta:   0.0,
    MetodoPago.deposito:  0.0,
  };
  final Map<MetodoPago, TextEditingController> _controllers = {
    MetodoPago.efectivo:  TextEditingController(),
    MetodoPago.tarjeta:   TextEditingController(),
    MetodoPago.deposito:  TextEditingController(),
  };

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // ── Getters ───────────────────────────────────────────────────────────────
  double get _total => (widget.pedido['total'] as num?)?.toDouble() ?? 0;
  bool   get _esDomicilio => widget.pedido['tipo_entrega'] == 'domicilio';

  // Anticipo: prioriza el campo guardado; si es 0 o nulo, calcula el 50% del total
  double get _anticipo {
    final guardado = (widget.pedido['anticipo'] as num?)?.toDouble() ?? 0;
    if (guardado > 0) return guardado;
    return (_total * 0.5); // 50% automático
  }

  double get _restante => (_total - _anticipo).clamp(0.0, double.infinity);

  // Monto objetivo según el modo seleccionado
  double get _montoObjetivo =>
      _modoPago == ModoPago.anticipo ? _anticipo : _total;

  // Suma de lo que el usuario asignó a los métodos activos
  double get _totalAsignado =>
      _metodosActivos.fold(0.0, (s, m) => s + (_montosPorMetodo[m] ?? 0));

  double get _diferencia => _montoObjetivo - _totalAsignado;
  bool   get _pagoCompleto => _diferencia.abs() < 0.01;

  // ── Init ──────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    // Para domicilio iniciamos en anticipo; para sucursal en total
    _modoPago = _esDomicilio ? ModoPago.anticipo : ModoPago.total;
    _preLlenarPrimerMetodo();
  }

  void _preLlenarPrimerMetodo() {
    final monto = _montoObjetivo;
    _controllers[MetodoPago.efectivo]!.text = monto.toStringAsFixed(2);
    _montosPorMetodo[MetodoPago.efectivo]   = monto;
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  // ── Actualizar monto de un método ─────────────────────────────────────────
  void _updateMonto(MetodoPago m, String val) {
    final d = double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
    setState(() => _montosPorMetodo[m] = d);
  }

  // ── Activar / desactivar método ──────────────────────────────────────────
  void _toggleMetodo(MetodoPago m) {
    setState(() {
      if (_metodosActivos.contains(m)) {
        if (_metodosActivos.length == 1) return; // mínimo 1
        _metodosActivos.remove(m);
        _montosPorMetodo[m] = 0;
        _controllers[m]!.clear();
      } else {
        _metodosActivos.add(m);
        // Sugerir el faltante
        final faltante = _diferencia.clamp(0.0, double.infinity);
        if (faltante > 0) {
          _controllers[m]!.text = faltante.toStringAsFixed(2);
          _montosPorMetodo[m] = faltante;
        }
      }
    });
  }

  // ── Cambiar modo ──────────────────────────────────────────────────────────
  void _setModoPago(ModoPago m) {
    setState(() {
      _modoPago = m;
      // Resetear montos
      for (final met in MetodoPago.values) {
        _montosPorMetodo[met] = 0;
        _controllers[met]!.clear();
      }
      _preLlenarPrimerMetodo();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONFIRMAR PAGO
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _confirmarPago() async {
    if (!_pagoCompleto) {
      final diff = _diferencia;
      final msg = diff > 0
          ? 'Faltan \$${diff.toStringAsFixed(2)} por asignar.'
          : 'El monto excede en \$${(-diff).toStringAsFixed(2)}. Ajusta los valores.';
      _snack(msg, _cOrange);
      return;
    }

    setState(() => _guardando = true);
    try {
      // 1. Buscar o crear cliente
      final clienteExistente = await _sb
          .from('clientes')
          .select()
          .eq('telefono', widget.datos['telefono'].toString())
          .maybeSingle();

      int idCliente;
      if (clienteExistente != null) {
        idCliente = clienteExistente['id_cliente'];
        final updates = <String, dynamic>{};
        if (clienteExistente['nombre'] != widget.datos['cliente']) {
          updates['nombre'] = widget.datos['cliente'];
        }
        if (clienteExistente['direccion'] != widget.datos['direccion']) {
          updates['direccion'] = widget.datos['direccion'];
        }
        if (updates.isNotEmpty) {
          await _sb.from('clientes').update(updates).eq('id_cliente', idCliente);
        }
      } else {
        final nuevo = await _sb.from('clientes').insert({
          'nombre':    widget.datos['cliente'],
          'telefono':  widget.datos['telefono'],
          'direccion': widget.datos['direccion'],
        }).select().single();
        idCliente = nuevo['id_cliente'];
      }

      // 2. Insertar pedido — folio aleatorio para privacidad
      final folioGenerado = _generarFolioPedido();
      final pedidoFinal = Map<String, dynamic>.from(widget.pedido)
        ..['id_cliente'] = idCliente
        ..['folio']      = folioGenerado;   // ← sobreescribe el folio secuencial de la BD
      final respPedido =
          await _sb.from('pedidos').insert(pedidoFinal).select().single();
      final idPedido = respPedido['id_pedido'];
      final folio    = respPedido['folio'].toString();

      WhatsAppBotService.sendMessage('🎂 *NUEVO PEDIDO ESPECIAL*\nFolio: $folio\nCliente: ${widget.datos['cliente']}\nTotal: \$${_total.toStringAsFixed(2)}\nAnticipo: \$${_totalAsignado.toStringAsFixed(2)}');

      // 3. Insertar detalle
      final detalle = Map<String, dynamic>.from(widget.pedidoDetalle)
        ..['id_pedido'] = idPedido;
      await _sb.from('detalle_pedido').insert(detalle);

      // 4. Insertar un pago por cada método activo con monto > 0
      final tipoPago = _modoPago == ModoPago.anticipo ? 'anticipo' : 'total';
      for (final m in _metodosActivos) {
        final monto = _montosPorMetodo[m] ?? 0;
        if (monto <= 0) continue;
        try {
          await _sb.from('pagos').insert({
            'id_pedido':   idPedido,
            'monto':       monto,
            'metodo_pago': m.dbValue,
            'tipo_pago':   tipoPago,
            'estado_pago': 'completado',
          });
        } catch (_) {
          await _sb.from('pagos').insert({
            'id_pedido': idPedido,
            'monto':     monto,
          });
        }
      }

      if (!mounted) return;

      // 5. Construir ticket
      final metodosUsados = _metodosActivos
          .where((m) => (_montosPorMetodo[m] ?? 0) > 0)
          .toList();
      final metodosLabel = metodosUsados
          .map((m) => '${m.label}: \$${(_montosPorMetodo[m] ?? 0).toStringAsFixed(2)}')
          .join(' + ');

      final logoData  = await rootBundle.load('assets/logo_ticket.png');
      final logoBytes = logoData.buffer.asUint8List();

      final montoRestanteTicket =
          _modoPago == ModoPago.anticipo ? _restante : 0.0;

      final datosTicket = {
        'folio':            folio,
        'nombre_producto':  widget.datos['nombre_producto'].toString(),
        'cantidad':         widget.pedidoDetalle['cantidad']?.toString() ?? '1',
        'total':            _total,
        'subtotal':         widget.pedido['subtotal'],
        'tamaño':           widget.datos['tamaño'].toString(),
        'categoria':        widget.datos['categoria'].toString(),
        'tipoPan':          widget.pedidoDetalle['sabor'].toString(),
        'tipoArmado':       widget.datos['armado'].toString(),
        'numeroPisos':      widget.datos['piso'].toString(),
        'diseño':           widget.datos['diseno'].toString(),
        'mensaje':          widget.pedidoDetalle['dedicatoria'].toString(),
        'notasAdicionales': widget.pedidoDetalle['observaciones'].toString(),
        'cliente':          widget.datos['cliente'].toString(),
        'telefono':         widget.datos['telefono'].toString(),
        'fechaEntrega':     widget.pedido['fecha_entrega'].toString(),
        'horaEntrega':      widget.pedido['hora_entrega'].toString(),
        'direccionEntrega': widget.datos['direccion'].toString(),
        'otrosCargos':      widget.pedido['descuento'],
        'flete':            widget.datos['flete'],
        'anticipo':         _anticipo,
        'restoPorPagar':    montoRestanteTicket,
        'logoBytes':        logoBytes,
        'metodoPago':       metodosLabel,
        'montoPagado':      _totalAsignado,
        'montoRestante':    montoRestanteTicket,
        'pagoCompleto':     _modoPago == ModoPago.total,
      };

      if (!mounted) return;

      mostrarModalTicketConDatos(
        context: context,
        datosTicket: datosTicket,
        alCerrarTicket: () {
          if (mounted) {
            Navigator.pop(context);
          }
          widget.alTerminar();
        },
      );
    } catch (e) {
      debugPrint('Error al confirmar pago: $e');
      if (mounted) setState(() => _guardando = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error en Base de Datos'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              )
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      appBar: AppBar(
        backgroundColor: _cBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: Column(
          children: [
            const Text('Cobro del Pedido',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('Total: \$${_total.toStringAsFixed(2)} MXN',
                style: const TextStyle(color: _cP, fontSize: 12)),
          ],
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFEEEEEE)),
        ),
      ),
      body: _guardando ? _buildLoading() : _buildBody(),
    );
  }

  Widget _buildLoading() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: _cP),
        SizedBox(height: 16),
        Text('Procesando pedido...', style: TextStyle(color: _cP)),
      ],
    ),
  );

  Widget _buildBody() => FadeTransition(
    opacity: _fadeAnim,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Resumen del pedido
          _buildResumenCard(),
          const SizedBox(height: 14),

          // 2. ¿Pago total o solo anticipo?
          _buildModoPagoCard(),
          const SizedBox(height: 14),

          // 3. Aviso especial para domicilio
          if (_esDomicilio) ...[
            _buildAvisoDomicilio(),
            const SizedBox(height: 14),
          ],

          // 4. Métodos de pago
          _seccionTitulo('Forma de Cobro', Icons.wallet_rounded),
          const SizedBox(height: 8),
          ...MetodoPago.values.map(_buildMetodoCard),
          const SizedBox(height: 14),

          // 5. Panel monto total
          _buildPanelMonto(),
          const SizedBox(height: 22),

          // 6. Botón confirmar
          _buildBotonConfirmar(),
          const SizedBox(height: 32),
        ],
      ),
    ),
  );

  // ── 1. RESUMEN ────────────────────────────────────────────────────────────
  Widget _buildResumenCard() {
    final subtotal  = (widget.pedido['subtotal']  as num?)?.toDouble() ?? 0;
    final flete     = (widget.datos['flete']      as num?)?.toDouble() ?? 0;
    final descuento = (widget.pedido['descuento'] as num?)?.toDouble() ?? 0;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _seccionTitulo('Resumen del Pedido', Icons.receipt_long_rounded),
          const SizedBox(height: 12),
          _fila('Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
          if (flete > 0) _fila('Flete / Envío 🚚', '\$${flete.toStringAsFixed(2)}'),
          if (descuento > 0) _fila('Otros cargos', '\$${descuento.toStringAsFixed(2)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: _cBord, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('\$${_total.toStringAsFixed(2)} MXN',
                  style: const TextStyle(
                      color: _cP, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          // Desglose anticipo / restante
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _cSurf,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cBord),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.timelapse_rounded, color: _cS, size: 16),
                      const SizedBox(width: 6),
                      const Text('Anticipo (50%)',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ]),
                    Text('\$${_anticipo.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: _cP, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Icon(Icons.schedule_rounded, color: Colors.grey, size: 16),
                      const SizedBox(width: 6),
                      const Text('Resto al entregar',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ]),
                    Text('\$${_restante.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. MODO DE PAGO ───────────────────────────────────────────────────────
  Widget _buildModoPagoCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _seccionTitulo('¿Cuánto cobra hoy?', Icons.tune_rounded),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _modoBtn(
                label: 'Pago Total',
                sub: '\$${_total.toStringAsFixed(2)} MXN',
                icon: Icons.check_circle_rounded,
                seleccionado: _modoPago == ModoPago.total,
                onTap: () => _setModoPago(ModoPago.total),
              )),
              const SizedBox(width: 10),
              Expanded(child: _modoBtn(
                label: 'Solo Anticipo',
                sub: '\$${_anticipo.toStringAsFixed(2)} (50%)',
                icon: Icons.timelapse_rounded,
                seleccionado: _modoPago == ModoPago.anticipo,
                onTap: () => _setModoPago(ModoPago.anticipo),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modoBtn({
    required String label,
    required String sub,
    required IconData icon,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: seleccionado ? _cSurf : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: seleccionado ? _cP : _cBord,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: seleccionado ? _cP : Colors.grey, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      color: seleccionado ? _cP : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    )),
              ),
            ]),
            const SizedBox(height: 4),
            Text(sub,
                style: TextStyle(
                    color: seleccionado ? _cS : Colors.grey,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ── 3. AVISO DOMICILIO ────────────────────────────────────────────────────
  Widget _buildAvisoDomicilio() {
    final esAnticipo = _modoPago == ModoPago.anticipo;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: esAnticipo
            ? const Color(0xFFFFF8E1)
            : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esAnticipo ? _cOrange : _cGreen,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            esAnticipo ? Icons.info_outline_rounded : Icons.local_shipping_rounded,
            color: esAnticipo ? _cOrange : _cGreen,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esAnticipo
                      ? 'Anticipo — se cobra el resto al entregar'
                      : 'Pedido liquidado — listo para envío',
                  style: TextStyle(
                    color: esAnticipo ? _cOrange : _cGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  esAnticipo
                      ? 'Hoy: \$${_anticipo.toStringAsFixed(2)}  •  Al entregar: \$${_restante.toStringAsFixed(2)}'
                      : 'El cliente paga el total completo hoy.',
                  style: TextStyle(
                    color: esAnticipo
                        ? _cOrange.withValues(alpha: 0.85)
                        : _cGreen.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Toggle rápido
          GestureDetector(
            onTap: () => _setModoPago(
                esAnticipo ? ModoPago.total : ModoPago.anticipo),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: esAnticipo ? _cOrange : _cGreen),
              ),
              child: Text(
                esAnticipo ? 'Liquidar' : 'Anticipo',
                style: TextStyle(
                  color: esAnticipo ? _cOrange : _cGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. TARJETA DE MÉTODO DE PAGO ─────────────────────────────────────────
  Widget _buildMetodoCard(MetodoPago m) {
    final activo = _metodosActivos.contains(m);
    final monto  = _montosPorMetodo[m] ?? 0.0;
    final col    = m.accentColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: activo ? col.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activo ? col.withValues(alpha: 0.5) : _cBord,
          width: activo ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Encabezado tappable
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _toggleMetodo(m),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Indicador selección
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activo ? col : Colors.transparent,
                      border: Border.all(
                          color: activo ? col : Colors.grey.shade400, width: 2),
                    ),
                    child: activo
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 13)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Icon(m.icon, color: activo ? col : Colors.grey, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(m.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: activo ? Colors.black87 : Colors.grey.shade500,
                        )),
                  ),
                  // Badge monto asignado
                  if (activo && monto > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('\$${monto.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: col,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                ],
              ),
            ),
          ),

          // Campo de monto (si activo)
          if (activo) ...[
            Divider(height: 1, color: col.withValues(alpha: 0.2)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.attach_money_rounded,
                      color: col.withValues(alpha: 0.7), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controllers[m],
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        prefix: Text('MXN  ',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13)),
                      ),
                      onChanged: (v) => _updateMonto(m, v),
                    ),
                  ),
                  // Botón "Agregar faltante"
                  if (_diferencia > 0.01)
                    GestureDetector(
                      onTap: () {
                        final r = _diferencia;
                        _controllers[m]!.text = r.toStringAsFixed(2);
                        _updateMonto(m, r.toStringAsFixed(2));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: col.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: col.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '+ \$${_diferencia.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: col,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Datos bancarios para depósito
            if (m == MetodoPago.deposito) _buildInfoDeposito(),
          ],
        ],
      ),
    );
  }

  // ── Datos bancarios ───────────────────────────────────────────────────────
  Widget _buildInfoDeposito() {
    const col = Color(0xFF8E44AD);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border(
            left: BorderSide(color: col.withValues(alpha: 0.6), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BBVA — Datos de transferencia',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
          const SizedBox(height: 6),
          _infoFila('Titular', 'Pastelería La Estrella S.A de C.V'),
          _infoFila('Cuenta', '0123456789'),
          _infoFila('CLABE', '012 345 6789 0123 4567'),
          const SizedBox(height: 4),
          const Text('Presenta comprobante al recoger o al entregar.',
              style: TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _infoFila(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Text('$k: ', style: const TextStyle(color: Colors.grey, fontSize: 12)),
      Expanded(
          child: Text(v,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );

  // ── 5. PANEL MONTO ────────────────────────────────────────────────────────
  Widget _buildPanelMonto() {
    final ok     = _pagoCompleto;
    final excede = _diferencia < -0.01;

    Color statusColor;
    String statusMsg;
    IconData statusIcon;

    if (ok) {
      statusColor = _cGreen;
      statusMsg   = 'Monto completo';
      statusIcon  = Icons.check_circle_rounded;
    } else if (excede) {
      statusColor = _cRed;
      statusMsg   = 'Excede \$${(-_diferencia).toStringAsFixed(2)}';
      statusIcon  = Icons.error_rounded;
    } else {
      statusColor = _cOrange;
      statusMsg   = 'Faltan \$${_diferencia.toStringAsFixed(2)}';
      statusIcon  = Icons.timelapse_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_cP, const Color(0xFFA0623C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _cP.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        children: [
          Text(
            _modoPago == ModoPago.anticipo
                ? 'Anticipo a cobrar hoy'
                : 'Total a cobrar',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${_montoObjetivo.toStringAsFixed(2)} MXN',
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          if (_modoPago == ModoPago.anticipo) ...[
            const SizedBox(height: 4),
            Text(
              'Pendiente al entregar: \$${_restante.toStringAsFixed(2)} MXN',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),

          // Desglose si hay más de un método activo
          if (_metodosActivos.length > 1) ...[
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 12),
            ..._metodosActivos.map((m) {
              final monto = _montosPorMetodo[m] ?? 0;
              if (monto <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(m.icon, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(m.label,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                  const Spacer(),
                  Text('\$${monto.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ]),
              );
            }),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 8),
          ],

          // Badge de estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                  color: statusColor == _cGreen
                      ? Colors.white30
                      : statusColor.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(statusMsg,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. BOTÓN CONFIRMAR ────────────────────────────────────────────────────
  Widget _buildBotonConfirmar() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _pagoCompleto ? _cP : Colors.grey.shade300,
          foregroundColor: _pagoCompleto ? Colors.white : Colors.grey.shade500,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: _pagoCompleto ? 2 : 0,
        ),
        onPressed: _pagoCompleto ? _confirmarPago : null,
        icon: const Icon(Icons.check_circle_rounded, size: 22),
        label: const Text('Confirmar y Generar Ticket',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _cBord),
    ),
    child: child,
  );

  Widget _seccionTitulo(String text, IconData icon) => Row(children: [
    Icon(icon, color: _cP, size: 18),
    const SizedBox(width: 8),
    Text(text,
        style: const TextStyle(
            color: _cP, fontWeight: FontWeight.bold, fontSize: 14)),
  ]);

  Widget _fila(String label, String valor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(valor,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    ),
  );
}
