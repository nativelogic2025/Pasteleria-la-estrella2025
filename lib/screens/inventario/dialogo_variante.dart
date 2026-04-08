import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DialogoAgregarVariante extends StatefulWidget {
  final String nombreProducto;
  final String? urlImagen;

  const DialogoAgregarVariante({
    super.key,
    required this.nombreProducto,
    this.urlImagen,
  });

  @override
  State<DialogoAgregarVariante> createState() => _DialogoAgregarVarianteState();
}

class _DialogoAgregarVarianteState extends State<DialogoAgregarVariante> {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar variante'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form( // ✅ ENVOLVEMOS EN UN FORM
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.urlImagen != null && widget.urlImagen!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.urlImagen!,
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const Icon(Icons.broken_image, size: 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  '"${widget.nombreProducto}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 20),
                
                _buildField(label: 'Tamaño', controller: _tamanoCtrl, isRequired: true),
                _buildField(label: 'Precio Venta', controller: _precioVentaCtrl, prefix: '\$ ', isNumeric: true, isRequired: true),
                _buildField(label: 'Precio Costo (opcional)', controller: _precioCostoCtrl, prefix: '\$ ', isNumeric: true),
                // _buildField(label: 'Stock (opcional)', controller: _stockCtrl, isNumeric: true, onlyInt: true),
                _buildField(label: 'Porciones (opcional)', controller: _porcionesCtrl, isNumeric: true, onlyInt: true),
                _buildField(label: 'Peso Estimado (opcional)', controller: _pesoCtrl, isNumeric: true),
                _buildField(label: 'Stock mínimo (opcional)', controller: _minCtrl, isNumeric: true, onlyInt: true),
                _buildField(label: 'Stock máximo (opcional)', controller: _maxCtrl, isNumeric: true, onlyInt: true),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null), // Retorna null si cancela
          child: const Text('CANCELAR'),
        ),
        FilledButton(
          onPressed: () {
            // 3. VALIDAR Y RETORNAR EL MAPA DE DATOS
            if (_formKey.currentState!.validate()) {
              final Map<String, dynamic> datos = {
                'tamaño': _tamanoCtrl.text,
                'precio_venta': double.tryParse(_precioVentaCtrl.text) ?? 0.0,
                'precio_costo': double.tryParse(_precioCostoCtrl.text),
                // 'stock': int.tryParse(_stockCtrl.text) ?? 0,
                'porciones': int.tryParse(_porcionesCtrl.text),
                'peso_estimado': double.tryParse(_pesoCtrl.text),
                'stock_minimo': int.tryParse(_minCtrl.text),
                'stock_maximo': int.tryParse(_maxCtrl.text),
              };
              Navigator.pop(context, datos); // ✅ RETORNA EL MAPA
            }
          },
          style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey),
          child: const Text('AGREGAR VARIANTE'),
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
}