// ver_pedido_consulta.dart
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';

/// Mantén el mismo enum que usas en VerPedidosScreen
enum PedidoEstado { pendiente, hecho, entregado }

class VerPedidoConsultaScreen extends StatefulWidget {
  // Opcional: datos de entrada para precargar la vista
  final String? folio;
  final String? nombre;     // ← no editable
  final String? telefono;
  final DateTime? fechaEntrega;
  final TimeOfDay? horaEntrega;
  final String? domicilio;
  final String? producto;   // "Pastel"
  final String? tamano;     // "6-8", ...
  final int? pisos;
  final bool? doble;
  final String? base;
  final List<String>? disenosSeleccionados; // ["Oblea", "Crema", ...]
  final String? sabor;
  final String? mensajeEnPastel;

  // Precios actuales
  final double? deposito;
  final double? flete;
  final double? anticipo;
  final double? total;      // si no lo tienes, lo recalculo como deposito + flete
  final double? restante;   // si no lo tienes, lo recalculo como total - anticipo

  final PedidoEstado? estado;

  const VerPedidoConsultaScreen({
    super.key,
    this.folio,
    this.nombre,
    this.telefono,
    this.fechaEntrega,
    this.horaEntrega,
    this.domicilio,
    this.producto,
    this.tamano,
    this.pisos,
    this.doble,
    this.base,
    this.disenosSeleccionados,
    this.sabor,
    this.mensajeEnPastel,
    this.deposito,
    this.flete,
    this.anticipo,
    this.total,
    this.restante,
    this.estado,
  });

  @override
  State<VerPedidoConsultaScreen> createState() => _VerPedidoConsultaScreenState();
}

class _VerPedidoConsultaScreenState extends State<VerPedidoConsultaScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores (nombre deshabilitado)
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _domicilioCtrl;

  // Precios “actuales” (sección igual que el formulario)
  late final TextEditingController _depositoCtrl;
  late final TextEditingController _fleteCtrl;
  late final TextEditingController _anticipoCtrl;

  // Totales calculados “actuales”
  double _totalActual = 0;
  double _restanteActual = 0;

  // Sección NUEVA: actualización de precio (ajuste)
  final _ajusteCtrl = TextEditingController(); // positivo o negativo
  double _totalNuevo = 0;
  double _restanteNuevo = 0;

  // Estado
  late PedidoEstado _estado;

  // Otros campos de solo lectura
  late final String _folio;
  late final String _producto;
  late final String _tamano;
  late final int _pisos;
  late final bool _doble;
  late final String? _base;
  late final List<String> _disenos;
  late final String _sabor;
  late final String _mensaje;
  late final DateTime? _fechaEntrega;
  late final TimeOfDay? _horaEntrega;

  @override
  void initState() {
    super.initState();

    _folio     = widget.folio ?? 'A-000';
    _nombreCtrl = TextEditingController(text: widget.nombre ?? 'Cliente Demo');
    _telefonoCtrl = TextEditingController(text: widget.telefono ?? '771-000-0000');
    _domicilioCtrl = TextEditingController(text: widget.domicilio ?? '');

    _producto = widget.producto ?? 'Pastel';
    _tamano   = widget.tamano ?? '6-8';
    _pisos    = widget.pisos ?? 1;
    _doble    = widget.doble ?? false;
    _base     = widget.base;
    _disenos  = widget.disenosSeleccionados ?? const ['Oblea'];
    _sabor    = widget.sabor ?? 'Chocolate';
    _mensaje  = widget.mensajeEnPastel ?? '';

    _fechaEntrega = widget.fechaEntrega;
    _horaEntrega  = widget.horaEntrega;

    // Precios actuales
    final dep = (widget.deposito ?? 300).toDouble();
    final fle = (widget.flete ?? 50).toDouble();
    final ant = (widget.anticipo ?? 100).toDouble();

    _depositoCtrl = TextEditingController(text: dep.toStringAsFixed(2));
    _fleteCtrl    = TextEditingController(text: fle.toStringAsFixed(2));
    _anticipoCtrl = TextEditingController(text: ant.toStringAsFixed(2));

    // Cálculo de actuales
    _recalcularActuales();

    // Ajuste inicia en 0
    _ajusteCtrl.text = '0.00';
    _recalcularNuevos();

    _estado = widget.estado ?? PedidoEstado.pendiente;

    // Listeners para recalcular al vuelo
    _depositoCtrl.addListener(_recalcularActuales);
    _fleteCtrl.addListener(_recalcularActuales);
    _anticipoCtrl.addListener(() {
      _recalcularActuales();
      _recalcularNuevos();
    });
    _ajusteCtrl.addListener(_recalcularNuevos);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _domicilioCtrl.dispose();
    _depositoCtrl.dispose();
    _fleteCtrl.dispose();
    _anticipoCtrl.dispose();
    _ajusteCtrl.dispose();
    super.dispose();
  }

  void _recalcularActuales() {
    final dep = double.tryParse(_depositoCtrl.text) ?? 0;
    final fle = double.tryParse(_fleteCtrl.text) ?? 0;
    final ant = double.tryParse(_anticipoCtrl.text) ?? 0;
    setState(() {
      _totalActual = dep + fle;
      _restanteActual = (_totalActual - ant).clamp(0, double.infinity);
    });
  }

  void _recalcularNuevos() {
    final ajuste = double.tryParse(_ajusteCtrl.text) ?? 0;
    final ant = double.tryParse(_anticipoCtrl.text) ?? 0;
    setState(() {
      _totalNuevo = (_totalActual + ajuste).clamp(0, double.infinity);
      _restanteNuevo = (_totalNuevo - ant).clamp(0, double.infinity);
    });
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
                child: ListView(
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
                        TextFormField(
                          controller: _nombreCtrl,
                          enabled: false, // ← bloqueado
                          decoration: const InputDecoration(
                            labelText: 'Nombre (no editable)',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telefonoCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            prefixIcon: Icon(Icons.call_outlined),
                          ),
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
                                      : 'Fecha no registrada',
                                  prefixIcon: const Icon(Icons.event_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: _horaEntrega != null
                                      ? 'Hora: ${_horaEntrega!.format(context)}'
                                      : 'Hora no registrada',
                                  prefixIcon: const Icon(Icons.schedule_outlined),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _domicilioCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Domicilio (solo lectura)',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                      ],
                    ),

                    // ========== Producto (solo lectura) ==========
                    _SectionCard(
                      title: 'Producto',
                      children: [
                        _ReadOnlyTile(icon: Icons.cake_outlined, label: 'Producto', value: _producto),
                        _ReadOnlyTile(icon: Icons.straighten_outlined, label: 'Tamaño', value: _tamano),
                        Row(
                          children: [
                            Expanded(child: _ReadOnlyTile(icon: Icons.layers_outlined, label: 'Pisos', value: '$_pisos')),
                            const SizedBox(width: 12),
                            Expanded(child: _ReadOnlyTile(icon: Icons.toggle_on_outlined, label: 'Tipo', value: _doble ? 'Doble' : 'Sencillo')),
                          ],
                        ),
                        if (_base != null && _base!.isNotEmpty) _ReadOnlyTile(
                          icon: Icons.inventory_2_outlined, label: 'Base', value: _base!,
                        ),
                      ],
                    ),

                    // ========== Diseño (solo lectura) ==========
                    _SectionCard(
                      title: 'Diseño del pastel',
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _disenos.map((k) => Chip(label: Text(k))).toList(),
                        ),
                        _ReadOnlyTile(icon: Icons.icecream_outlined, label: 'Sabor', value: _sabor),
                        if (_mensaje.isNotEmpty)
                          _ReadOnlyTile(icon: Icons.edit_note_outlined, label: 'Mensaje', value: _mensaje),
                      ],
                    ),

                    // ========== Precio (igual que en el formulario) ==========
                    _SectionCard(
                      title: 'Precio del pastel (actual)',
                      children: [
                        TextFormField(
                          controller: _depositoCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Depósito',
                            prefixIcon: Icon(Icons.attach_money_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _fleteCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Flete',
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _anticipoCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Anticipo',
                            prefixIcon: Icon(Icons.savings_outlined),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: _TotalTile(label: 'Total', value: _totalActual)),
                            const SizedBox(width: 12),
                            Expanded(child: _TotalTile(label: 'Restante', value: _restanteActual)),
                          ],
                        ),
                        Text(
                          'El restante se calcula como Total - Anticipo.',
                          style: TextStyle(color: Colors.grey.shade600),
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
                            labelText: 'Ajuste (+/-) al Total',
                            prefixIcon: Icon(Icons.price_change_outlined),
                          ),
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

  void _onActualizar() {
    if (!(_formKey.currentState?.validate() ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los campos')),
      );
      return;
    }

    // Aquí normalmente mandarías a PB/SQLite:
    // - Actualizar teléfono si cambió
    // - Guardar depósito/flete/anticipo y nuevo total/restante
    // - Guardar estado
    // (y, si quieres, guardar un historial de “ajustes”)

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$_folio actualizado · Estado: ${_estadoLabel(_estado)} · Total: ${_totalNuevo.toStringAsFixed(2)} · Restante: ${_restanteNuevo.toStringAsFixed(2)}',
        ),
      ),
    );
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
