import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/timezone_utils.dart';
import 'estado_widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// ======== MODELOS ========
class VentaProducto {
  final DateTime fecha;
  final String producto;
  final int cantidad;
  final double precioUnit; // precio de venta
  final double costoUnit;  // costo

  VentaProducto({
    required this.fecha,
    required this.producto,
    required this.cantidad,
    required this.precioUnit,
    required this.costoUnit,
  });
}

/// ======== PANTALLA PRODUCTOS ========
class EstadoCuentaProductosScreen extends StatefulWidget {
  const EstadoCuentaProductosScreen({super.key});

  @override
  State<EstadoCuentaProductosScreen> createState() => _EstadoCuentaProductosScreenState();
}

class _EstadoCuentaProductosScreenState extends State<EstadoCuentaProductosScreen> {
  bool _intlReady = false;
  bool _loading = true;
  final _supabase = Supabase.instance.client;

  // Filtro de periodo
  String _periodo = 'Día'; // Día | Mes | Año
  DateTime _base = DateTime.now();

  // Formatters
  late final NumberFormat _fmtMon;
  late final DateFormat _fmtDia;
  late final DateFormat _fmtHora12;     // hh:mm a (12h)
  late final DateFormat _fmtFechaCorta; // dd/MM/yyyy

  List<VentaProducto> _ventas = [];

  @override
  void initState() {
    super.initState();
    _initIntl().then((_) => _cargarVentasDetalle());
  }


  Future<void> _initIntl() async {
    Intl.defaultLocale = 'es_MX';
    await initializeDateFormatting('es_MX', null);
    _fmtMon = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    _fmtDia = DateFormat("EEEE, d 'de' MMMM 'de' y", 'es_MX');
    _fmtHora12 = DateFormat('hh:mm a', 'es_MX');      // 12h con am/pm
    _fmtFechaCorta = DateFormat('dd/MM/yyyy', 'es_MX');
    if (mounted) setState(() => _intlReady = true);
  }

  Future<void> _cargarVentasDetalle() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final unificado = <VentaProducto>[];

      // Extraer renglones vendidos en mostrador
      final vDetalle = await _supabase.from('ventas_detalle').select('id_venta, id_producto, cantidad, precio_unitario');
      
      final idVentas = vDetalle.map((v) => v['id_venta'] as int?).where((e) => e != null).toSet().toList();
      final idProds = vDetalle.map((v) => v['id_producto'] as int?).where((e) => e != null).toSet().toList();

      final vVentasDate = <int, DateTime>{};
      if (idVentas.isNotEmpty) {
        final resVentas = await _supabase.from('ventas').select('id_venta, fecha').inFilter('id_venta', idVentas);
        for (var row in resVentas) {
          final idV = row['id_venta'] as int?;
          final fStr = row['fecha'];
          if (idV != null && fStr != null) {
            vVentasDate[idV] = parseSupabaseTs(fStr.toString());
          }
        }
      }

      final vProdsInfo = <int, String>{};
      if (idProds.isNotEmpty) {
        final resProds = await _supabase.from('productos').select('id_producto, nombre').inFilter('id_producto', idProds);
        for (var row in resProds) {
          final idP = row['id_producto'] as int?;
          if (idP != null) {
            vProdsInfo[idP] = row['nombre'].toString();
          }
        }
      }

      for (var det in vDetalle) {
          final idV = det['id_venta'] as int?;
          final idP = det['id_producto'] as int?;
          if (idV == null || idP == null) continue;

          final fecha = vVentasDate[idV];
          final nombreProd = vProdsInfo[idP];
          if (fecha == null || nombreProd == null) continue;

          final precioUnitario = double.tryParse(det['precio_unitario'].toString()) ?? 0.0;

          unificado.add(VentaProducto(
               fecha: fecha,
               producto: nombreProd,
               cantidad: int.tryParse(det['cantidad'].toString()) ?? 1,
               precioUnit: precioUnitario,
               costoUnit: precioUnitario * 0.55, // Costo aproximado (55%) al no tener columna específica
          ));
      }

      // Order recien a antiguo
      unificado.sort((a, b) => b.fecha.compareTo(a.fecha));

      if (mounted) {
        setState(() {
            _ventas = unificado;
            _loading = false;
        });
      }

    } catch (e) {
      if (mounted) {
         setState(() => _loading = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ======== LÓGICA DE PERIODO ========
  bool _enPeriodo(DateTime d) {
    final base = DateTime(_base.year, _base.month, _base.day);
    switch (_periodo) {
      case 'Día':
        return DateTime(d.year, d.month, d.day) == base;
      case 'Mes':
        return d.year == base.year && d.month == base.month;
      case 'Año':
        return d.year == base.year;
      default:
        return true;
    }
  }

  // ======== CÁLCULOS ========
  int get _unidadesVendidas =>
      _ventas.where((v) => _enPeriodo(v.fecha)).fold(0, (p, e) => p + e.cantidad);

  double get _ventasBrutas =>
      _ventas.where((v) => _enPeriodo(v.fecha)).fold(0.0, (p, e) => p + e.cantidad * e.precioUnit);

  double get _costoMercancia =>
      _ventas.where((v) => _enPeriodo(v.fecha)).fold(0.0, (p, e) => p + e.cantidad * e.costoUnit);

  double get _utilidadProductos => _ventasBrutas - _costoMercancia;

  double get _margenProductos => _ventasBrutas == 0 ? 0 : (_utilidadProductos / _ventasBrutas);

  List<MapEntry<String, int>> get _topProductos {
    final map = <String, int>{};
    for (final v in _ventas.where((v) => _enPeriodo(v.fecha))) {
      map.update(v.producto, (old) => old + v.cantidad, ifAbsent: () => v.cantidad);
    }
    final list = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  // ======== UI ========
  @override
  Widget build(BuildContext context) {
    if (!_intlReady) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final titlePeriodo = _periodo == 'Día'
        ? _fmtDia.format(_base)
        : _periodo == 'Mes'
            ? DateFormat('MMMM y', 'es_MX').format(_base)
            : DateFormat('y', 'es_MX').format(_base);

    final ventasPeriodo =
        _ventas.where((v) => _enPeriodo(v.fecha)).toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Productos y Desempeño', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarVentasDetalle)
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: PeriodoHeader(
            periodoValue: _periodo,
            onPeriodoChanged: (v) => setState(() => _periodo = v!),
            onPrev: () => setState(() {
              if (_periodo == 'Día') {
                _base = _base.subtract(const Duration(days: 1));
              } else if (_periodo == 'Mes') {
                _base = DateTime(_base.year, _base.month - 1, _base.day);
              } else {
                _base = DateTime(_base.year - 1, _base.month, _base.day);
              }
            }),
            onNext: () => setState(() {
              if (_periodo == 'Día') {
                _base = _base.add(const Duration(days: 1));
              } else if (_periodo == 'Mes') {
                _base = DateTime(_base.year, _base.month + 1, _base.day);
              } else {
                _base = DateTime(_base.year + 1, _base.month, _base.day);
              }
            }),
            titlePeriodo: titlePeriodo,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                  children: [
                    // KPIs
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        KpiCard(
                          title: 'Ventas Brutas',
                          value: _fmtMon.format(_ventasBrutas),
                          icon: Icons.point_of_sale,
                        ),
                        KpiCard(
                          title: 'Costo de Mercancía',
                          value: _fmtMon.format(_costoMercancia),
                          icon: Icons.inventory_2,
                          iconColor: Colors.deepPurple,
                        ),
                        KpiCard(
                          title: 'Utilidad Operativa',
                          value: _fmtMon.format(_utilidadProductos),
                          icon: Icons.attach_money,
                        ),
                        KpiCard(
                          title: 'Margen Promedio',
                          value: '${(_margenProductos * 100).toStringAsFixed(1)} %',
                          icon: Icons.pie_chart_outline,
                        ),
                        KpiCard(
                          title: 'Volumen',
                          value: '$_unidadesVendidas pzas',
                          icon: Icons.shopping_cart_checkout,
                        ),
                      ].animate(interval: 50.ms).fade(duration: 400.ms).scaleXY(begin: 0.9),
                    ),
                    const SizedBox(height: 16),

                    // Top productos
                    SectionCard(
                      title: 'Rendimiento y Más Vendidos',
                      child: _topProductos.isEmpty
                          ? const EmptyState(
                              icon: Icons.star_border,
                              title: 'Sin volumen de venta',
                              subtitle: 'No hay productos de mostrador ni catálogo desplazados en este periodo.',
                            )
                          : Column(
                              children: _topProductos.take(15).map((e) {
                                final nombre = e.key;
                                final cant = e.value;
                                final max = (_topProductos.first.value).toDouble().clamp(1, 9999);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(nombre.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                            const SizedBox(height: 6),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: LinearProgressIndicator(
                                                value: cant / max,
                                                minHeight: 8,
                                                backgroundColor: const Color(0xFFF0F0F0),
                                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Text('x$cant', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.blueGrey)),
                                    ],
                                  ),
                                ).animate(key: ValueKey(nombre))
                                 .fade(duration: 300.ms, delay: (20 * _topProductos.take(15).toList().indexOf(e)).ms)
                                 .slideX(begin: 0.05, duration: 300.ms, delay: (20 * _topProductos.take(15).toList().indexOf(e)).ms);
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 12),

                    // Historial
                    SectionCard(
                      title: 'Historial de Productos Ruteados',
                      child: ventasPeriodo.isEmpty
                          ? const EmptyState(
                              icon: Icons.receipt_long,
                              title: 'Sin movimiento',
                              subtitle: 'No se procesó cobro de ningún producto.',
                            )
                          : Column(
                              children: ventasPeriodo.map((v) {
                                final total = v.cantidad * v.precioUnit;
                                final hora = _fmtHora12.format(v.fecha).toLowerCase();
                                final frase = '${v.cantidad} ${v.producto} · $hora';
                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFFE8F5E9),
                                    child: const Icon(Icons.inventory_2_rounded, color: Colors.green, size: 18),
                                  ),
                                  title: Text(
                                    frase,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(_fmtFechaCorta.format(v.fecha)),
                                  trailing: Text(
                                    _fmtMon.format(total),
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ).animate(key: ValueKey(v.fecha.millisecondsSinceEpoch.toString() + v.producto))
                                 .fade(duration: 300.ms, delay: (20 * ventasPeriodo.indexOf(v)).ms)
                                 .slideX(begin: 0.05, duration: 300.ms, delay: (20 * ventasPeriodo.indexOf(v)).ms);
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}