import 'package:flutter/material.dart';

class VerPedidosScreen extends StatefulWidget {
  const VerPedidosScreen({super.key});

  @override
  State<VerPedidosScreen> createState() => _VerPedidosScreenState();
}

// =======================
//   MODELO SIMPLE
// =======================
class PedidoEvent {
  final DateTime fechaHora;
  final String titulo;
  final String cursoOCliente; // o proyecto / cliente
  final bool pendiente; // para mostrar estado

  PedidoEvent({
    required this.fechaHora,
    required this.titulo,
    required this.cursoOCliente,
    this.pendiente = true,
  });
}

class _VerPedidosScreenState extends State<VerPedidosScreen> {
  // Estado de filtros / búsqueda
  String _filtroTipo = 'Todos';
  String _orden = 'Fecha (asc)';
  String _buscar = '';
  DateTime _mesActual = DateTime(DateTime.now().year, DateTime.now().month);

  // Datos de ejemplo
  final List<PedidoEvent> _todos = [
    PedidoEvent(
      fechaHora: DateTime(DateTime.now().year, DateTime.now().month, 21, 22, 0),
      titulo: 'Evidencia de movimientos del carro - batman',
      cursoOCliente: 'Implementación de Soluciones IoT',
      pendiente: true,
    ),
    PedidoEvent(
      fechaHora: DateTime(DateTime.now().year, DateTime.now().month, 8, 9, 30),
      titulo: 'Entrega de pedido #A-204',
      cursoOCliente: 'Cliente: ACME S.A.',
      pendiente: false,
    ),
    PedidoEvent(
      fechaHora: DateTime(DateTime.now().year, DateTime.now().month, 10, 16, 0),
      titulo: 'Instalación de sensores',
      cursoOCliente: 'Proyecto: Almacén 3',
      pendiente: true,
    ),
    PedidoEvent(
      fechaHora: DateTime(DateTime.now().year, DateTime.now().month, 3, 12, 15),
      titulo: 'Revisión factura #778',
      cursoOCliente: 'Cliente: InnoTech',
      pendiente: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final eventosFiltrados = _aplicarFiltrosYBusqueda(_todos);
    final eventosPorDia = _agruparPorDia(eventosFiltrados);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ver Pedidos'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // =======================
          // LÍNEA DE TIEMPO
          // =======================
          _CardWrap(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filtros de la cabecera
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FiltroDropdown<String>(
                          value: _filtroTipo,
                          items: const ['Todos', 'Pendientes', 'Completados'],
                          onChanged: (v) => setState(() => _filtroTipo = v!),
                          label: 'Todos',
                        ),
                        const SizedBox(width: 8),
                        _FiltroDropdown<String>(
                          value: _orden,
                          items: const ['Fecha (asc)', 'Fecha (desc)'],
                          onChanged: (v) => setState(() => _orden = v!),
                          label: 'Ordenar por fechas',
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 340,
                      child: TextField(
                        onChanged: (v) => setState(() => _buscar = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre o tipo de actividad',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF6F6F6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.black87, width: 1.2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),

                // Lista agrupada por fecha
                ...eventosPorDia.entries.map((entry) {
                  final fecha = entry.key;
                  final eventos = entry.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        _formatearFechaLarga(fecha),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...eventos.map((e) => _TimelineTile(
                            event: e,
                            onAddEnvio: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Acción: Añadir envío')),
                              );
                            },
                          )),
                    ],
                  );
                }),

                if (eventosPorDia.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No hay actividades que coincidan con el filtro.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // =======================
          // CALENDARIO
          // =======================
          _CardWrap(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      'Calendario',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    _FiltroDropdown<String>(
                      value: 'Todos los pedidos',
                      items: const ['Todos los pedidos'],
                      onChanged: (_) {},
                      label: 'Todos los pedidos',
                      dense: true,
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Acción: Nuevo evento')),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1A41FF), // azul como la imagen
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Nuevo evento'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _MonthHeader(
                  month: _mesActual,
                  onPrev: () => setState(() {
                    _mesActual = DateTime(_mesActual.year, _mesActual.month - 1);
                  }),
                  onNext: () => setState(() {
                    _mesActual = DateTime(_mesActual.year, _mesActual.month + 1);
                  }),
                ),
                const SizedBox(height: 8),
                _CalendarGrid(
                  month: _mesActual,
                  events: _todos,
                  onTapDay: (day) {
                    // cuando toques un día, podrías navegar o filtrar
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========= Helpers de datos =========
  List<PedidoEvent> _aplicarFiltrosYBusqueda(List<PedidoEvent> base) {
    var list = [...base];

    // Búsqueda
    if (_buscar.isNotEmpty) {
      list = list
          .where((e) =>
              e.titulo.toLowerCase().contains(_buscar) ||
              e.cursoOCliente.toLowerCase().contains(_buscar))
          .toList();
    }

    // Filtro por estado
    if (_filtroTipo == 'Pendientes') {
      list = list.where((e) => e.pendiente).toList();
    } else if (_filtroTipo == 'Completados') {
      list = list.where((e) => !e.pendiente).toList();
    }

    // Orden
    list.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    if (_orden == 'Fecha (desc)') list = list.reversed.toList();

    return list;
  }

  Map<DateTime, List<PedidoEvent>> _agruparPorDia(List<PedidoEvent> eventos) {
    final map = <DateTime, List<PedidoEvent>>{};
    for (final e in eventos) {
      final key = DateTime(e.fechaHora.year, e.fechaHora.month, e.fechaHora.day);
      map.putIfAbsent(key, () => []).add(e);
    }
    // Orden por fecha
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
    // ej: martes, 21 de octubre de 2025
  }
}

// =======================
//  WIDGETS DE PRESENTACIÓN
// =======================

class _CardWrap extends StatelessWidget {
  final Widget child;
  const _CardWrap({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFEDEDED)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }
}

class _FiltroDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final void Function(T?)? onChanged;
  final String label;
  final bool dense;

  const _FiltroDropdown({
    required this.value,
    required this.items,
    this.onChanged,
    required this.label,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE6E6E6)),
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFFF6F6F6),
        ),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: dense ? 4 : 8),
        child: DropdownButton<T>(
          value: value,
          onChanged: onChanged,
          isDense: dense,
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(e.toString()),
                ),
              )
              .toList(),
          icon: const Icon(Icons.expand_more),
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final PedidoEvent event;
  final VoidCallback onAddEnvio;

  const _TimelineTile({
    required this.event,
    required this.onAddEnvio,
  });

  @override
  Widget build(BuildContext context) {
    final hora = '${event.fechaHora.hour.toString().padLeft(2, '0')}:${event.fechaHora.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          // hora
          SizedBox(
            width: 52,
            child: Text(
              hora,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
          // icono pequeño
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.assignment_turned_in_outlined, size: 20, color: Colors.black54),
          ),
          // contenido
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    // Accion: abrir detalle del pedido
                  },
                  child: Text(
                    event.titulo,
                    style: const TextStyle(
                      color: Color(0xFF1A41FF),
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${event.pendiente ? "Tarea está en fecha de entrega" : "Completado"} · ${event.cursoOCliente}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onAddEnvio,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              foregroundColor: Colors.black87,
            ),
            child: const Text('Añadir envío'),
          ),
        ],
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
      'enero','febrero','marzo','abril','mayo','junio',
      'julio','agosto','septiembre','octubre','noviembre','diciembre'
    ];
    final titulo = '${meses[month.month - 1]} ${month.year}';

    return Row(
      children: [
        TextButton.icon(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
          label: const Text('septiembre'),
          style: TextButton.styleFrom(foregroundColor: Colors.black54),
        ),
        Expanded(
          child: Center(
            child: Text(
              titulo,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onNext,
          label: const Icon(Icons.chevron_right),
          icon: const Text('noviembre'),
          style: TextButton.styleFrom(foregroundColor: Colors.black54),
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month; // primer día del mes
  final List<PedidoEvent> events;
  final void Function(DateTime day) onTapDay;

  const _CalendarGrid({
    required this.month,
    required this.events,
    required this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final firstWeekday = firstOfMonth.weekday; // 1=lunes .. 7=domingo
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // Empezamos desde lunes
    final leadingEmpty = (firstWeekday + 6) % 7; // de 0..6

    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();

    // Días que tienen eventos
    final Set<int> daysWithEvents = events
        .where((e) => e.fechaHora.month == month.month && e.fechaHora.year == month.year)
        .map((e) => e.fechaHora.day)
        .toSet();

    final today = DateTime.now();

    final headers = const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return Column(
      children: [
        // cabecera de días
        Row(
          children: headers
              .map((h) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Center(
                          child: Text(h,
                              style: const TextStyle(
                                  color: Colors.black54, fontWeight: FontWeight.w600))),
                    ),
                  ))
              .toList(),
        ),
        // grilla
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEDEDED)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: List.generate(rows, (r) {
              return Row(
                children: List.generate(7, (c) {
                  final index = r * 7 + c;
                  final dayNumber = index - leadingEmpty + 1;
                  final inMonth = dayNumber >= 1 && dayNumber <= daysInMonth;
                  final date = DateTime(month.year, month.month, inMonth ? dayNumber : 1);

                  final isToday = inMonth &&
                      date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;

                  final hasEvent = inMonth && daysWithEvents.contains(dayNumber);

                  return Expanded(
                    child: InkWell(
                      onTap: inMonth ? () => onTapDay(date) : null,
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Colors.grey.shade200),
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                          color: Colors.white,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isToday ? Colors.black : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color:
                                        isToday ? Colors.black : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  inMonth ? '$dayNumber' : '',
                                  style: TextStyle(
                                    color: isToday ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            if (hasEvent)
                              Positioned(
                                bottom: 10,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1A41FF),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ),
      ],
    );
  }
}
