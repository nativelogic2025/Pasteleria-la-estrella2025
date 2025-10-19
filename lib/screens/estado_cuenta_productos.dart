// estado_cuenta_productos.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

// ✅ Widgets compartidos ("wingeds")
import 'estado_widgets.dart';

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

  // Filtro de periodo
  String _periodo = 'Día'; // Día | Mes | Año
  DateTime _base = DateTime.now();

  // Formatters
  late final NumberFormat _fmtMon;
  late final DateFormat _fmtDia;
  late final DateFormat _fmtHora12;     // hh:mm a (12h)
  late final DateFormat _fmtFechaCorta; // dd/MM/yyyy

  // Datos dummy (conecta a tu backend cuando quieras)
  final List<VentaProducto> _ventas = [
    VentaProducto(
      fecha: DateTime.now().subtract(const Duration(minutes: 30)),
      producto: 'pastel de chocolate',
      cantidad: 1,
      precioUnit: 280,
      costoUnit: 160,
    ),
    VentaProducto(
      fecha: DateTime.now().subtract(const Duration(hours: 2)),
      producto: 'pay de queso',
      cantidad: 2,
      precioUnit: 150,
      costoUnit: 90,
    ),
    VentaProducto(
      fecha: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
      producto: 'galletas surtidas',
      cantidad: 5,
      precioUnit: 25,
      costoUnit: 10,
    ),
    VentaProducto(
      fecha: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
      producto: 'pastel tres leches',
      cantidad: 1,
      precioUnit: 320,
      costoUnit: 190,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initIntl();
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
    return list.take(5).toList();
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
        title: const Text('Productos'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
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
      body: Align(
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
                    title: 'Ventas brutas',
                    value: _fmtMon.format(_ventasBrutas),
                    icon: Icons.point_of_sale,
                  ),
                  KpiCard(
                    title: 'Costo mercancía',
                    value: _fmtMon.format(_costoMercancia),
                    icon: Icons.inventory_2,
                  ),
                  KpiCard(
                    title: 'Utilidad',
                    value: _fmtMon.format(_utilidadProductos),
                    icon: Icons.attach_money,
                  ),
                  KpiCard(
                    title: 'Margen',
                    value: '${(_margenProductos * 100).toStringAsFixed(1)} %',
                    icon: Icons.pie_chart_outline,
                  ),
                  KpiCard(
                    title: 'Unidades vendidas',
                    value: _unidadesVendidas.toString(),
                    icon: Icons.shopping_cart_checkout,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Top productos
              SectionCard(
                title: 'Top productos del periodo',
                child: _topProductos.isEmpty
                    ? const EmptyState(
                        icon: Icons.star_border,
                        title: 'Sin ventas',
                        subtitle: 'No hay ventas registradas en este periodo.',
                      )
                    : Column(
                        children: _topProductos.map((e) {
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
                                      Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: cant / max,
                                          minHeight: 8,
                                          backgroundColor: const Color(0xFFF0F0F0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('x$cant', style: const TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 12),

              // Ventas del periodo (formato frase SIEMPRE "en efectivo")
              SectionCard(
                title: 'Ventas del periodo',
                child: ventasPeriodo.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long,
                        title: 'Sin ventas',
                        subtitle: 'No hay ventas registradas en este periodo.',
                      )
                    : Column(
                        children: ventasPeriodo.map((v) {
                          final total = v.cantidad * v.precioUnit;
                          final hora = _fmtHora12.format(v.fecha).toLowerCase(); // ej. 12:30 p. m.
                          final frase =
                              '${v.cantidad} ${v.producto} a las $hora en efectivo';
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFF3F3F3),
                              child: const Icon(Icons.payments_outlined, color: Colors.black87),
                            ),
                            title: Text(
                              // Capitaliza primera letra
                              frase[0].toUpperCase() + frase.substring(1),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(_fmtFechaCorta.format(v.fecha)),
                            trailing: Text(
                              _fmtMon.format(total),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          );
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
