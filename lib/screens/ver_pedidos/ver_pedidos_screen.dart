import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../servicios/supabase_client.dart';
import 'pedido_detalle_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

// =======================
//   MODELO REFINADO
// =======================
enum PedidoEstado { pendiente, hecho, entregado }

class PedidoEvent {
  final DateTime fechaHora;
  final String folio;
  final String cliente;
  final String telefono;
  final double restante;
  final PedidoEstado estado;

  PedidoEvent({
    required this.fechaHora,
    required this.folio,
    required this.cliente,
    required this.telefono,
    required this.restante,
    required this.estado,
  });
}

class VerPedidosScreen extends StatefulWidget {
  const VerPedidosScreen({super.key});

  @override
  State<VerPedidosScreen> createState() => _VerPedidosScreenState();
}

class _VerPedidosScreenState extends State<VerPedidosScreen> {
  List<PedidoEvent> _todos = [];
  bool _loading = true;
  
  // Estado de filtros / búsqueda
  String _filtroTipo = 'Todos';
  String _buscar = '';
  DateTime _mesActual = DateTime(DateTime.now().year, DateTime.now().month);
  
  // Selección para el Split View
  String? _selectedFolio;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // ---------- Data (Supabase) ----------
  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final inicioMes = DateTime(_mesActual.year, _mesActual.month, 1);
      final finMesSiguiente = DateTime(_mesActual.year, _mesActual.month + 2, 0); 

      final strInicio = inicioMes.toIso8601String().split('T')[0];
      final strFin = finMesSiguiente.toIso8601String().split('T')[0];

      var query = supabase.from('pedidos').select('''
        fecha_entrega,
        hora_entrega,
        folio,
        clientes(nombre, telefono),
        restante,
        estado
      ''')
      .gte('fecha_entrega', strInicio)
      .lte('fecha_entrega', strFin);

      if (_filtroTipo == 'Pendientes') {
        query = query.eq('estado', 'pendiente');
      } else if (_filtroTipo == 'Completados') {
        query = query.eq('estado', 'entregado');
      }

      final respuestaSupabase = await query.order('fecha_entrega', ascending: false);

      if (!mounted) return;

      final List<PedidoEvent> listaMapeada = (respuestaSupabase as List<dynamic>).map((fila) {
        final clienteMap = fila['clientes'] as Map<String, dynamic>?;
        final nombreCliente = clienteMap?['nombre']?.toString() ?? 'Cliente Mostrador';
        final telefonoCliente = clienteMap?['telefono']?.toString() ?? 'Sin teléfono';

        final fechaStr = fila['fecha_entrega']?.toString() ?? DateTime.now().toString().split(' ')[0];
        final horaStr = fila['hora_entrega']?.toString() ?? '00:00:00';
        final fechaHoraObjeto = DateTime.tryParse('$fechaStr $horaStr') ?? DateTime.now();

        PedidoEstado estadoEnum;
        switch (fila['estado']?.toString().toLowerCase()) {
          case 'entregado':
            estadoEnum = PedidoEstado.entregado;
            break;
          case 'hecho':
            estadoEnum = PedidoEstado.hecho;
            break;
          default:
            estadoEnum = PedidoEstado.pendiente;
        }

        return PedidoEvent(
          fechaHora: fechaHoraObjeto,
          folio: fila['folio']?.toString() ?? 'S/F',
          cliente: nombreCliente,
          telefono: telefonoCliente,
          restante: double.tryParse(fila['restante']?.toString() ?? '0') ?? 0.0,
          estado: estadoEnum,
        );
      }).toList();

      setState(() {
        _todos = listaMapeada;
        _loading = false;
        
        // Auto-seleccionar el primero si no hay selección y hay datos
        if (_selectedFolio == null && _todos.isNotEmpty) {
          _selectedFolio = _aplicarFiltrosYBusqueda(_todos).firstOrNull?.folio;
        }
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _todos = []; 
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar pedidos: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ========= Helpers de datos =========
  List<PedidoEvent> _aplicarFiltrosYBusqueda(List<PedidoEvent> base) {
    var list = [...base];

    if (_buscar.isNotEmpty) {
      final qUpper = _buscar.toUpperCase();
      final qLower = _buscar.toLowerCase();
      list = list.where((e) {
        final folioOk = e.folio.toUpperCase().contains(qUpper);
        final clienteOk = e.cliente.toLowerCase().contains(qLower);
        final telOk = e.telefono.contains(_buscar);
        return folioOk || clienteOk || telOk;
      }).toList();
    }

    if (_filtroTipo == 'Pendientes') {
      list = list.where((e) => e.estado == PedidoEstado.pendiente).toList();
    } else if (_filtroTipo == 'Completados') {
      list = list.where((e) => e.estado == PedidoEstado.entregado).toList();
    }

    list.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    return list;
  }

  Map<DateTime, List<PedidoEvent>> _agruparPorDia(List<PedidoEvent> eventos) {
    final map = <DateTime, List<PedidoEvent>>{};
    for (final e in eventos) {
      final key = DateTime(e.fechaHora.year, e.fechaHora.month, e.fechaHora.day);
      map.putIfAbsent(key, () => []).add(e);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Map.fromEntries(entries);
  }

  String _formatearFechaLarga(DateTime d) {
    const meses = [
      'enero','febrero','marzo','abril','mayo','junio',
      'julio','agosto','septiembre','octubre','noviembre','diciembre'
    ];
    const dias = ['lunes','martes','miércoles','jueves','viernes','sábado','domingo'];
    final dow = dias[(DateTime(d.year, d.month, d.day).weekday + 6) % 7];
    return '$dow, ${d.day} de ${meses[d.month - 1]} de ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final eventosFiltrados = _aplicarFiltrosYBusqueda(_todos);
    final eventosPorDia = _agruparPorDia(eventosFiltrados);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
        titleSpacing: 20,
        title: Row(
          children: [
            const Icon(Icons.list_alt_rounded, color: Color(0xFF8C5535)),
            const SizedBox(width: 12),
            const Text('Ver Pedidos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =======================
          // PANEL IZQUIERDO (Lista / Línea de Tiempo)
          // =======================
          Container(
            width: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                // Filtros y Buscador
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFFFCF5EE),
                  child: Column(
                    children: [
                      _MonthHeader(
                        month: _mesActual,
                        onPrev: () {
                          setState(() => _mesActual = DateTime(_mesActual.year, _mesActual.month - 1));
                          _cargar(); 
                        },
                        onNext: () {
                          setState(() => _mesActual = DateTime(_mesActual.year, _mesActual.month + 1));
                          _cargar(); 
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _FiltroDropdown<String>(
                              value: _filtroTipo,
                              items: const ['Todos', 'Pendientes', 'Completados'],
                              onChanged: (v) {
                                setState(() {
                                  _filtroTipo = v!;
                                  _selectedFolio = null; // reset selection
                                });
                                _cargar();
                              },
                              label: 'Estado',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 40,
                              child: TextField(
                                onChanged: (v) => setState(() => _buscar = v.trim()),
                                decoration: InputDecoration(
                                  hintText: 'Buscar...',
                                  prefixIcon: const Icon(Icons.search, size: 18),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.black87, width: 1.2)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                
                // Timeline List
                Expanded(
                  child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF8C5535)))
                  : eventosFiltrados.isEmpty
                      ? const Center(child: Text('No hay pedidos en este rango.', style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          physics: const BouncingScrollPhysics(),
                          itemCount: eventosPorDia.length,
                          itemBuilder: (context, index) {
                            final entry = eventosPorDia.entries.elementAt(index);
                            final fecha = entry.key;
                            final eventos = entry.value;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                Text(
                                  _formatearFechaLarga(fecha),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                  ...eventos.map((e) {
                                    int i = eventos.indexOf(e);
                                    return _TimelineTile(
                                      event: e,
                                      isSelected: e.folio == _selectedFolio,
                                      onTap: () => setState(() => _selectedFolio = e.folio),
                                    ).animate(key: ValueKey(e.folio))
                                     .fade(duration: 300.ms, delay: (20 * i).ms)
                                     .slideX(begin: -0.05, duration: 300.ms, delay: (20 * i).ms);
                                  }),
                                ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          
          // =======================
          // PANEL DERECHO (Detalle Premium)
          // =======================
          Expanded(
            child: _selectedFolio == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Selecciona un pedido', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                        const SizedBox(height: 8),
                        Text('Para ver todos sus detalles, pagos y cambiar el estado.', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                      ],
                    ),
                  )
                : PedidoDetalleScreen(
                    key: ValueKey(_selectedFolio), // Forza recarga del widget al cambiar folio
                    folio: _selectedFolio!,
                    onStatusChanged: _cargar, // Refresca la lista izquierda si el estado cambia
                  ).animate(key: ValueKey(_selectedFolio))
                   .fade(duration: 400.ms)
                   .slideY(begin: 0.05),
          ),
        ],
      ),
    );
  }
}

// =======================
//  WIDGETS DE PRESENTACIÓN
// =======================

class _FiltroDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final void Function(T?)? onChanged;
  final String label;

  const _FiltroDropdown({
    required this.value,
    required this.items,
    this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DropdownButton<T>(
          value: value,
          onChanged: onChanged,
          isDense: true,
          items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(e.toString(), style: const TextStyle(fontSize: 13)))).toList(),
          icon: const Icon(Icons.expand_more, size: 18),
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final PedidoEvent event;
  final bool isSelected;
  final VoidCallback onTap;

  const _TimelineTile({
    required this.event,
    required this.isSelected,
    required this.onTap,
  });

  (Color bg, Color fg, IconData icon, String texto) _estadoVisual(PedidoEstado e) {
    switch (e) {
      case PedidoEstado.entregado:
        return (const Color(0xFFE8F5E9), const Color(0xFF27AE60), Icons.check_circle_rounded, 'Entregado');
      case PedidoEstado.hecho:
        return (const Color(0xFFFFF8E1), const Color(0xFFE67E22), Icons.blender_rounded, 'En preparación');
      case PedidoEstado.pendiente:
      default:
        return (const Color(0xFFE3F2FD), const Color(0xFF2980B9), Icons.schedule_rounded, 'Pendiente');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hora = '${event.fechaHora.hour.toString().padLeft(2, '0')}:${event.fechaHora.minute.toString().padLeft(2, '0')}';
    final (stateBg, stateFg, stateIcon, textoEstado) = _estadoVisual(event.estado);
    final tieneRestante = event.restante > 0.01;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFCF5EE) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFF8C5535).withValues(alpha: 0.5) : const Color(0xFFEEEEEE),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Banda de color izquierda
                Container(
                  width: 4,
                  height: 72,
                  decoration: BoxDecoration(
                    color: stateFg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Hora
                SizedBox(
                  width: 44,
                  child: Text(hora, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
                // Contenido principal
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Folio + badge estado
                        Row(
                          children: [
                            Text(event.folio, style: TextStyle(color: isSelected ? const Color(0xFF8C5535) : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: stateBg, borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(stateIcon, color: stateFg, size: 10),
                                  const SizedBox(width: 4),
                                  Text(textoEstado, style: TextStyle(color: stateFg, fontSize: 9, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${event.cliente}  •  ${event.telefono}',
                          style: const TextStyle(color: Colors.black87, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (tieneRestante)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Pendiente: \$${event.restante.toStringAsFixed(2)}',
                              style: const TextStyle(color: Color(0xFFE67E22), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Flecha
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.chevron_right_rounded, color: isSelected ? const Color(0xFF8C5535) : Colors.grey.shade300, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    const meses = [
      'Enero','Febrero','Marzo','Abril','Mayo','Junio',
      'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
    ];
    final titulo = '${meses[month.month - 1]} ${month.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left, color: Colors.black87),
            visualDensity: VisualDensity.compact,
          ),
          Text(
            titulo,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, color: Colors.black87),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}