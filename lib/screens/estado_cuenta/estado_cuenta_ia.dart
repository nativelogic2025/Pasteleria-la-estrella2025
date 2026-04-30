import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';

import '../../utils/timezone_utils.dart';
import 'estado_widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EstadoCuentaIaScreen extends StatefulWidget {
  const EstadoCuentaIaScreen({super.key});

  @override
  State<EstadoCuentaIaScreen> createState() => _EstadoCuentaIaScreenState();
}

class _EstadoCuentaIaScreenState extends State<EstadoCuentaIaScreen> {
  final _supabase = Supabase.instance.client;
  
  String _periodo = 'Mes'; // Día | Mes | Año
  DateTime _base = DateTime.now();
  
  bool _isLoading = false;
  String _reporte = '';
  
  double _totalIngresosState = 0;
  double _totalGastosState = 0;
  List<MapEntry<String, int>> _topProductosState = [];
  
  String? _apiKey;
  final _apiKeyCtrl = TextEditingController();

  late final NumberFormat _fmtMon;

  @override
  void initState() {
    super.initState();
    _fmtMon = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    _cargarApiKey();
  }

  Future<void> _cargarApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('gemini_api_key');
    });
  }

  Future<void> _guardarApiKey() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);
    setState(() {
      _apiKey = key;
    });
    _apiKeyCtrl.clear();
  }

  Future<void> _borrarApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gemini_api_key');
    setState(() {
      _apiKey = null;
      _reporte = '';
    });
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

  Future<void> _generarReporte() async {
    if (_apiKey == null || _apiKey!.isEmpty) return;
    setState(() {
      _isLoading = true;
      _reporte = '';
    });

    try {
      // 1. OBTENER INGRESOS
      double totalIngresos = 0;
      final resVentas = await _supabase.from('pagos_venta').select('fecha, monto');
      for (var row in resVentas) {
        final fStr = row['fecha'];
        final mStr = row['monto'];
        if (fStr != null && mStr != null) {
          final dt = parseSupabaseTs(fStr.toString());
          if (_enPeriodo(dt)) {
            totalIngresos += double.tryParse(mStr.toString()) ?? 0;
          }
        }
      }
      final resPedidos = await _supabase.from('pagos').select('fecha, monto');
      for (var row in resPedidos) {
        final fStr = row['fecha'];
        final mStr = row['monto'];
        if (fStr != null && mStr != null) {
          final dt = parseSupabaseTs(fStr.toString());
          if (_enPeriodo(dt)) {
            totalIngresos += double.tryParse(mStr.toString()) ?? 0;
          }
        }
      }

      // 2. OBTENER GASTOS
      double totalGastos = 0;
      try {
        final resGastos = await _supabase.from('gastos').select('fecha, monto');
        for (var row in resGastos) {
          final fStr = row['fecha'];
          final mStr = row['monto'];
          if (fStr != null && mStr != null) {
            final dt = parseSupabaseTs(fStr.toString());
            if (_enPeriodo(dt)) {
              totalGastos += double.tryParse(mStr.toString()) ?? 0;
            }
          }
        }
      } catch (_) {}

      // 3. TOP PRODUCTOS
      final topProdMap = <String, int>{};
      final vDetalle = await _supabase.from('ventas_detalle').select('id_venta, id_producto, cantidad');
      
      if (vDetalle.isNotEmpty) {
        final idVentas = vDetalle.map((v) => v['id_venta'] as int?).where((e) => e != null).toSet().toList();
        final idProds = vDetalle.map((v) => v['id_producto'] as int?).where((e) => e != null).toSet().toList();

        final vVentasDate = <int, DateTime>{};
        if (idVentas.isNotEmpty) {
          final resVentasTab = await _supabase.from('ventas').select('id_venta, fecha').inFilter('id_venta', idVentas);
          for (var row in resVentasTab) {
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

          if (_enPeriodo(fecha)) {
            final cant = int.tryParse(det['cantidad'].toString()) ?? 1;
            topProdMap.update(nombreProd, (val) => val + cant, ifAbsent: () => cant);
          }
        }
      }
      
      final topProdsList = topProdMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final top5 = topProdsList.take(5).map((e) => '- ${e.key}: ${e.value} unidades').join('\n');

      final utilidad = totalIngresos - totalGastos;
      final margen = totalIngresos > 0 ? (utilidad / totalIngresos) * 100 : 0.0;

      final titlePeriodo = _periodo == 'Día'
        ? DateFormat("EEEE, d 'de' MMMM 'de' y", 'es_MX').format(_base)
        : _periodo == 'Mes'
            ? DateFormat('MMMM y', 'es_MX').format(_base)
            : DateFormat('y', 'es_MX').format(_base);

      // 4. CONSTRUIR PROMPT
      final prompt = '''
Eres un consultor de negocios y financiero experto en pastelerías y panaderías ("Pastelería La Estrella").
A continuación, te presento el resumen financiero del periodo "$titlePeriodo".

- Ingresos Brutos: ${_fmtMon.format(totalIngresos)}
- Gastos Totales: ${_fmtMon.format(totalGastos)}
- Utilidad Neta (Caja Resultante): ${_fmtMon.format(utilidad)}
- Margen de Ganancia: ${margen.toStringAsFixed(1)}%

Top 5 Productos Más Vendidos:
${top5.isEmpty ? 'Sin ventas registradas en este periodo.' : top5}

Por favor, escribe un reporte ejecutivo, amigable y directo en Markdown.
Estructúralo de la siguiente manera:
1. **Resumen Ejecutivo**: Un párrafo corto sobre cómo estuvo el periodo.
2. **Análisis de Rentabilidad**: Comenta sobre los ingresos vs gastos y el margen. Si hay pérdidas o márgenes bajos, sé crítico pero constructivo.
3. **Desempeño de Productos**: Menciona cuáles son las estrellas del menú basado en el Top 5.
4. **Recomendaciones**: 2 estrategias clave para aumentar las ganancias el próximo periodo.

No uses saludos genéricos ni te presentes, ve directo al reporte. Usa formato markdown limpio, negritas y viñetas para que se vea estético.
''';

      // 5. LLAMAR A GEMINI
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey!,
      );

      final response = await model.generateContent([Content.text(prompt)]);
      
      if (mounted) {
        setState(() {
          _totalIngresosState = totalIngresos;
          _totalGastosState = totalGastos;
          _topProductosState = topProdsList;
          _reporte = response.text ?? 'No se pudo generar el reporte.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al comunicarse con la IA: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titlePeriodo = _periodo == 'Día'
        ? DateFormat("EEEE, d 'de' MMMM 'de' y", 'es_MX').format(_base)
        : _periodo == 'Mes'
            ? DateFormat('MMMM y', 'es_MX').format(_base)
            : DateFormat('y', 'es_MX').format(_base);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Asistente Financiero IA', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_apiKey != null)
            IconButton(
              icon: const Icon(Icons.key_off, color: Colors.red),
              onPressed: _borrarApiKey,
              tooltip: 'Borrar API Key',
            )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: PeriodoHeader(
            periodoValue: _periodo,
            onPeriodoChanged: (v) => setState(() {
              _periodo = v!;
              _reporte = '';
            }),
            onPrev: () => setState(() {
              if (_periodo == 'Día') {
                _base = _base.subtract(const Duration(days: 1));
              } else if (_periodo == 'Mes') {
                _base = DateTime(_base.year, _base.month - 1, _base.day);
              } else {
                _base = DateTime(_base.year - 1, _base.month, _base.day);
              }
              _reporte = '';
            }),
            onNext: () => setState(() {
              if (_periodo == 'Día') {
                _base = _base.add(const Duration(days: 1));
              } else if (_periodo == 'Mes') {
                _base = DateTime(_base.year, _base.month + 1, _base.day);
              } else {
                _base = DateTime(_base.year + 1, _base.month, _base.day);
              }
              _reporte = '';
            }),
            titlePeriodo: titlePeriodo,
          ),
        ),
      ),
      body: _apiKey == null ? _buildApiKeyConfig() : _buildIaContent(),
    );
  }

  Widget _buildApiKeyConfig() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 64, color: Color(0xFF8C5535)),
              const SizedBox(height: 16),
              const Text(
                'Configuración del Asistente IA',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Para generar reportes automáticos necesitamos conectarnos al cerebro de Google Gemini. Pega tu API Key a continuación para habilitar esta función.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _apiKeyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Gemini API Key',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.vpn_key),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8C5535),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _guardarApiKey,
                  child: const Text('Guardar y Habilitar IA', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fade(duration: 400.ms).scaleXY(begin: 0.95);
  }

  Widget _buildIaContent() {
    return Column(
      children: [
        if (_reporte.isEmpty && !_isLoading)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.analytics_outlined, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Reporte no generado', style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Presiona el botón para analizar los datos de este periodo.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8C5535),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    onPressed: _generarReporte,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generar Análisis', style: TextStyle(fontSize: 16)),
                  )
                ],
              ),
            ),
          ).animate().fade(duration: 400.ms),
        if (_isLoading)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF8C5535)),
                  SizedBox(height: 16),
                  Text('La IA está analizando tus finanzas...', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            ),
          ),
        if (_reporte.isNotEmpty && !_isLoading) ...[
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFFCF5EE),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF8C5535)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Reporte Generado por IA. Revisa las recomendaciones.',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF8C5535)),
                  ),
                ),
                OutlinedButton(
                  onPressed: _generarReporte,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8C5535),
                    side: const BorderSide(color: Color(0xFF8C5535)),
                  ),
                  child: const Text('Regenerar'),
                )
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PANEL IZQUIERDO: GRÁFICAS
                Expanded(
                  flex: 4,
                  child: Container(
                    margin: const EdgeInsets.only(left: 24, top: 24, bottom: 24, right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Resumen Visual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF8C5535))),
                          const SizedBox(height: 24),
                          // GRÁFICA DE DONA
                          const Text('Ingresos vs Gastos', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: [
                                  PieChartSectionData(
                                    color: Colors.green,
                                    value: _totalIngresosState,
                                    title: '${((_totalIngresosState / (_totalIngresosState + _totalGastosState == 0 ? 1 : _totalIngresosState + _totalGastosState)) * 100).toStringAsFixed(1)}%',
                                    radius: 50,
                                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  PieChartSectionData(
                                    color: Colors.redAccent,
                                    value: _totalGastosState,
                                    title: '${((_totalGastosState / (_totalIngresosState + _totalGastosState == 0 ? 1 : _totalIngresosState + _totalGastosState)) * 100).toStringAsFixed(1)}%',
                                    radius: 50,
                                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildLeyenda('Ingresos', Colors.green),
                              const SizedBox(width: 16),
                              _buildLeyenda('Gastos', Colors.redAccent),
                            ],
                          ),
                          const SizedBox(height: 40),
                          // GRÁFICA DE BARRAS
                          const Text('Top Productos (Unidades)', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 220,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: _topProductosState.isEmpty ? 10 : _topProductosState.first.value.toDouble() * 1.2,
                                barTouchData: BarTouchData(enabled: true),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (double value, TitleMeta meta) {
                                        if (value.toInt() >= _topProductosState.length) return const SizedBox();
                                        final name = _topProductosState[value.toInt()].key;
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            name.length > 8 ? '${name.substring(0, 8)}...' : name,
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        );
                                      },
                                      reservedSize: 40,
                                    ),
                                  ),
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                barGroups: List.generate(_topProductosState.take(5).length, (i) {
                                  return BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: _topProductosState[i].value.toDouble(),
                                        color: const Color(0xFF8C5535),
                                        width: 22,
                                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fade(duration: 400.ms).slideX(begin: -0.05),
                ),
                // PANEL DERECHO: TEXTO IA
                Expanded(
                  flex: 6,
                  child: Container(
                    margin: const EdgeInsets.only(top: 24, bottom: 24, right: 24, left: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Markdown(
                        data: _reporte,
                        styleSheet: MarkdownStyleSheet(
                          h1: const TextStyle(color: Color(0xFF8C5535), fontSize: 24, fontWeight: FontWeight.bold),
                          h2: const TextStyle(color: Color(0xFF8C5535), fontSize: 20, fontWeight: FontWeight.bold),
                          h3: const TextStyle(color: Color(0xFF8C5535), fontSize: 18, fontWeight: FontWeight.bold),
                          p: const TextStyle(fontSize: 15, height: 1.5),
                          listBullet: const TextStyle(color: Color(0xFF8C5535)),
                        ),
                      ),
                    ),
                  ).animate().fade(duration: 400.ms, delay: 150.ms).slideX(begin: 0.05),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLeyenda(String title, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
