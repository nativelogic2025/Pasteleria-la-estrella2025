// pedido_detalle_screen.dart
// Pantalla de detalle de pedido — diseño premium café/marrón
// Carga todos los datos desde Supabase en tiempo real
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../servicios/supabase_client.dart';
import '../../utils/timezone_utils.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─── PALETA ───────────────────────────────────────────────────────────────────
const _cP     = Color(0xFF8C5535);
const _cBg    = Color(0xFFFAFAFA);
const _cSurf  = Color(0xFFFCF5EE);
const _cBord  = Color(0xFFE5CEB3);
const _cGreen = Color(0xFF27AE60);
const _cOrange= Color(0xFFE67E22);
const _cBlue  = Color(0xFF2980B9);

// ─── PANTALLA ─────────────────────────────────────────────────────────────────
class PedidoDetalleScreen extends StatefulWidget {
  final String folio;
  final VoidCallback? onStatusChanged;
  const PedidoDetalleScreen({super.key, required this.folio, this.onStatusChanged});

  @override
  State<PedidoDetalleScreen> createState() => _PedidoDetalleScreenState();
}

class _PedidoDetalleScreenState extends State<PedidoDetalleScreen>
    with SingleTickerProviderStateMixin {

  Map<String, dynamic>? _pedido;
  Map<String, dynamic>? _cliente;
  Map<String, dynamic>? _detalle;
  List<Map<String, dynamic>> _pagos = [];
  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  String _estadoActual = 'pendiente';

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _cargar();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Carga ─────────────────────────────────────────────────────────────────
  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final p = await supabase
          .from('pedidos')
          .select('*, clientes(*)')
          .eq('folio', widget.folio)
          .maybeSingle();

      if (p == null) {
        if (mounted) setState(() {
          _error = 'No se encontró el folio ${widget.folio}';
          _cargando = false;
        });
        return;
      }

      final detRes = await supabase
          .from('detalle_pedido')
          .select('*, producto_variantes(*, productos(*))')
          .eq('id_pedido', p['id_pedido'])
          .maybeSingle();

      final pagosRes = await supabase
          .from('pagos')
          .select()
          .eq('id_pedido', p['id_pedido']);

      if (!mounted) return;
      setState(() {
        _pedido       = p;
        _cliente      = p['clientes'] as Map<String, dynamic>?;
        _detalle      = detRes;
        _pagos        = List<Map<String, dynamic>>.from(pagosRes ?? []);
        _estadoActual = p['estado']?.toString() ?? 'pendiente';
        _cargando     = false;
      });
      _animCtrl.forward(from: 0);
    } catch (e) {
      if (mounted) setState(() { _error = 'Error: $e'; _cargando = false; });
    }
  }

  // ── Cambiar estado ────────────────────────────────────────────────────────
  Future<void> _cambiarEstado(String nuevoEstado) async {
    setState(() => _guardando = true);
    try {
      await supabase
          .from('pedidos')
          .update({'estado': nuevoEstado})
          .eq('folio', widget.folio);
      setState(() {
        _estadoActual = nuevoEstado;
        if (_pedido != null) _pedido!['estado'] = nuevoEstado;
      });
      if (widget.onStatusChanged != null) widget.onStatusChanged!();
      _snack('Estado actualizado: ${_estadoLabel(nuevoEstado)}', _cGreen);
    } catch (e) {
      _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _estadoLabel(String e) {
    switch (e) {
      case 'entregado': return 'Entregado';
      case 'hecho':     return 'En preparación';
      default:          return 'Pendiente';
    }
  }

  (Color bg, Color fg, IconData icon) _estadoVisual(String e) {
    switch (e) {
      case 'entregado': return (const Color(0xFFE8F5E9), _cGreen,  Icons.check_circle_rounded);
      case 'hecho':     return (const Color(0xFFFFF8E1), _cOrange, Icons.blender_rounded);
      default:          return (const Color(0xFFE3F2FD), _cBlue,   Icons.schedule_rounded);
    }
  }

  String _formatFecha(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      // parseSupabaseTs fuerza UTC si no tiene Z, luego convierte a hora México
      final d = parseSupabaseTs(iso);
      const m = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
      return '${d.day.toString().padLeft(2,'0')} ${m[d.month-1]} ${d.year}';
    } catch (_) { return iso; }
  }

  String _metodoPago(String? v) {
    switch (v) {
      case 'efectivo':      return 'Efectivo';
      case 'tarjeta':       return 'Tarjeta';
      case 'transferencia': return 'Transferencia';
      default:              return v ?? '—';
    }
  }

  // ── Parsear observaciones (JSON o texto plano) ────────────────────────────
  Map<String, dynamic> _parseObs(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    if (!raw.trimLeft().startsWith('{')) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [_buildAppBar(ctx)],
        body: _cargando
            ? const Center(child: CircularProgressIndicator(color: _cP))
            : _error != null
                ? _buildError()
                : FadeTransition(opacity: _fadeAnim, child: _buildBody()),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext ctx) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: _cP,
      foregroundColor: Colors.white,
      actions: [
        if (_guardando)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
          ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _cargar,
          tooltip: 'Recargar',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5C3316), Color(0xFF8C5535), Color(0xFFA0623C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.folio,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        )),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.folio));
                        _snack('Folio copiado', _cP);
                      },
                      child: Icon(Icons.copy_rounded,
                          color: Colors.white.withValues(alpha: 0.7), size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_pedido != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_estadoVisual(_estadoActual).$3,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(_estadoLabel(_estadoActual),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: FilledButton.styleFrom(backgroundColor: _cP),
            ),
          ],
        ),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    final p          = _pedido!;
    final total      = (p['total'] as num?)?.toDouble() ?? 0;
    final subtotal   = (p['subtotal'] as num?)?.toDouble() ?? 0;
    final descuento  = (p['descuento'] as num?)?.toDouble() ?? 0;
    final pagoTotal  = _pagos.fold<double>(
        0, (s, e) => s + ((e['monto'] as num?)?.toDouble() ?? 0));
    final restante   = (total - pagoTotal).clamp(0.0, double.infinity);
    final completo   = restante < 0.01;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Estado
          _buildEstadoCard(),
          const SizedBox(height: 12),

          // 2. Resumen financiero
          _buildResumenFinanciero(total, subtotal, descuento, pagoTotal, restante, completo),
          const SizedBox(height: 12),

          // 3. Cliente
          _buildSeccion(
            icon: Icons.person_rounded,
            titulo: 'Cliente',
            hijos: [
              _infoRow(Icons.badge_rounded, 'Nombre',
                  _cliente?['nombre']?.toString() ?? '—'),
              _infoRow(Icons.phone_rounded, 'Teléfono',
                  _cliente?['telefono']?.toString() ?? '—'),
              if ((_cliente?['direccion']?.toString() ?? '').isNotEmpty)
                _infoRow(Icons.location_on_rounded, 'Dirección',
                    _cliente!['direccion'].toString()),
            ],
          ),
          const SizedBox(height: 12),

          // 4. Entrega
          _buildSeccion(
            icon: Icons.local_shipping_rounded,
            titulo: 'Entrega',
            hijos: [
              _infoRow(Icons.calendar_today_rounded, 'Fecha',
                  _formatFecha(p['fecha_entrega']?.toString())),
              _infoRow(Icons.access_time_rounded, 'Hora',
                  p['hora_entrega']?.toString() ?? '—'),
              _infoRow(Icons.store_rounded, 'Modalidad',
                  p['tipo_entrega'] == 'domicilio'
                      ? 'Envío a domicilio'
                      : 'Recoger en sucursal'),
            ],
          ),
          const SizedBox(height: 12),

          // 5. Producto
          if (_detalle != null) _buildProductoCard(),
          if (_detalle != null) const SizedBox(height: 12),

          // 6. Pagos
          if (_pagos.isNotEmpty) _buildPagosCard(),
          if (_pagos.isNotEmpty) const SizedBox(height: 12),

          // 7. Cambiar estado
          _buildCambiarEstado(),
          const SizedBox(height: 24),
        ].animate(interval: 50.ms).fade(duration: 400.ms).slideY(begin: 0.05),
      ),
    );
  }

  // ── 1. Estado card ────────────────────────────────────────────────────────
  Widget _buildEstadoCard() {
    final (bg, fg, icon) = _estadoVisual(_estadoActual);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: fg, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_estadoLabel(_estadoActual),
                    style: TextStyle(color: fg, fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  _estadoActual == 'entregado'
                      ? 'Pedido completado y entregado'
                      : _estadoActual == 'hecho'
                          ? 'Listo — en espera de entrega'
                          : 'En cola de producción',
                  style: TextStyle(
                      color: fg.withValues(alpha: 0.8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Resumen financiero ─────────────────────────────────────────────────
  Widget _buildResumenFinanciero(double total, double subtotal, double descuento,
      double pagado, double restante, bool completo) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8C5535), Color(0xFFA0623C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C5535).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.receipt_long_rounded, color: Colors.white70, size: 16),
              SizedBox(width: 8),
              Text('Resumen Financiero',
                  style: TextStyle(color: Colors.white70, fontSize: 12,
                      fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Total',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
                const Spacer(),
                Text('\$${total.toStringAsFixed(2)} MXN',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 10),
            if (subtotal > 0 && subtotal != total)
              _resumenFila('Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
            if (descuento > 0)
              _resumenFila('Otros cargos', '\$${descuento.toStringAsFixed(2)}'),
            _resumenFila('Pagado', '\$${pagado.toStringAsFixed(2)}',
                color: const Color(0xFF90EE90)),
            if (!completo)
              _resumenFila('Pendiente', '\$${restante.toStringAsFixed(2)}',
                  color: const Color(0xFFFFD700)),
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: completo
                          ? const Color(0xFF90EE90).withValues(alpha: 0.6)
                          : const Color(0xFFFFD700).withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      completo
                          ? Icons.check_circle_rounded
                          : Icons.timelapse_rounded,
                      color: completo
                          ? const Color(0xFF90EE90)
                          : const Color(0xFFFFD700),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      completo ? 'LIQUIDADO' : 'ANTICIPO PAGADO',
                      style: TextStyle(
                        color: completo
                            ? const Color(0xFF90EE90)
                            : const Color(0xFFFFD700),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumenFila(String label, String valor, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        Text(valor,
            style: TextStyle(
                color: color ?? Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ],
    ),
  );

  // ── 5. Producto (con parsing de JSON en observaciones) ────────────────────
  Widget _buildProductoCard() {
    final d        = _detalle!;
    final variante = d['producto_variantes'] as Map<String, dynamic>?;
    final producto = variante?['productos'] as Map<String, dynamic>?;
    final nombre   = producto?['nombre']?.toString() ?? 'Producto';
    final tamano   = variante?['tamaño']?.toString() ?? '';

    // Sabor y dedicatoria pueden venir directo en la fila
    final saborDirecto = d['sabor']?.toString() ?? '';
    final dedDirecta   = d['dedicatoria']?.toString() ?? '';

    // Parsear observaciones (puede ser JSON serializado del formulario)
    final obsRaw = d['observaciones']?.toString() ?? '';
    final obsJson = _parseObs(obsRaw);

    // Priorizar dato directo; si vacío, buscar en el JSON
    final sabor    = saborDirecto.isNotEmpty ? saborDirecto
                   : obsJson['sabor']?.toString() ?? '';
    final ded      = dedDirecta.isNotEmpty ? dedDirecta
                   : obsJson['dedicatoria']?.toString() ?? '';
    final armado   = obsJson['armado']?.toString() ?? '';
    final pisos    = obsJson['pisos']?.toString() ?? '';
    final diseno   = obsJson['diseno']?.toString() ?? '';
    final desc     = obsJson['descripcion']?.toString() ?? '';

    // Si obs NO era JSON, mostrarlo como nota de texto
    final notaTexto = obsRaw.trimLeft().startsWith('{') ? '' : obsRaw;

    final hijos = <Widget>[
      _infoRow(Icons.cake_outlined, 'Nombre', nombre),
      if (tamano.isNotEmpty)
        _infoRow(Icons.straighten_rounded, 'Tamaño', tamano),
      if (sabor.isNotEmpty)
        _infoRow(Icons.grain_rounded, 'Tipo de pan', sabor),
      if (armado.isNotEmpty)
        _infoRow(Icons.layers_rounded, 'Armado', armado),
      if (pisos.isNotEmpty && pisos != '0')
        _infoRow(Icons.format_list_numbered_rounded, 'Pisos', pisos),
      if (diseno.isNotEmpty)
        _infoRow(Icons.palette_rounded, 'Diseño', diseno),
      if (desc.isNotEmpty)
        _infoRow(Icons.description_rounded, 'Descripción', desc),
      if (notaTexto.isNotEmpty)
        _infoRow(Icons.note_outlined, 'Notas', notaTexto),
      if (ded.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Divider(height: 1, color: _cBord),
        ),
        _infoRow(Icons.format_quote_rounded, 'Dedicatoria', '"$ded"',
            bold: true, colorVal: _cP),
      ],
    ];

    return _buildSeccion(
      icon: Icons.cake_rounded,
      titulo: 'Producto',
      hijos: hijos,
    );
  }

  // ── 6. Pagos ──────────────────────────────────────────────────────────────
  Widget _buildPagosCard() {
    return _buildSeccion(
      icon: Icons.wallet_rounded,
      titulo: 'Pagos Recibidos',
      hijos: _pagos.map((pg) {
        final monto  = (pg['monto'] as num?)?.toDouble() ?? 0;
        final metodo = _metodoPago(pg['metodo_pago']?.toString());
        final tipo   = pg['tipo_pago'] == 'anticipo' ? 'Anticipo' : 'Pago total';
        final fecha  = _formatFecha(pg['created_at']?.toString());
        final icon   = pg['metodo_pago'] == 'efectivo'
            ? Icons.payments_rounded
            : pg['metodo_pago'] == 'tarjeta'
                ? Icons.credit_card_rounded
                : Icons.account_balance_rounded;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _cSurf,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cBord),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _cP.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _cP, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(metodo,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('$tipo  •  $fecha',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              Text('\$${monto.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: _cP,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── 7. Cambiar estado ─────────────────────────────────────────────────────
  Widget _buildCambiarEstado() {
    const estados = [
      ('pendiente', 'Pendiente',       Icons.schedule_rounded,      _cBlue),
      ('hecho',     'En preparación',  Icons.blender_rounded,       _cOrange),
      ('entregado', 'Entregado',       Icons.check_circle_rounded,  _cGreen),
    ];

    return _buildSeccion(
      icon: Icons.tune_rounded,
      titulo: 'Actualizar Estado',
      hijos: [
        Row(
          children: estados.map((item) {
            final (val, label, icon, col) = item;
            final sel = _estadoActual == val;
            return Expanded(
              child: GestureDetector(
                onTap: _guardando ? null : () => _cambiarEstado(val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? col.withValues(alpha: 0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? col : _cBord,
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(icon, color: sel ? col : Colors.grey, size: 22),
                      const SizedBox(height: 4),
                      Text(label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                sel ? FontWeight.bold : FontWeight.normal,
                            color: sel ? col : Colors.grey,
                          )),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Helpers de widgets ────────────────────────────────────────────────────
  Widget _buildSeccion({
    required IconData icon,
    required String titulo,
    required List<Widget> hijos,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: _cP, size: 18),
            const SizedBox(width: 8),
            Text(titulo,
                style: const TextStyle(
                  color: _cP,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                )),
          ]),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFF0E8DC)),
          ),
          ...hijos,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String valor,
      {bool bold = false, Color? colorVal}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(valor,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                    color: colorVal ?? Colors.black87)),
          ),
        ],
      ),
    );
  }
}
