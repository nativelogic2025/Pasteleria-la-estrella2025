// ver_pedido_consulta.dart
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

import '../servicios/supabase_client.dart';

/// Mantén el mismo enum que usas en VerPedidosScreen
enum PedidoEstado { pendiente, hecho, entregado }

class VerPedidoConsultaScreen extends StatefulWidget {
  // Opcional: datos de entrada para precargar la vista
  final String folio;

  const VerPedidoConsultaScreen({
    super.key,
    required this.folio,
  });

  @override
  State<VerPedidoConsultaScreen> createState() => _VerPedidoConsultaScreenState();
}

class _VerPedidoConsultaScreenState extends State<VerPedidoConsultaScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores 
  final _telefonoCtrl = TextEditingController();
  final _domicilioCtrl = TextEditingController();
  final _otrosCargosCtrl = TextEditingController();
  final _fleteCtrl = TextEditingController();
  final _ajusteCtrl = TextEditingController();

  Map<String, dynamic> _items = {};
  bool _loading = true;

  PedidoEstado _estado = PedidoEstado.pendiente;
  String _folio = '';
  String _cliente = '';
  String _producto = '';
  String _tipo_pan = '';
  String _tamano = '';
  String _pisos = '';
  String _doble = '';
  String _diseno = '';
  String _mensaje = '';
  String _notas = '';
  DateTime? _fechaEntrega;
  TimeOfDay? _horaEntrega;
  double _subtotal = 0;
  double _anticipo = 0;

  // Totales calculados “actuales”
  double _totalActual = 0;
  double _restanteActual = 0;

  // Sección NUEVA: actualización de precio (ajuste)
  double _totalNuevo = 0;
  double _restanteNuevo = 0;

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
      // Supabase devuelve directamente una List<Map<String, dynamic>>
      final Map<String, dynamic> res = await supabase
          .from('pedidos')
          .select('''
            *, clientes(*), detalle_pedido(*, producto_variantes(*, productos(*, categorias(nombre))))
          ''')
          .eq('folio', widget.folio ?? '')
          //.order('id_pedido', ascending: true);
          .single();

      if (!mounted) return;
      setState(() {
        _items = res; // Guardamos la lista de mapas directamente
        _inicializarVariables();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = {}; // Limpiamos la lista en caso de error
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar ${widget.folio}: $e')),
      );
    }
  }

  void _inicializarVariables() {
    _folio = widget.folio ?? '';
    _cliente = _items['clientes']['nombre'];
    _producto = _items['detalle_pedido'][0]['producto_variantes']['productos']['nombre'];
    _tipo_pan = _items['detalle_pedido'][0]['sabor'];
    _tamano = _items['detalle_pedido'][0]['producto_variantes']['tamaño'];
    _pisos = _items['detalle_pedido'][0]['pisos'];
    _doble = _items['detalle_pedido'][0]['armado'];
    _diseno = _items['detalle_pedido'][0]['diseño'];
    _mensaje = _items['detalle_pedido'][0]['dedicatoria'];
    _notas = _items['detalle_pedido'][0]['observaciones'];
    _subtotal = _items['subtotal'];
    _anticipo = _items['anticipo'];
    _totalActual = _items['total'];
    _restanteActual = _items['restante'];

    _telefonoCtrl.text = _items['clientes']['telefono']?.toString() ?? '';
    _domicilioCtrl.text = _items['clientes']['direccion']?.toString() ?? '';
    
    // Si tienes estos campos en BD, los cargas; si no, inician en '0'
    _otrosCargosCtrl.text = _items['descuento']?.toString() ?? '0';
    _fleteCtrl.text = _items['flete']?.toString() ?? '0';
    _ajusteCtrl.text = '0'; // El ajuste siempre inicia en 0 al abrir la consulta

    // Inicializamos los nuevos totales iguales a los actuales para empezar
    _totalNuevo = _totalActual;
    _restanteNuevo = _restanteActual;

    // 1. Nos aseguramos de convertirlos a String de forma segura
    final String fechaStr = _items['fecha_entrega']?.toString() ?? '';
    final String horaStr = _items['hora_entrega']?.toString() ?? '00:00:00';

    // 2. Unimos los textos ("2026-04-15 14:30:00") y tratamos de parsearlo
    final DateTime fechaHoraCompleta = DateTime.tryParse('$fechaStr $horaStr') ?? DateTime.now();

    // 3. ¡Asignamos los valores limpios!
    _fechaEntrega = fechaHoraCompleta; // DateTime toma la fecha completa
    _horaEntrega = TimeOfDay.fromDateTime(fechaHoraCompleta); // Extrae solo la hora y minuto

    String est = _items['estado'].toString().toLowerCase();
    switch (est) {
      case 'entregado':
        _estado = PedidoEstado.entregado;
        break;
      case 'hecho':
        _estado = PedidoEstado.hecho;
        break;
      case 'pendiente':
      default: // El default es vital: si la BD devuelve algo raro, no explota la app
        _estado = PedidoEstado.pendiente;
        break;
    }
  }

  // 👇 2. FUNCIÓN PARA RECALCULAR LOS TOTALES DINÁMICAMENTE
  void _calcularNuevosTotales() {
    setState(() {
      // Extraemos el valor escrito, si escriben basura o está vacío, tomamos 0
      final ajuste = double.tryParse(_ajusteCtrl.text) ?? 0.0;
      final otrosCargos = _items['descuento'] ?? 0.0;
      final flete = _items['flete'] ?? 0.0;
      final otrosCargosNew = double.tryParse(_otrosCargosCtrl.text) ?? 0.0;
      final fleteNew = double.tryParse(_fleteCtrl.text) ?? 0.0;

      // Ajustamos los valores actuales restando los valores originales
      _totalNuevo = _totalActual + otrosCargosNew - otrosCargos + fleteNew - flete;

      _restanteNuevo = _restanteActual - ajuste;
    });
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaEntrega ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (fecha != null) setState(() => _fechaEntrega = fecha);
  }

  Future<void> _seleccionarHora(BuildContext context) async {
    final hora = await showTimePicker(
      context: context,
      initialTime: _horaEntrega ?? TimeOfDay.now(),
    );
    if (hora != null) setState(() => _horaEntrega = hora);
  }

  @override
  void dispose() {
    _telefonoCtrl.dispose();
    _domicilioCtrl.dispose();
    _otrosCargosCtrl.dispose();
    _fleteCtrl.dispose();
    _ajusteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFAFAFA);
    final divider = DividerThemeData(
      thickness: 1, space: 24, color: Colors.grey.shade200,
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: Colors.black,
        title: Text('Consulta del pedido — $_folio'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerTheme: divider,
                inputDecorationTheme: InputDecorationTheme(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black87, width: 1.2),
                  ),
                  labelStyle: TextStyle(color: Colors.grey.shade700),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              child: Form(
                key: _formKey,
                child:_loading 
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  :  ListView(
                  children: [
                    _HeaderCard(
                      title: 'Consulta de Pedido',
                      subtitle: 'Revisa los datos. El nombre está bloqueado. '
                                'Puedes actualizar precios y estado del pedido.',
                    ),

                    const SizedBox(height: 16),

                    // ========== Cliente (nombre bloqueado) ==========
                    _SectionCard(
                      title: 'Cliente',
                      children: [
                        _ReadOnlyTile(icon: Icons.person_outline, label: 'Cliente', value: _cliente),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telefonoCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            prefixIcon: Icon(Icons.call_outlined),
                          ),
                          validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                      ],
                    ),

                    // ========== Datos de entrega (solo lectura) ==========
                    _SectionCard(
                      title: 'Datos de entrega',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: _fechaEntrega != null
                                      ? 'Fecha: ${_fechaEntrega!.day}/${_fechaEntrega!.month}/${_fechaEntrega!.year}'
                                      : 'Seleccionar Fecha *',
                                  prefixIcon: const Icon(Icons.event_outlined),
                                  suffixIcon: IconButton(
                                    tooltip: 'Elegir fecha',
                                    onPressed: () => _seleccionarFecha(context),
                                    icon: const Icon(Icons.edit_calendar_outlined),
                                  ),
                                ),
                                validator: (_) =>
                                    _fechaEntrega == null ? 'Requerido' : null,
                                onTap: () => _seleccionarFecha(context),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: _horaEntrega != null
                                      ? 'Hora: ${_horaEntrega!.format(context)}'
                                      : 'Seleccionar Hora *',
                                  prefixIcon: const Icon(Icons.schedule_outlined),
                                  suffixIcon: IconButton(
                                    tooltip: 'Elegir hora',
                                    onPressed: () => _seleccionarHora(context),
                                    icon: const Icon(Icons.access_time),
                                  ),
                                ),
                                validator: (_) =>
                                    _horaEntrega == null ? 'Requerido' : null,
                                onTap: () => _seleccionarHora(context),
                              ),
                            ),
                          ],
                        ),
                        if(_items['tipo_entrega'].toString() == 'domicilio')
                        ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _domicilioCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Domicilio',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                          validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                        ],
                        if(_items['tipo_entrega'].toString() != 'domicilio')
                        ...[
                        const SizedBox(height: 12),
                        _ReadOnlyTile(icon: Icons.location_on_outlined, label: 'Entrega en', value: 'ESTÁ SUCURSAL'),
                        ]
                      ],
                    ),

                    // ========== Producto (solo lectura) ==========
                    _SectionCard(
                      title: 'Producto',
                      children: [
                        _ReadOnlyTile(icon: Icons.cake_outlined, label: 'Producto', value: _producto),
                        if(_tipo_pan.isNotEmpty)
                          _ReadOnlyTile(icon: Icons.straighten_outlined, label: 'Tipo de Pan', value: _tipo_pan),
                        _ReadOnlyTile(icon: Icons.straighten_outlined, label: 'Tamaño', value: _tamano),
                        
                      ],
                    ),

                    // ========== Diseño (solo lectura) ==========
                    _SectionCard(
                      title: 'Diseño del pastel',
                      children: [
                        if(_items['detalle_pedido']?[0]?['producto_variantes']?['productos']?['categorias']?['nombre']?.toString() == 'Pasteles')
                        ...[
                          Row(
                            children: [
                              Expanded(child: _ReadOnlyTile(icon: Icons.layers_outlined, label: 'Pisos', value: _pisos)),
                              const SizedBox(width: 12),
                              Expanded(child: _ReadOnlyTile(icon: Icons.toggle_on_outlined, label: 'Tipo', value: _doble)),
                            ],
                          ),
                          _ReadOnlyTile(icon: Icons.cake_outlined, label: 'Diseño', value: _diseno),
                        ],
                        if (_mensaje.isNotEmpty)
                          _ReadOnlyTile(icon: Icons.edit_note_outlined, label: 'Mensaje', value: _mensaje),
                        _ReadOnlyTile(icon: Icons.list, label: 'Notas', value: _notas),
                      ],
                      
                    ),

                    // ========== Precio (igual que en el formulario) ==========
                    _SectionCard(
                      title: 'Precio del pastel (actual)',
                      children: [
                        _ReadOnlyTile(icon: Icons.money, label: 'Subtotal', value: _subtotal.toString()),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _otrosCargosCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Otros cargos',
                            prefixIcon: Icon(Icons.attach_money_outlined),
                          ),
                          validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          onChanged: (v) => _calcularNuevosTotales(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _fleteCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Flete',
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                          ),
                          validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          onChanged: (v) => _calcularNuevosTotales(),
                        ),
                        const SizedBox(height: 12),
                        _ReadOnlyTile(icon: Icons.savings_outlined, label: 'Anticipo', value: _anticipo.toString()),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _TotalTile(label: 'Total', value: _totalActual)),
                            const SizedBox(width: 12),
                            Expanded(child: _TotalTile(label: 'Restante', value: _restanteActual)),
                          ],
                        ),
                        Text(
                          'Los ajustes se reflejaran en la sección siguiente.',
                          style: TextStyle(color: const Color.fromARGB(255, 231, 137, 137)),
                        ),
                      ],
                    ),

                    // ========== NUEVO: Actualización de precio ==========
                    _SectionCard(
                      title: 'Actualización de precio',
                      children: [
                        TextFormField(
                          controller: _ajusteCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Ajuste al Restante (Se resta al restante)',
                            prefixIcon: Icon(Icons.price_change_outlined),
                          ),
                          validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          onChanged: (v) => _calcularNuevosTotales(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _TotalTile(label: 'Nuevo Total', value: _totalNuevo)),
                            const SizedBox(width: 12),
                            Expanded(child: _TotalTile(label: 'Nuevo Restante', value: _restanteNuevo)),
                          ],
                        ),
                        Text(
                          'El ajuste se suma al Total actual antes de recalcular el Restante.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),

                    // ========== Estado del pedido ==========
                    _SectionCard(
                      title: 'Estado del pedido',
                      children: [
                        _EstadoSelector(
                          value: _estado,
                          onChanged: (v) => setState(() => _estado = v),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Botón ACTUALIZAR
                    SizedBox(
                      height: 52,
                      child: FilledButton.tonal(
                        style: ButtonStyle(
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          backgroundColor: const WidgetStatePropertyAll(Colors.black),
                          foregroundColor: const WidgetStatePropertyAll(Colors.white),
                        ),
                        onPressed: _onActualizar,
                        child: const Text('Actualizar'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onActualizar() async {
    if (!(_formKey.currentState?.validate() ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los campos')),
      );
      return;
    }

    try{
      String est;
      switch (_estado) {
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

      // Armamos las fechas de forma segura para pasarlas a la función
      final String? fechaDb = _fechaEntrega != null 
          ? _fechaEntrega!.toIso8601String().split('T')[0] 
          : null;
    
      final String? horaDb = _horaEntrega != null 
          ? "${_horaEntrega!.hour.toString().padLeft(2, '0')}:${_horaEntrega!.minute.toString().padLeft(2, '0')}:00" 
          : null;

      // Disparamos la transacción atómica
      await supabase.rpc('actualizar_pedido_completo', params: {
        'p_id_cliente': _items['clientes']['id_cliente'],
        'p_telefono': _telefonoCtrl.text.trim(),
        'p_direccion': _domicilioCtrl.text.trim(),
        'p_id_pedido': _items['id_pedido'],
        'p_fecha_entrega': fechaDb,
        'p_hora_entrega': horaDb,
        'p_descuento': double.parse(_otrosCargosCtrl.text.trim()) ,
        'p_flete': double.parse(_fleteCtrl.text.trim()),
        'p_restante': _restanteNuevo,
        'p_estado': est,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_folio actualizado · Estado: ${_estadoLabel(_estado)} · Total: ${_totalNuevo.toStringAsFixed(2)} · Restante: ${_restanteNuevo.toStringAsFixed(2)}',
          ),
        ),
      );
    }catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $err'), 
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _estadoLabel(PedidoEstado e) {
    switch (e) {
      case PedidoEstado.entregado: return 'Entregado';
      case PedidoEstado.hecho:     return 'Hecho';
      case PedidoEstado.pendiente: return 'Pendiente';
    }
  }
}

/// ============ Widgets reutilizables ============

class _HeaderCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _HeaderCard({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: TextStyle(color: Colors.grey.shade700, height: 1.25)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
            const SizedBox(height: 14),
            ..._withGaps(children, 12),
          ],
        ),
      ),
    );
  }

  List<Widget> _withGaps(List<Widget> items, double gap) {
    if (items.isEmpty) return items;
    return [
      for (int i = 0; i < items.length; i++) ...[
        items[i],
        if (i != items.length - 1) SizedBox(height: gap),
      ]
    ];
  }
}

class _TotalTile extends StatelessWidget {
  final String label;
  final double value;
  const _TotalTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReadOnlyTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade700),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoSelector extends StatelessWidget {
  final PedidoEstado value;
  final ValueChanged<PedidoEstado> onChanged;
  const _EstadoSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8, children: [
        _segChip('Pendiente', PedidoEstado.pendiente),
        _segChip('Hecho', PedidoEstado.hecho),
        _segChip('Entregado', PedidoEstado.entregado),
      ],
    );
  }

  Widget _segChip(String label, PedidoEstado e) {
    final selected = value == e;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(e),
      shape: StadiumBorder(
        side: BorderSide(color: selected ? Colors.black87 : Colors.grey.shade300),
      ),
      selectedColor: Colors.grey.shade200,
      showCheckmark: false,
    );
  }
}
