import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        width: 850,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFCF5EE),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF8C5535).withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.factory_rounded, color: Color(0xFF8C5535), size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Text("Registrar Producción", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),

            // BODY
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // FORMULARIO SUPERIOR
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(flex: 2, child: _buildDropdownProd()),
                                const SizedBox(width: 16),
                                Expanded(flex: 2, child: _buildDropdownVar()),
                                const SizedBox(width: 16),
                                Expanded(flex: 1, child: _buildField(label: "Cantidad", controller: _cantidadCtrl, isNumeric: true)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _buildDateField(label: "Fecha Producción", controller: _fechaProduccionCtrl, isProduccion: true)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildDateField(label: "Fecha Caducidad", controller: _fechaCaducidadCtrl, isProduccion: false)),
                                const SizedBox(width: 16),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: _agregarProduccion,
                                    icon: const Icon(Icons.add_task),
                                    label: const Text("Agregar", style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8C5535),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // TABLA
                      if (_produccionesTemp.isNotEmpty) ...[
                        Row(
                          children: [
                            const Text("Registros Pendientes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFF8C5535).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Text('${_produccionesTemp.length}', style: const TextStyle(color: Color(0xFF8C5535), fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(const Color(0xFFF9F9F9)),
                              columns: const [
                                DataColumn(label: Text("Producto", style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text("Variante", style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text("Cantidad", style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text("Fechas", style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text("", style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: _produccionesTemp.map((p) => DataRow(
                                cells: [
                                  DataCell(Text(p['producto_nombre']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                                  DataCell(Text(p['variante_nombre']?.toString() ?? '')),
                                  DataCell(Text('${p['cantidad']} pzas', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold))),
                                  DataCell(Text('${p['fecha_produccion']} al ${p['fecha_caducidad']}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12))),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: 'Eliminar',
                                      splashRadius: 20,
                                      onPressed: () => setState(() => _produccionesTemp.remove(p)),
                                    ),
                                  ),
                                ]
                              )).toList(),
                            ),
                          ).animate().fade().slideY(begin: 0.1),
                        ),
                      ] else ...[
                         Container(
                           width: double.infinity,
                           padding: const EdgeInsets.all(32),
                           decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid), borderRadius: BorderRadius.circular(12)),
                           child: Column(
                             children: [
                               Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
                               const SizedBox(height: 12),
                               Text("No hay registros pendientes", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                               Text("Agrega lotes en el formulario de arriba", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                             ],
                           ),
                         )
                      ]
                    ],
                  ),
                ),
              ),
            ),

            // FOOTER
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _produccionesTemp.isEmpty ? null : () => Navigator.pop(context, _produccionesTemp),
                    icon: const Icon(Icons.save),
                    label: const Text("Guardar Registros"),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8C5535),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fade(duration: 400.ms).scaleXY(begin: 0.95),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildDropdownProd() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: _productoSelId,
      decoration: _inputDeco("Producto"),
      items: _productos.map((p) => DropdownMenuItem(value: p['id_producto'].toString(), child: Text(p['nombre'], maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
      validator: (v) => v == null ? 'Requerido' : null,
      onChanged: (v) {
        setState(() {
          _productoSelId = v;
          _varianteSelId = null;
          _variantesFiltradas = _variantes.where((variante) => variante['id_producto'].toString() == v).toList();
        });
      },
    );
  }

  Widget _buildDropdownVar() {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: _varianteSelId,
      onChanged: (_productoSelId != null && _variantesFiltradas.isNotEmpty) ? (v) => setState(() => _varianteSelId = v) : null,
      decoration: _inputDeco("Variante").copyWith(
        errorText: (_productoSelId != null && _variantesFiltradas.isEmpty) ? 'Sin variantes' : null,
        hintText: _productoSelId == null ? 'Elija un producto' : (_variantesFiltradas.isEmpty ? 'Inválido' : 'Seleccione variante'),
      ),
      items: _variantesFiltradas.map((v) => DropdownMenuItem(value: v['id_variante'].toString(), child: Text(v['tamaño'], maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
      validator: (v) {
        if (_productoSelId != null && _variantesFiltradas.isEmpty) return 'Cambie producto';
        return v == null ? 'Requerido' : null;
      },
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF8C5535))),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red)),
    );
  }

  Widget _buildField({required String label, required TextEditingController controller, bool isNumeric = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumeric ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: _inputDeco(label),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Req';
        if (isNumeric) {
          final number = int.tryParse(v);
          if (number == null || number <= 0) return '> 0';
        }
        return null;
      },
    );
  }

  Widget _buildDateField({required String label, required TextEditingController controller, required bool isProduccion}) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: _inputDeco(label).copyWith(suffixIcon: const Icon(Icons.calendar_today, size: 18, color: Colors.grey)),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Req';
        if (!isProduccion && _fechaProduccionCtrl.text.isNotEmpty) {
          final fProd = DateTime.tryParse(_fechaProduccionCtrl.text);
          final fCad = DateTime.tryParse(v);
          if (fProd != null && fCad != null && fProd.isAfter(fCad)) return 'Inválido';
        }
        return null;
      },
      onTap: () async {
        DateTime? fecha = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF8C5535))),
            child: child!,
          ),
        );
        if (fecha != null) {
          setState(() => controller.text = "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}");
          _formKey.currentState?.validate();
        }
      },
    );
  }
}