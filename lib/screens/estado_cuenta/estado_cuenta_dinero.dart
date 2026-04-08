// estado_cuenta_dinero.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../servicios/supabase_client.dart';


// ✅ Widgets compartidos ("wingeds")
import 'estado_widgets.dart';

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
  List<MovimientoDinero> _movimientos = [];
  bool _loading = true;

  // Filtro de periodo
  String _periodo = 'Día'; // Día | Mes | Año
  DateTime _base = DateTime.now();

  // Formatters
  late final NumberFormat _fmtMon;
  late final DateFormat _fmtDia;
  late final DateFormat _fmtHora;
  late final DateFormat _fmtFechaCorta;

  @override
  void initState() {
    super.initState();
    _cargar();
    _initIntl();
  }

  // ---------- Data (Supabase) ----------
  // 1. Cargar productos de la categoría
  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // INGRESOS DE PEDIDOS
      var query = supabase.from('pedidos').select('''
        fecha_pedido,
        folio,
        total,
        restante
      ''');
      final respuestaSupabase = await query.order('fecha_pedido', ascending: false);
      final filtro1 = respuestaSupabase.where((pedido) {
        double diferencia = (double.tryParse(pedido['total'].toString()) ?? 0) - (double.tryParse(pedido['restante'].toString()) ?? 0);
        
        return diferencia > 0; 
      }).toList();

      if (!mounted) return;  

      // 4. MAPEO DE DATOS: Convertimos los Mapas crudos a objetos
      List<MovimientoDinero> listaMapeada = (filtro1 as List<dynamic>).map((fila) {       
        // C) Mapeo del Enum de estado:
        /*TipoMovimiento typeEnum;
        switch ('ingreso') {
          case 'ingreso':
            typeEnum = TipoMovimiento.ingreso;
            break;
          default:
            typeEnum = TipoMovimiento.gasto;
        }*/

        double diferencia = (double.tryParse(fila['total'].toString()) ?? 0) - (double.tryParse(fila['restante'].toString()) ?? 0);
        final DateTime fechaHoraCompleta = DateTime.tryParse(fila['fecha_pedido'].toString()) ?? DateTime.now();

        // D) Construimos y retornamos el objeto final
        return MovimientoDinero(
          fecha: fechaHoraCompleta,
          tipo: TipoMovimiento.ingreso,
          monto: diferencia,
          concepto: 'Pedido ${fila['folio'].toString()}',
        );
        
      }).toList();

      // INGRESOS DE VENTAS
      var query2 = supabase.from('pagos_venta').select('''
        fecha,
        monto,
        ventas( folio )
      ''');
      final respuestaSupabase2 = await query2.order('fecha', ascending: false);

      if (!mounted) return; 

      listaMapeada += (respuestaSupabase2 as List<dynamic>).map((fila) {

        final DateTime fechaHoraCompleta = DateTime.tryParse(fila['fecha'].toString()) ?? DateTime.now();

        // D) Construimos y retornamos el objeto final
        return MovimientoDinero(
          fecha: fechaHoraCompleta,
          tipo: TipoMovimiento.ingreso,
          monto: (double.tryParse(fila['monto'].toString()) ?? 0),
          concepto: 'Venta ${fila['ventas']['folio'].toString()}',
        );
        
      }).toList();

      // GASTOS
      var query3 = supabase.from('gastos').select('''
        fecha,
        monto,
        concepto
      ''');
      final respuestaSupabase3 = await query3.order('fecha', ascending: false);

      if (!mounted) return; 

      listaMapeada += (respuestaSupabase3 as List<dynamic>).map((fila) {

        final DateTime fechaHoraCompleta = DateTime.tryParse(fila['fecha'].toString()) ?? DateTime.now();

        // D) Construimos y retornamos el objeto final
        return MovimientoDinero(
          fecha: fechaHoraCompleta,
          tipo: TipoMovimiento.gasto,
          monto: (double.tryParse(fila['monto'].toString()) ?? 0),
          concepto: 'Pago ${fila['concepto'].toString()}',
        );
        
      }).toList();


      setState(() {
        _movimientos = listaMapeada; // 👈 Ahora _todos recibe puros PedidoEvent reales
        _loading = false;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _movimientos = []; 
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar pedidos: $e'), backgroundColor: Colors.red),
      );
    }
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
        title: const Text('Dinero'),
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
          child: _loading 
              ? const Center(child: CircularProgressIndicator(color: Colors.black))
              : ListView(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
            children: [
              // KPIs
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  KpiCard(
                    title: 'Ingresos',
                    value: _fmtMon.format(_totalIngresos),
                    icon: Icons.trending_up,
                  ),
                  KpiCard(
                    title: 'Gastos',
                    value: _fmtMon.format(_totalGastos),
                    icon: Icons.trending_down,
                    iconColor: Colors.redAccent,
                  ),
                  KpiCard(
                    title: 'Utilidad',
                    value: _fmtMon.format(_utilidad),
                    icon: Icons.attach_money,
                  ),
                  KpiCard(
                    title: 'Margen',
                    value: '${(_margen * 100).toStringAsFixed(1)} %',
                    icon: Icons.pie_chart_outline,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Lista de movimientos
              SectionCard(
                title: 'Movimientos del periodo',
                child: movimientosPeriodo.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long,
                        title: 'Sin movimientos',
                        subtitle: 'No hay ingresos o gastos en este periodo.',
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
                                color: esIngreso ? Colors.green : Colors.red,
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
                              ),
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
