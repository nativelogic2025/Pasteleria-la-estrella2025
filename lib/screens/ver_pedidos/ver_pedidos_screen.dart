import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

// ⬇️ importa tu pantalla de consulta
import 'ver_pedido_consulta.dart';

// =======================
//   MODELO REFINADO
// =======================
enum PedidoEstado { pendiente, hecho, entregado }

class PedidoEvent {
  final DateTime fechaHora;
  final String folio;        // Folio visible y para búsqueda
  final String cliente;      // Nombre cliente
  final String telefono;     // ⬅️ NUEVO: para búsqueda
  final double restante;     // Falta por liquidar
  final PedidoEstado estado; // Estado

  PedidoEvent({
    required this.fechaHora,
    required this.folio,
    required this.cliente,
    required this.telefono,
    required this.restante,
    required this.estado,
  });

  PedidoEvent copyWith({
    DateTime? fechaHora,
    String? folio,
    String? cliente,
    String? telefono,
    double? restante,
    PedidoEstado? estado,
  }) {
    return PedidoEvent(
      fechaHora: fechaHora ?? this.fechaHora,
      folio: folio ?? this.folio,
      cliente: cliente ?? this.cliente,
      telefono: telefono ?? this.telefono,
      restante: restante ?? this.restante,
      estado: estado ?? this.estado,
    );
  }
}

class VerPedidosScreen extends StatefulWidget {
  const VerPedidosScreen({super.key});

  @override
  State<VerPedidosScreen> createState() => _VerPedidosScreenState();
}

class _VerPedidosScreenState extends State<VerPedidosScreen> {
  // Estado de filtros / búsqueda
  String _filtroTipo = 'Todos';
  String _buscar = ''; // ⬅️ ahora busca folio/cliente/teléfono
  DateTime _mesActual = DateTime(DateTime.now().year, DateTime.now().month);

  // Datos de ejemplo (ajusta a tu fuente real)
  final List<PedidoEvent> _todos = [
    PedidoEvent(
      fechaHora: DateTime(DateTime.now().year, DateTime.now().month, 21, 22, 0),
      folio: 'A-301',
      cliente: 'Implementación de Soluciones IoT',
      telefono: '771-123-4567',
      restante: 250.00,
      estado: PedidoEstado.hecho,
    ),
    PedidoEvent(
      fechaHora: DateTime(DateTime.now().year, DateTime.now().month, 8, 9, 30),
      folio: 'A-204',
      cliente: 'ACME S.A.',
      telefono: '771-555-1000',
      restante: 0.00,
      estado: PedidoEstado.entregado,
    ),
    PedidoEvent(
      fechaHora: DateTime(DateTime.now().year, DateTime.now().month, 10, 16, 0),
      folio: 'B-115',
      cliente: 'Proyecto: Almacén 3',
      telefono: '772-888-2222',
      restante: 120.00,
      estado: PedidoEstado.pendiente,
    ),
    PedidoEvent(
      fechaHora: DateTime(DateTime.now().year, DateTime.now().month, 3, 12, 15),
      folio: 'C-778',
      cliente: 'InnoTech',
      telefono: '771-000-7788',
      restante: 50.00,
      estado: PedidoEstado.pendiente,
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
                    _FiltroDropdown<String>(
                      value: _filtroTipo,
                      items: const ['Todos', 'Pendientes', 'Completados'],
                      onChanged: (v) => setState(() => _filtroTipo = v!),
                      label: 'Estado',
                    ),
                    SizedBox(
                      width: 340,
                      child: TextField(
                        onChanged: (v) => setState(() => _buscar = v.trim()),
                        decoration: InputDecoration(
                          hintText: 'Buscar por folio, cliente o teléfono',
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
                            onEditar: () => _abrirEditar(context, e),
                          )),
                    ],
                  );
                }),

                if (eventosPorDia.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No hay pedidos que coincidan con el filtro.',
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
                        backgroundColor: const Color(0xFF1A41FF),
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

    // 🔎 Búsqueda: folio (case-insensitive), cliente (case-insensitive), teléfono (tal cual)
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

    // Filtro por estado
    if (_filtroTipo == 'Pendientes') {
      list = list.where((e) => e.estado == PedidoEstado.pendiente).toList();
    } else if (_filtroTipo == 'Completados') {
      list = list.where((e) => e.estado == PedidoEstado.entregado).toList();
    }

    // Orden cronológico asc
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

  void _abrirEditar(BuildContext context, PedidoEvent e) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => EditarPedidoSheet(
        event: e,
        onGuardar: (nuevo) {
          // Aquí actualizarías tu fuente de datos real (PB/SQLite/etc.)
          final idx = _todos.indexWhere((x) => x.folio == e.folio);
          if (idx != -1) {
            setState(() => _todos[idx] = nuevo);
          }
          Navigator.pop(context);
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Pedido actualizado')));
        },
        onAbrirConsulta: () {
          Navigator.pop(context);
          // ⬇️ ahora abre la pantalla de consulta:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VerPedidoConsultaScreen()),
          );
        },
      ),
    );
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
  final VoidCallback onEditar;

  const _TimelineTile({
    required this.event,
    required this.onEditar,
  });

  (IconData icon, Color color, String texto) _estadoVisual(PedidoEstado e) {
    switch (e) {
      case PedidoEstado.entregado:
        return (Icons.check_circle, const Color(0xFF1DB954), 'Entregado');
      case PedidoEstado.hecho:
        return (Icons.check_circle, const Color(0xFFFFC107), 'Hecho');
      case PedidoEstado.pendiente:
      default:
        return (Icons.cancel, const Color(0xFFE53935), 'Pendiente');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hora =
        '${event.fechaHora.hour.toString().padLeft(2, '0')}:${event.fechaHora.minute.toString().padLeft(2, '0')}';
    final (iconData, color, textoEstado) = _estadoVisual(event.estado);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          // hora
          SizedBox(
            width: 52,
            child: Text(hora, style: const TextStyle(color: Colors.black87)),
          ),
          // icono de estado
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(iconData, size: 20, color: color),
          ),
          // contenido
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Folio “clickable”
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {},
                  child: Text(
                    'Folio: ${event.folio}',
                    style: const TextStyle(
                      color: Color(0xFF1A41FF),
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // Estado + cliente + restante + teléfono
                Text(
                  '$textoEstado · ${event.cliente} · Tel: ${event.telefono} · Restante: \$${event.restante.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onEditar,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              foregroundColor: Colors.black87,
            ),
            child: const Text('Editar'),
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

    final leadingEmpty = (firstWeekday + 6) % 7; // de 0..6
    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();

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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isToday ? Colors.black : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: isToday ? Colors.black : Colors.transparent,
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
                              const Positioned(
                                bottom: 10,
                                child: SizedBox(
                                  width: 6,
                                  height: 6,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Color(0xFF1A41FF),
                                      shape: BoxShape.circle,
                                    ),
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

// =======================
//  SHEET DE EDICIÓN
// =======================

class EditarPedidoSheet extends StatefulWidget {
  final PedidoEvent event;
  final void Function(PedidoEvent nuevo) onGuardar;
  final VoidCallback onAbrirConsulta; // ⬅️ cambia a consulta

  const EditarPedidoSheet({
    super.key,
    required this.event,
    required this.onGuardar,
    required this.onAbrirConsulta,
  });

  @override
  State<EditarPedidoSheet> createState() => _EditarPedidoSheetState();
}

class _EditarPedidoSheetState extends State<EditarPedidoSheet> {
  late TextEditingController _folioCtrl;
  late TextEditingController _clienteCtrl;
  late TextEditingController _telefonoCtrl; // ⬅️ NUEVO
  late TextEditingController _restanteCtrl;
  late PedidoEstado _estado;

  @override
  void initState() {
    super.initState();
    _folioCtrl = TextEditingController(text: widget.event.folio);
    _clienteCtrl = TextEditingController(text: widget.event.cliente);
    _telefonoCtrl = TextEditingController(text: widget.event.telefono); // ⬅️
    _restanteCtrl = TextEditingController(text: widget.event.restante.toStringAsFixed(2));
    _estado = widget.event.estado;
  }

  @override
  void dispose() {
    _folioCtrl.dispose();
    _clienteCtrl.dispose();
    _telefonoCtrl.dispose(); // ⬅️
    _restanteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Editar pedido', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              )),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _folioCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Folio',
                        filled: true,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<PedidoEstado>(
                      value: _estado,
                      items: const [
                        DropdownMenuItem(value: PedidoEstado.pendiente, child: Text('Pendiente')),
                        DropdownMenuItem(value: PedidoEstado.hecho, child: Text('Hecho')),
                        DropdownMenuItem(value: PedidoEstado.entregado, child: Text('Entregado')),
                      ],
                      onChanged: (v) => setState(() => _estado = v!),
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _clienteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cliente',
                  filled: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _telefonoCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  filled: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.call_outlined),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _restanteCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Restante',
                  filled: true,
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onAbrirConsulta,
                      child: const Text('Ver pedido (consulta)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final restante = double.tryParse(_restanteCtrl.text) ?? 0;
                        final nuevo = widget.event.copyWith(
                          folio: _folioCtrl.text.trim().toUpperCase(),
                          cliente: _clienteCtrl.text.trim(),
                          telefono: _telefonoCtrl.text.trim(),
                          restante: restante,
                          estado: _estado,
                        );
                        widget.onGuardar(nuevo);
                      },
                      child: const Text('Guardar cambios'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
