import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DialogoRegistrarProduccion extends StatefulWidget {

  const DialogoRegistrarProduccion({
    super.key,
  });

  @override
  State<DialogoRegistrarProduccion> createState() => _DialogoRegistrarProduccionState();
}

class _DialogoRegistrarProduccionState extends State<DialogoRegistrarProduccion> {
  // 1. LLAVE PARA VALIDAR EL FORMULARIO
  final _formKey = GlobalKey<FormState>();

  // 2. CONTROLADORES PARA CAPTURAR EL TEXTO
  final _tamanoCtrl = TextEditingController();
  final _precioVentaCtrl = TextEditingController();
  final _precioCostoCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _porcionesCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _fechaProduccionCtrl = TextEditingController();
  final _fechaCaducidadCtrl = TextEditingController();

  String? _productoSelId;
  String? _varianteSelId;
  List<Map<String, dynamic>> _variantesFiltradas = [];

  List<Map<String, dynamic>> _variantes = [];
  List<Map<String, dynamic>> _productos = [];

  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    setState(() => _cargando = true);
    try {
      _variantes =
          await supabase.from('producto_variantes').select('*').order('tamaño');

      _productos =
          await supabase.from('productos').select('*').order('nombre');
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    // Limpieza de memoria
    _tamanoCtrl.dispose();
    _precioVentaCtrl.dispose();
    _precioCostoCtrl.dispose();
    _stockCtrl.dispose();
    _porcionesCtrl.dispose();
    _pesoCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _fechaProduccionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  return AlertDialog(
    title: const Text('Registrar Producción'),
    content: SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// SECCIÓN: DATOS DE PRODUCCIÓN
              const Text(
                "Datos de Producción",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 15),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 4.5,
                children: [

                  /// PRODUCTO
                  DropdownButtonFormField<String>(
                    value: _productoSelId,
                    items: _productos
                        .map((c) => DropdownMenuItem(
                              value: c['id_producto'].toString(),
                              child: Text(c['nombre']),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _productoSelId = v;
                        _varianteSelId = null;

                        _variantesFiltradas = _variantes.where((variante) {
                          return variante['id_producto'].toString() == v;
                        }).toList();
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Producto',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  /// VARIANTE
                  DropdownButtonFormField<String>(
                    value: _varianteSelId,
                    items: _variantesFiltradas
                        .map((c) => DropdownMenuItem(
                              value: c['id_variante'].toString(),
                              child: Text(c['tamaño']),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _varianteSelId = v),
                    decoration: const InputDecoration(
                      labelText: 'Variante',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  /// CANTIDAD
                  _buildField(
                    label: 'Cantidad Producida',
                    controller: _precioCostoCtrl,
                    isNumeric: true,
                  ),

                  /// FECHA PRODUCCIÓN
                  _buildDateField(
                    label: 'Fecha Producción',
                    controller: _fechaProduccionCtrl,
                    context: context,
                  ),

                  /// FECHA CADUCIDAD
                  _buildDateField(
                    label: 'Fecha Caducidad',
                    controller: _fechaCaducidadCtrl,
                    context: context,
                  ),

                  /// BOTÓN AGREGAR
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text(
                      "Agregar",
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: () {
                      print('Agregar Variante Producida');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color.fromARGB(210, 236, 231, 131),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              /// SECCIÓN TABLA
              const Text(
                "Producción Registrada",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Producto')),
                    DataColumn(label: Text('Variante')),
                    DataColumn(label: Text('Cantidad')),
                    DataColumn(label: Text('F. Producción')),
                    DataColumn(label: Text('F. Caducidad')),
                  ],
                  rows: const [],
                ),
              ),
            ],
          ),
        ),
      ),
    ),

    /// BOTONES DEL DIALOG
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, null),
        child: const Text('CANCELAR'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.blueGrey,
        ),
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            final Map<String, dynamic> datos = {
              'tamaño': _tamanoCtrl.text,
              'precio_venta':
                  double.tryParse(_precioVentaCtrl.text) ?? 0.0,
              'precio_costo':
                  double.tryParse(_precioCostoCtrl.text),
              'porciones': int.tryParse(_porcionesCtrl.text),
              'peso_estimado':
                  double.tryParse(_pesoCtrl.text),
              'stock_minimo': int.tryParse(_minCtrl.text),
              'stock_maximo': int.tryParse(_maxCtrl.text),
            };

            Navigator.pop(context, datos);
          }
        },
        child: const Text('REGISTRAR'),
      ),
    ],
  );
}

  Widget _buildField({
    required String label, 
    required TextEditingController controller, // ✅ RECIBE EL CONTROLADOR
    String? prefix, 
    bool isNumeric = false, 
    bool onlyInt = false,
    bool isRequired = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller, // ✅ VINCULACIÓN
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefix,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: isNumeric ? TextInputType.numberWithOptions(decimal: !onlyInt) : TextInputType.text,
        inputFormatters: isNumeric 
          ? [FilteringTextInputFormatter.allow(RegExp(onlyInt ? r'^\d+$' : r'^\d+\.?\d{0,2}'))] 
          : null,
        validator: (v) => isRequired && (v == null || v.isEmpty) ? 'Requerido' : null,
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required BuildContext context,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      onTap: () async {
        DateTime? fecha = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );

        if (fecha != null) {
          controller.text =
              "${fecha.year}-${fecha.month}-${fecha.day}";
        }
      },
    );
  }
}