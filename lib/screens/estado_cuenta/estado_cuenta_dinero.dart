import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/timezone_utils.dart';
import 'estado_widgets.dart';
import 'agregar_gasto.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// ======== MODELOS ========
enum TipoMovimiento { ingreso, gasto }

class MovimientoDinero {
  final DateTime fecha;
  final TipoMovimiento tipo;
  final double monto;
  final String concepto;

  MovimientoDinero({
    required this.fecha,
    required this.tipo,
    required this.monto,
    required this.concepto,
  });
}

/// ======== PANTALLA DINERO ========
class EstadoCuentaDineroScreen extends StatefulWidget {
  const EstadoCuentaDineroScreen({super.key});

  @override
  State<EstadoCuentaDineroScreen> createState() => _EstadoCuentaDineroScreenState();
}

class _EstadoCuentaDineroScreenState extends State<EstadoCuentaDineroScreen> {
  bool _intlReady = false;
  bool _loading = true;
  final _supabase = Supabase.instance.client;

  // Filtro de periodo
  String _periodo = 'Día'; // Día | Mes | Año
  DateTime _base = DateTime.now();

  // Formatters
  late final NumberFormat _fmtMon;
  late final DateFormat _fmtDia;
  late final DateFormat _fmtHora;
  late final DateFormat _fmtFechaCorta;

  // Datos reales desde Supabase
  List<MovimientoDinero> _movimientos = [];

  @override
  void initState() {
    super.initState();
    _initIntl().then((_) => _cargarMovimientos());
  }


  Future<void> _initIntl() async {
    Intl.defaultLocale = 'es_MX';
    await initializeDateFormatting('es_MX', null);
    _fmtMon = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    _fmtDia = DateFormat("EEEE, d 'de' MMMM 'de' y", 'es_MX');
    _fmtHora = DateFormat('HH:mm', 'es_MX');
    _fmtFechaCorta = DateFormat('dd/MM/yyyy', 'es_MX');
    if (mounted) setState(() => _intlReady = true);
  }

  Future<void> _cargarMovimientos() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final List<MovimientoDinero> unificado = [];

      // 1. OBTENER INGRESOS DE MOSTRADOR (Ventas Rápidas)
      final resVentas = await _supabase.from('pagos_venta').select('fecha, monto, id_venta');
      
      // Diccionario en memoria para folios de ventas y pedidos (evita error de FK missing)
      final ventasIds = resVentas.map((v) => v['id_venta'] as int?).where((v) => v != null).toSet().toList();
      final Map<int, String> foliosVentas = {};
      if (ventasIds.isNotEmpty) {
        final fVentas = await _supabase.from('ventas').select('id_venta, folio').inFilter('id_venta', ventasIds);
        for (var f in fVentas) {
          foliosVentas[f['id_venta'] as int] = f['folio'].toString();
        }
      }

      for (var row in resVentas) {
        final fStr = row['fecha'];
        final mStr = row['monto'];
        final idV = row['id_venta'] as int?;
        final folioInfo = (idV != null && foliosVentas.containsKey(idV)) ? foliosVentas[idV] : 'N/A';
        
        if (fStr != null && mStr != null) {
          unificado.add(MovimientoDinero(
            fecha: parseSupabaseTs(fStr.toString()),
            tipo: TipoMovimiento.ingreso,
            monto: double.tryParse(mStr.toString()) ?? 0,
            concepto: 'Venta Caja #$folioInfo',
          ));
        }
      }

      // 2. OBTENER INGRESOS DE PEDIDOS/WEB (Anticipos o Pagos)
      final resPedidos = await _supabase.from('pagos').select('fecha, monto, id_pedido');
      final pedidosIds = resPedidos.map((p) => p['id_pedido'] as int?).where((p) => p != null).toSet().toList();
      final Map<int, String> foliosPedidos = {};
      if (pedidosIds.isNotEmpty) {
        final fPedidos = await _supabase.from('pedidos').select('id_pedido, folio').inFilter('id_pedido', pedidosIds);
        for (var f in fPedidos) {
          foliosPedidos[f['id_pedido'] as int] = f['folio'].toString();
        }
      }

      for (var row in resPedidos) {
        final fStr = row['fecha'];
        final mStr = row['monto'];
        final idP = row['id_pedido'] as int?;
        final folioInfo = (idP != null && foliosPedidos.containsKey(idP)) ? foliosPedidos[idP] : 'N/A';

        if (fStr != null && mStr != null) {
          unificado.add(MovimientoDinero(
            fecha: parseSupabaseTs(fStr.toString()),
            tipo: TipoMovimiento.ingreso,
            monto: double.tryParse(mStr.toString()) ?? 0,
            concepto: 'Pedido #$folioInfo',
          ));
        }
      }

      // 3. OBTENER EGRESOS (Gastos)
      // Se mete en try/catch independiente para que si la tabla gastos aún no existe, no crashee ventas.
      try {
        final resGastos = await _supabase.from('gastos').select('fecha, monto, concepto');
        for (var row in resGastos) {
          final fStr = row['fecha'];
          final mStr = row['monto'];
          if (fStr != null && mStr != null) {
            unificado.add(MovimientoDinero(
              fecha: parseSupabaseTs(fStr.toString()),
              tipo: TipoMovimiento.gasto,
              monto: double.tryParse(mStr.toString()) ?? 0,
              concepto: row['concepto']?.toString() ?? 'Gasto',
            ));
          }
        }
      } catch (eGasto) {
        debugPrint('Tabla gastos aún no existe: $eGasto');
      }

      // Ordenar por fecha recien a antiguo
      unificado.sort((a, b) => b.fecha.compareTo(a.fecha));

      if (mounted) {
        setState(() {
          _movimientos = unificado;
          _loading = false; // FINISHED LOADING
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar contabilidad: $e'), backgroundColor: Colors.red),
        );
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
  double get _totalIngresos => _movimientos
      .where((m) => _enPeriodo(m.fecha) && m.tipo == TipoMovimiento.ingreso)
      .fold(0.0, (p, e) => p + e.monto);

  double get _totalGastos => _movimientos
      .where((m) => _enPeriodo(m.fecha) && m.tipo == TipoMovimiento.gasto)
      .fold(0.0, (p, e) => p + e.monto);

  double get _utilidad => _totalIngresos - _totalGastos;

  double get _margen => _totalIngresos == 0 ? 0 : (_utilidad / _totalIngresos);

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

    final movimientosPeriodo =
        _movimientos.where((m) => _enPeriodo(m.fecha)).toList()
          ..sort((a, b) => b.fecha.compareTo(a.fecha));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Flujo de Caja Real', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarMovimientos,
            tooltip: 'Sincronizar base de datos',
          )
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
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 100),
                  children: [
                    // KPIs
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        KpiCard(
                          title: 'Ingresos Netos',
                          value: _fmtMon.format(_totalIngresos),
                          icon: Icons.trending_up,
                        ),
                        KpiCard(
                          title: 'Gastos Netos',
                          value: _fmtMon.format(_totalGastos),
                          icon: Icons.trending_down,
                          iconColor: Colors.redAccent,
                        ),
                        KpiCard(
                          title: 'Caja Resultante',
                          value: _fmtMon.format(_utilidad),
                          icon: Icons.account_balance_wallet,
                        ),
                        KpiCard(
                          title: 'Margen Rentable',
                          value: '${(_margen * 100).toStringAsFixed(1)} %',
                          icon: Icons.pie_chart_outline,
                        ),
                      ].animate(interval: 50.ms).fade(duration: 400.ms).scaleXY(begin: 0.9),
                    ),
                    const SizedBox(height: 16),

                    // Lista de movimientos
                    SectionCard(
                      title: 'Transacciones y Movimientos de Caja',
                      child: movimientosPeriodo.isEmpty
                          ? const EmptyState(
                              icon: Icons.receipt_long,
                              title: 'Sin movimientos',
                              subtitle: 'No hay ingresos ni salidas de dinero registradas en este periodo.',
                            )
                          : Column(
                              children: movimientosPeriodo.map((m) {
                                final esIngreso = m.tipo == TipoMovimiento.ingreso;
                                return ListTile(
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor: esIngreso
                                        ? Colors.green.withOpacity(.12)
                                        : Colors.red.withOpacity(.12),
                                    child: Icon(
                                      esIngreso
                                          ? Icons.arrow_downward_rounded
                                          : Icons.arrow_upward_rounded,
                                      color: esIngreso ? Colors.green : Colors.redAccent,
                                    ),
                                  ),
                                  title: Text(
                                    m.concepto,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    '${_fmtFechaCorta.format(m.fecha)} · ${_fmtHora.format(m.fecha)}',
                                  ),
                                  trailing: Text(
                                    (esIngreso ? '+' : '-') + _fmtMon.format(m.monto),
                                    style: TextStyle(
                                      color: esIngreso ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ).animate(key: ValueKey(m.fecha.millisecondsSinceEpoch.toString() + m.concepto))
                                 .fade(duration: 300.ms, delay: (20 * movimientosPeriodo.indexOf(m)).ms)
                                 .slideX(begin: 0.05, duration: 300.ms, delay: (20 * movimientosPeriodo.indexOf(m)).ms);
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        icon: const Icon(Icons.money_off, color: Colors.white),
        label: const Text('Nuevo Gasto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () async {
          final res = await Navigator.push(
            context,
             MaterialPageRoute(builder: (_) => const AgregarGastoScreen()),
          );
          if (res == true && mounted) {
            _cargarMovimientos();
          }
        },
      ),
    );
  }
}