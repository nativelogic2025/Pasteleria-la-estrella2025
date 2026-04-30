// ticket_publico_screen.dart
// Pantalla pública accesible escaneando el QR del ticket impreso.
// Consulta Supabase por folio y muestra todos los datos del pedido.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/timezone_utils.dart';

final _sb = Supabase.instance.client;

String _moneda(double v) => '\$${v.toStringAsFixed(2)} MXN';

// ─── Pantalla ──────────────────────────────────────────────────────────────
class TicketPublicoScreen extends StatefulWidget {
  final String folio;
  const TicketPublicoScreen({super.key, required this.folio});

  @override
  State<TicketPublicoScreen> createState() => _TicketPublicoScreenState();
}

class _TicketPublicoScreenState extends State<TicketPublicoScreen> {
  Map<String, dynamic>? _pedido;
  Map<String, dynamic>? _cliente;
  List<Map<String, dynamic>> _detalles = [];
  List<Map<String, dynamic>> _pagos = [];
  bool _cargando = true;
  String? _error;

  static const _cP    = Color(0xFF8C5535);
  static const _cSurf = Color(0xFFFCF5EE);
  static const _cBord = Color(0xFFE5CEB3);
  static const _cBg   = Color(0xFFFAFAFA);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final res = await _sb
          .from('pedidos')
          .select('*, clientes(*)')
          .eq('folio', widget.folio)
          .maybeSingle();

      if (res == null) {
        setState(() {
          _error = 'No se encontró el pedido con folio ${widget.folio}';
          _cargando = false;
        });
        return;
      }

      final detalles = await _sb
          .from('detalle_pedido')
          .select('*, producto_variantes(*, productos(*))')
          .eq('id_pedido', res['id_pedido']);

      final pagos = await _sb
          .from('pagos')
          .select()
          .eq('id_pedido', res['id_pedido']);

      setState(() {
        _pedido   = res;
        _cliente  = res['clientes'] as Map<String, dynamic>?;
        _detalles = List<Map<String, dynamic>>.from(detalles ?? []);
        _pagos    = List<Map<String, dynamic>>.from(pagos ?? []);
        _cargando = false;
      });
    } catch (e) {
      setState(() { _error = 'Error al cargar: $e'; _cargando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      body: CustomScrollView(
        slivers: [
          // ── Header con gradiente ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: _cP,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5C3316), Color(0xFF8C5535)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('PASTELERÍA LA ESTRELLA',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w500,
                            )),
                        const SizedBox(height: 6),
                        Text(widget.folio,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            )),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Tu Ticket Digital',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Contenido ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _cargando
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(child: CircularProgressIndicator(color: _cP)),
                  )
                : _error != null
                    ? _buildError()
                    : _buildContenido(),
          ),
        ],
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
            const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Contenido principal ───────────────────────────────────────────────────
  Widget _buildContenido() {
    final p           = _pedido!;
    final pagoTotal   = _pagos.fold<double>(
        0, (s, e) => s + ((e['monto'] as num?)?.toDouble() ?? 0));
    final total       = (p['total'] as num?)?.toDouble() ?? 0;
    final restante    = (total - pagoTotal).clamp(0.0, double.infinity);
    final pagoCompleto = restante < 0.01;
    final estadoPago  = pagoCompleto ? 'LIQUIDADO' : 'ANTICIPO PAGADO';

    final fechaEntrega = p['fecha_entrega']?.toString() ?? '—';
    final horaEntrega  = (p['hora_entrega']?.toString() ?? '').replaceAll(':00', '').trim();
    final fechaFmt     = _formatFecha(fechaEntrega);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge de estado de pago
          _buildBadgeEstado(estadoPago, pagoCompleto),
          const SizedBox(height: 16),

          // Cliente
          _seccion(
            icon: Icons.person_rounded,
            titulo: 'Cliente',
            hijos: [
              _fila('Nombre', _cliente?['nombre']?.toString() ?? '—'),
              _fila('Teléfono', _cliente?['telefono']?.toString() ?? '—'),
              if ((_cliente?['direccion']?.toString() ?? '').isNotEmpty)
                _fila('Dirección', _cliente!['direccion'].toString()),
            ],
          ),

          // Entrega
          _seccion(
            icon: Icons.event_rounded,
            titulo: 'Entrega',
            hijos: [
              _fila('Fecha',
                  '$fechaFmt${horaEntrega.isNotEmpty ? '  •  $horaEntrega' : ''}'),
              _fila('Modalidad',
                  p['tipo_entrega'] == 'domicilio'
                      ? 'Envío a domicilio'
                      : 'Recoger en sucursal'),
            ],
          ),

          // Productos
          if (_detalles.isNotEmpty)
            _seccion(
              icon: Icons.cake_rounded,
              titulo: 'Pedido',
              hijos: _detalles.map((d) {
                final variante = d['producto_variantes'] as Map<String, dynamic>?;
                final producto = variante?['productos'] as Map<String, dynamic>?;
                final nombre   = producto?['nombre']?.toString() ?? 'Producto';
                final tamano   = variante?['tamaño']?.toString() ?? '';
                final sabor    = d['sabor']?.toString() ?? '';
                final ded      = d['dedicatoria']?.toString() ?? '';
                final obs      = d['observaciones']?.toString() ?? '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fila('Producto', nombre),
                    if (tamano.isNotEmpty) _fila('Tamaño', tamano),
                    if (sabor.isNotEmpty)  _fila('Tipo de pan', sabor),
                    if (ded.isNotEmpty)    _fila('Dedicatoria', '"$ded"'),
                    if (obs.isNotEmpty)    _fila('Notas', obs),
                  ],
                );
              }).toList(),
            ),

          // Resumen financiero
          _seccion(
            icon: Icons.receipt_long_rounded,
            titulo: 'Resumen de Pago',
            hijos: [
              _fila('Total del pedido', _moneda(total),
                  negrita: true, colorVal: _cP),
              ..._pagos.map((pg) {
                final tip = pg['tipo_pago'] == 'anticipo' ? ' (anticipo)' : '';
                final monto = (pg['monto'] as num?)?.toDouble() ?? 0;
                return _fila('Pagado$tip', _moneda(monto),
                    colorVal: const Color(0xFF27AE60));
              }),
              if (!pagoCompleto)
                _fila('Pendiente al entregar', _moneda(restante),
                    negrita: true, colorVal: const Color(0xFFE67E22)),
            ],
          ),

          // Métodos de pago
          if (_pagos.isNotEmpty)
            _seccion(
              icon: Icons.wallet_rounded,
              titulo: 'Forma(s) de Pago',
              hijos: _pagos.map((pg) {
                final met   = _metodoPagoLabel(pg['metodo_pago']?.toString() ?? '');
                final monto = (pg['monto'] as num?)?.toDouble() ?? 0;
                return _fila(met, _moneda(monto));
              }).toList(),
            ),

          // Nota final
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cSurf,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cBord),
            ),
            child: const Row(
              children: [
                Icon(Icons.favorite_rounded, color: _cP, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¡Gracias por confiar en Pastelería La Estrella! '
                    'Cualquier duda llámanos.',
                    style: TextStyle(
                        color: _cP,
                        fontSize: 13,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Badge estado ──────────────────────────────────────────────────────────
  Widget _buildBadgeEstado(String estado, bool completo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: completo ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: completo ? const Color(0xFF27AE60) : const Color(0xFFE67E22),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            completo ? Icons.check_circle_rounded : Icons.access_time_rounded,
            color: completo ? const Color(0xFF27AE60) : const Color(0xFFE67E22),
            size: 40,
          ),
          const SizedBox(height: 6),
          Text(estado,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: completo
                    ? const Color(0xFF1B6B35)
                    : const Color(0xFF9C5500),
              )),
        ],
      ),
    );
  }

  // ── Card de sección ───────────────────────────────────────────────────────
  Widget _seccion({
    required IconData icon,
    required String titulo,
    required List<Widget> hijos,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
          const Divider(height: 16, color: Color(0xFFF0E8DC)),
          ...hijos,
        ],
      ),
    );
  }

  Widget _fila(String label, String valor,
      {bool negrita = false, Color? colorVal}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(valor,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: negrita ? FontWeight.bold : FontWeight.w600,
                  color: colorVal ?? Colors.black87,
                )),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _formatFecha(String iso) {
    try {
      final d = parseSupabaseTs(iso); // UTC sin Z → hora México
      const meses = [
        'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
      ];
      return '${d.day} de ${meses[d.month - 1]} de ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  String _metodoPagoLabel(String val) {
    switch (val) {
      case 'efectivo':      return 'Efectivo';
      case 'tarjeta':       return 'Tarjeta';
      case 'transferencia': return 'Transferencia / Depósito';
      default:              return val;
    }
  }
}
