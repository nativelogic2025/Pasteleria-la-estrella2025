import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class DialogoRegistrarProduccion extends StatefulWidget {
  const DialogoRegistrarProduccion({super.key});

  @override
  State<DialogoRegistrarProduccion> createState() => _DialogoRegistrarProduccionState();
}

class _DialogoRegistrarProduccionState extends State<DialogoRegistrarProduccion> {
  // 1. LLAVE PARA VALIDAR EL FORMULARIO
  final _formKey = GlobalKey<FormState>();

  // 2. CONTROLADORES ESTRICTAMENTE NECESARIOS
  final _cantidadCtrl = TextEditingController();
  final _fechaProduccionCtrl = TextEditingController();
  final _fechaCaducidadCtrl = TextEditingController();

  String? _productoSelId;
  String? _varianteSelId;
  
  List<Map<String, dynamic>> _variantesFiltradas = [];
  List<Map<String, dynamic>> _produccionesTemp = [];
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
      _variantes = await supabase.from('producto_variantes').select('*').order('tamaño');
      _productos = await supabase.from('productos').select('*').order('nombre');
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
    // Limpieza de memoria solo de los controladores usados
    _cantidadCtrl.dispose();
    _fechaProduccionCtrl.dispose();
    _fechaCaducidadCtrl.dispose();
    super.dispose();
  }

  // Dentro de _DialogoRegistrarProduccionState
  void _agregarProduccion() {
    if (!_formKey.currentState!.validate()) return;
    if (_productoSelId == null || _varianteSelId == null) return;

    setState(() {
      _produccionesTemp.add({
        // -- Datos para mostrar en la tabla visual --
        "producto_nombre": _productos.firstWhere((p) => p['id_producto'].toString() == _productoSelId)['nombre'],
        "variante_nombre": _variantesFiltradas.firstWhere((v) => v['id_variante'].toString() == _varianteSelId)['tamaño'],
        
        // -- Datos reales que enviaremos a Supabase --
        "id_producto": _productoSelId, 
        "id_variante": _varianteSelId,
        "cantidad": int.parse(_cantidadCtrl.text),
        "fecha_produccion": _fechaProduccionCtrl.text,
        "fecha_caducidad": _fechaCaducidadCtrl.text,
      });

      _cantidadCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.factory),
          SizedBox(width: 10),
          Text("Registrar Producción"),
        ],
      ),
      content: SizedBox(
        width: 950,
        // Agregamos un tema local para estandarizar la altura y bordes de TODOS los inputs
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// FORMULARIO
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      // --- FILA 1 ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _productoSelId,
                              decoration: const InputDecoration(labelText: "Producto"),
                              items: _productos.map((p) {
                                return DropdownMenuItem(
                                  value: p['id_producto'].toString(),
                                  child: Text(p['nombre'], overflow: TextOverflow.ellipsis, maxLines: 1,),
                                );
                              }).toList(),
                              validator: (v) => v == null ? 'Requerido' : null,
                              onChanged: (v) {
                                setState(() {
                                  _productoSelId = v;
                                  _varianteSelId = null; // Reset variante
                                  _variantesFiltradas = _variantes
                                      .where((variante) => variante['id_producto'].toString() == v)
                                      .toList();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _varianteSelId,
                              // 1. DESHABILITAR si no hay producto seleccionado o si la lista filtrada está vacía
                              onChanged: (_productoSelId != null && _variantesFiltradas.isNotEmpty)
                                  ? (v) => setState(() => _varianteSelId = v)
                                  : null,
                              decoration: InputDecoration(
                                labelText: "Variante",
                                // 2. ERROR VISUAL INMEDIATO: Si hay producto pero no tiene variantes, se pone en rojo
                                errorText: (_productoSelId != null && _variantesFiltradas.isEmpty)
                                    ? 'Producto sin variantes'
                                    : null,
                                // 3. TEXTO DE AYUDA DINÁMICO
                                hintText: _productoSelId == null
                                    ? 'Elija un producto primero'
                                    : (_variantesFiltradas.isEmpty ? 'Inválido' : 'Seleccione variante'),
                              ),
                              items: _variantesFiltradas.map((v) {
                                return DropdownMenuItem(
                                  value: v['id_variante'].toString(),
                                  child: Text(v['tamaño'], overflow: TextOverflow.ellipsis, maxLines: 1,),
                                );
                              }).toList(),
                              // 4. VALIDACIÓN ESTRICTA
                              validator: (v) {
                                if (_productoSelId != null && _variantesFiltradas.isEmpty) {
                                  return 'Cambie el producto';
                                }
                                return v == null ? 'Requerido' : null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildField(
                              label: "Cantidad",
                              controller: _cantidadCtrl,
                              isNumeric: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // --- FILA 2 ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildDateField(
                              label: "Fecha Producción",
                              controller: _fechaProduccionCtrl,
                              context: context,
                              isProduccion: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDateField(
                              label: "Fecha Caducidad",
                              controller: _fechaCaducidadCtrl,
                              context: context,
                              isProduccion: false,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 52, // Altura igualada a los TextFields estándar
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text("Agregar a tabla", style: TextStyle(fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[600],
                                  foregroundColor: Colors.black87,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _agregarProduccion,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// TABLA
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                        columns: const [
                          DataColumn(label: Text("Producto", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Variante", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Cantidad", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Producción", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Caducidad", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Acciones", style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _produccionesTemp.map((p) {
                          return DataRow(
                            cells: [
                              // Se cambiaron 'producto' por 'producto_nombre' y 'variante' por 'variante_nombre'
                              DataCell(Text(p['producto_nombre']?.toString() ?? 'Sin producto')),
                              DataCell(Text(p['variante_nombre']?.toString() ?? 'Sin variante')),
                              DataCell(Text('${p['cantidad'] ?? 0} pzas')),
                              DataCell(Text(p['fecha_produccion']?.toString() ?? 'N/A')),
                              DataCell(Text(p['fecha_caducidad']?.toString() ?? 'N/A')),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Eliminar',
                                  onPressed: () => setState(() => _produccionesTemp.remove(p)),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCELAR"),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.save),
          label: const Text("Guardar Registros"),
          onPressed: _produccionesTemp.isEmpty 
              ? null 
              : () => Navigator.pop(context, _produccionesTemp), 
        ),
      ],
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    bool isNumeric = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      // Solo permitimos números enteros positivos
      inputFormatters: isNumeric ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Requerido';
        if (isNumeric) {
          final number = int.tryParse(v);
          if (number == null || number <= 0) return 'Debe ser mayor a 0';
        }
        return null;
      },
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required BuildContext context,
    required bool isProduccion,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Requerido';
        
        // Validación cruzada de fechas: Producción <= Caducidad
        if (!isProduccion && _fechaProduccionCtrl.text.isNotEmpty) {
          final fProd = DateTime.tryParse(_fechaProduccionCtrl.text);
          final fCad = DateTime.tryParse(v);
          
          if (fProd != null && fCad != null && fProd.isAfter(fCad)) {
            return 'La caducidad debe ser posterior';
          }
        }
        return null;
      },
      onTap: () async {
        DateTime? fecha = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );

        if (fecha != null) {
          // Formateamos para asegurar formato YYYY-MM-DD (Ej: 2024-05-09)
          final month = fecha.month.toString().padLeft(2, '0');
          final day = fecha.day.toString().padLeft(2, '0');
          
          setState(() {
            controller.text = "${fecha.year}-$month-$day";
          });
          
          // Forzamos re-validación tras elegir fecha
          _formKey.currentState?.validate();
        }
      },
    );
  }
}