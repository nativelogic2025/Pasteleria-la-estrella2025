import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../servicios/supabase_client.dart';

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
  List<PedidoEvent> _todos = [];
  bool _loading = true;
  // Estado de filtros / búsqueda
  String _filtroTipo = 'Todos';
  String _buscar = ''; // ⬅️ ahora busca folio/cliente/teléfono
  DateTime _mesActual = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _diaSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  // ---------- Data (Supabase) ----------
  // 1. Cargar productos de la categoría
  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // Usamos _mesActual (la variable que cambia cuando tocas las flechas)
      final inicioMes = DateTime(_mesActual.year, _mesActual.month, 1);
      final finMesSiguiente = DateTime(_mesActual.year, _mesActual.month + 2, 0); 

      // Convertimos a formato SQL (YYYY-MM-DD)
      final strInicio = inicioMes.toIso8601String().split('T')[0];
      final strFin = finMesSiguiente.toIso8601String().split('T')[0];

      // 1. Preparamos la consulta base (sin el filtro de estado todavía)
      var query = supabase.from('pedidos').select('''
        fecha_entrega,
        hora_entrega,
        folio,
        clientes(nombre, telefono),
        restante,
        estado
      ''')
      // 👇 AGREGA ESTOS DOS FILTROS DE RANGO DE FECHA
      .gte('fecha_entrega', strInicio) // gte = Greater Than or Equal (Mayor o igual a)
      .lte('fecha_entrega', strFin);   // lte = Less Than or Equal (Menor o igual a)

      // 2. Aplicamos el filtro de estado SOLO si no es "Todos"
      if (_filtroTipo == 'Pendientes') {
        query = query.eq('estado', 'pendiente');
      } else if (_filtroTipo == 'Completados') {
        query = query.eq('estado', 'entregado');
      } 
      // Si es "Todos", simplemente no agregamos el .eq() y traerá toda la tabla.

      // 3. Ejecutamos la consulta ordenando por fecha
      final respuestaSupabase = await query.order('fecha_entrega', ascending: false);

      if (!mounted) return;

      // 4. MAPEO DE DATOS: Convertimos los Mapas crudos a objetos PedidoEvent
      final List<PedidoEvent> listaMapeada = (respuestaSupabase as List<dynamic>).map((fila) {
        
        // A) Manejo de relaciones (Join de clientes):
        // Supabase devuelve los joins como un mapa anidado.
        final clienteMap = fila['clientes'] as Map<String, dynamic>?;
        final nombreCliente = clienteMap?['nombre']?.toString() ?? 'Cliente Mostrador';
        final telefonoCliente = clienteMap?['telefono']?.toString() ?? 'Sin teléfono';

        // B) Fusión de Fecha y Hora:
        // Concatenamos "YYYY-MM-DD" con "HH:MM:SS" para crear un solo DateTime
        final fechaStr = fila['fecha_entrega']?.toString() ?? DateTime.now().toString().split(' ')[0];
        final horaStr = fila['hora_entrega']?.toString() ?? '00:00:00';
        final fechaHoraObjeto = DateTime.tryParse('$fechaStr $horaStr') ?? DateTime.now();

        // C) Mapeo del Enum de estado:
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

        // D) Construimos y retornamos el objeto final
        return PedidoEvent(
          fechaHora: fechaHoraObjeto,
          folio: fila['folio']?.toString() ?? 'S/F',
          cliente: nombreCliente,
          telefono: telefonoCliente,
          restante: double.tryParse(fila['restante']?.toString() ?? '0') ?? 0.0,
          estado: estadoEnum,
        );
        
      }).toList(); // 👈 El .toList() es vital para convertir el Iterable a una Lista real

      setState(() {
        _todos = listaMapeada; // 👈 Ahora _todos recibe puros PedidoEvent reales
        _loading = false;
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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            // =======================
            // LÍNEA DE TIEMPO
            // =======================
            Expanded( // ⬅️ 3. Obligamos a esta tarjeta a tomar el espacio libre superior
              child: _CardWrap(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      // 1. Esto alinea los elementos verticalmente por el centro
                      crossAxisAlignment: WrapCrossAlignment.center, 
                      runSpacing: 8,
                      children: [
                        // 2. Le damos una altura fija al Dropdown
                        SizedBox(
                          height: 48, 
                          child: _FiltroDropdown<String>(
                            value: _filtroTipo,
                            items: const ['Todos', 'Pendientes', 'Completados'],
                            onChanged: (v) => setState(() => _filtroTipo = v!),
                            label: 'Estado',
                          ),
                        ),
                        SizedBox(width: 8),                    
                        // 3. Le damos la MISMA altura fija al TextField
                        SizedBox(
                          width: 340,
                          height: 48, 
                          child: TextField(
                            onChanged: (v) => setState(() => _buscar = v.trim()),
                            // 4. Centramos el texto verticalmente para que no se pegue arriba
                            textAlignVertical: TextAlignVertical.center, 
                            decoration: InputDecoration(
                              hintText: 'Buscar por folio, cliente o teléfono',
                              prefixIcon: const Icon(Icons.search),
                              // 5. Ajustamos el padding interno para respetar la altura de 48px
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

                    Expanded(
                      child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                          onRecargar: _cargar,
                                        )),
                                  ],
                                );
                              }),

                              if (eventosPorDia.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'No hay pedidos para este mes.',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ),
                  ],
                ),
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
                      /*const Spacer(),
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
                      ),*/
                    ],
                  ),
                  const SizedBox(height: 8),
                  _MonthHeader(
                    month: _mesActual,
                    onPrev: () {
                      setState(() {
                        _mesActual = DateTime(_mesActual.year, _mesActual.month - 1);
                        _diaSeleccionado = null;
                      });
                      // 👇 Obligamos a Supabase a traer los datos del nuevo mes
                      _cargar(); 
                    },
                    onNext: () {
                      setState(() {
                        _mesActual = DateTime(_mesActual.year, _mesActual.month + 1);
                        _diaSeleccionado = null;
                      });
                      // 👇 Obligamos a Supabase a traer los datos del nuevo mes
                      _cargar(); 
                    },
                  ),
                  const SizedBox(height: 8),
                  _CalendarGrid(
                    month: _mesActual,
                    events: eventosFiltrados,
                    selectedDay: _diaSeleccionado,
                    onTapDay: (day) {
                      setState(() {
                        // Si el usuario toca el MISMO día que ya estaba seleccionado, apagamos el filtro
                        if (_diaSeleccionado != null &&
                            _diaSeleccionado!.year == day.year &&
                            _diaSeleccionado!.month == day.month &&
                            _diaSeleccionado!.day == day.day) {
                          _diaSeleccionado = null;
                        } else {
                          // Si toca un día diferente, lo seleccionamos
                          _diaSeleccionado = day;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
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

    // Filtro por día seleccionado en el calendario
    if (_diaSeleccionado != null) {
      list = list.where((e) {
        return e.fechaHora.year == _diaSeleccionado!.year &&
              e.fechaHora.month == _diaSeleccionado!.month &&
              e.fechaHora.day == _diaSeleccionado!.day;
      }).toList();
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
        onGuardar: (nuevo) async {
          try {
            // 1. Mapeo limpio y seguro del Enum usando switch
            String est;
            switch (nuevo.estado) {
              case PedidoEstado.pendiente:
                est = 'pendiente';
                break;
              case PedidoEstado.hecho:
                est = 'hecho';
                break;
              case PedidoEstado.entregado:
                est = 'entregado';
                break;
            }

            // 2. Primer UPDATE: Pedido
            final resp = await supabase.from('pedidos').update({
              'estado': est,
              'restante': nuevo.restante.toString(), // Asegúrate de que tu BD acepta texto aquí, o quita el .toString() si es numérico (double)
            }).eq('folio', e.folio).select().single(); 

            // 3. Segundo UPDATE: Cliente
            await supabase.from('clientes').update({
              'nombre': nuevo.cliente,
              'telefono': nuevo.telefono,
            }).eq('id_cliente', resp['id_cliente']);

            // 4. Actualización Visual (Solo ocurre si la BD no arrojó errores)
            final idx = _todos.indexWhere((x) => x.folio == e.folio);
            if (idx != -1) {
              setState(() => _todos[idx] = nuevo);
            }
            
            // 5. Cierre y Éxito
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pedido actualizado'), 
                backgroundColor: Colors.green, // Un toque de color para el éxito
              )
            );

          } catch (err) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al guardar: $err'), 
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        onAbrirConsulta: () async {
          Navigator.pop(context);
          // ⬇️ ahora abre la pantalla de consulta:
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => 
              VerPedidoConsultaScreen(
                folio: e.folio
              )
            ),
          );

          _cargar();
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
  final VoidCallback onRecargar;
  final PedidoEvent event;
  final VoidCallback onEditar;

  const _TimelineTile({
    required this.event,
    required this.onEditar,
    required this.onRecargar,
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
                  onTap: () async {
                    // Abrir pantalla de consulta para este pedido
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => 
                        VerPedidoConsultaScreen(
                          folio: event.folio
                        )
                      ),
                    );

                    onRecargar();
                  },
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
  final DateTime? selectedDay;

  const _CalendarGrid({
    required this.month,
    required this.events,
    required this.onTapDay,
    this.selectedDay,
  });

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final firstWeekday = firstOfMonth.weekday; // 1=lunes .. 7=domingo
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final leadingEmpty = (firstWeekday + 6) % 7; // de 0..6
    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final Map<int, List<PedidoEvent>> eventosDelMes = {};
    for (final e in events) {
      if (e.fechaHora.month == month.month && e.fechaHora.year == month.year) {
        eventosDelMes.putIfAbsent(e.fechaHora.day, () => []).add(e);
      }
    }

    final today = DateTime.now();
    final headers = const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    Color getColorPorEstado(PedidoEstado estado) {
      switch (estado) {
        case PedidoEstado.entregado: return const Color(0xFF1DB954); // Verde
        case PedidoEstado.hecho: return const Color(0xFFFFC107);     // Amarillo
        case PedidoEstado.pendiente: return const Color(0xFFE53935); // Rojo
      }
    }

    return Column(
      children: [
        // cabecera de días
        Row(
          children: headers
              .map((h) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
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

                  final isSelected = selectedDay != null &&
                    date.year == selectedDay!.year &&
                    date.month == selectedDay!.month &&
                    date.day == selectedDay!.day;

                  final eventosDelDia = inMonth ? (eventosDelMes[dayNumber] ?? []) : [];

                  final eventosVisuales = List<PedidoEvent>.from(eventosDelDia);
                  eventosVisuales.sort((a, b) {
                    // Le damos un "peso" a cada estado (Menor número = Mayor prioridad visual)
                    int prioridad(PedidoEstado estado) {
                      switch (estado) {
                        case PedidoEstado.pendiente: return 1; // 🔴 Máxima prioridad
                        case PedidoEstado.hecho: return 2;     // 🟡 Media prioridad
                        case PedidoEstado.entregado: return 3; // 🟢 Baja prioridad
                      }
                    }
                    return prioridad(a.estado).compareTo(prioridad(b.estado));
                  });

                  return Expanded(
                    child: InkWell(
                      onTap: inMonth ? () => onTapDay(date) : null,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Colors.grey.shade200),
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                          color: isSelected ? const Color(0xFFE8EAF6) : Colors.white,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: 4,
                              right: 4,
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
                            if (eventosVisuales.isNotEmpty)
                              Positioned(
                                bottom: 4,
                                child: Wrap(
                                  spacing: 2, // Espacio entre cada puntito
                                  alignment: WrapAlignment.center,
                                  // Usamos .take(4) para evitar que si hay 20 pedidos se desborde la celda.
                                  // Máximo mostrará 4 puntitos visualmente.
                                  children: eventosVisuales.take(4).map((e) {
                                    return Container(
                                      width: 5, // Un poco más pequeños para que quepan varios
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: getColorPorEstado(e.estado),
                                        shape: BoxShape.circle,
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
                      readOnly: true,
                      decoration: const InputDecoration(
                        fillColor: Color.fromARGB(0, 145, 145, 211),
                        labelText: 'Folio (No editable)',
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
                readOnly: true,
                decoration: const InputDecoration(
                  fillColor: Color.fromARGB(0, 145, 145, 211),
                  labelText: 'Cliente (No editable)',
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