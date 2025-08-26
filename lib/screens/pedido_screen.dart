import 'package:flutter/material.dart';
import 'carrito.dart';

class PedidoScreen extends StatefulWidget {
  const PedidoScreen({super.key});

  @override
  State<PedidoScreen> createState() => _PedidoScreenState();
}

class _PedidoScreenState extends State<PedidoScreen> {
  // Controladores
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _domicilioController = TextEditingController();
  final _depositoController = TextEditingController();
  final _fleteController = TextEditingController();
  final _anticipoController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _mensajeController = TextEditingController();

  DateTime? _fechaEntrega;
  TimeOfDay? _horaEntrega;

  // Producto
  String _productoSeleccionado = 'Pastel';
  String _tamanoSeleccionado = 'Individual';
  int _pisos = 1;
  bool _doble = false;
  String? _baseSeleccionada;
  List<String> _bases = ['Bizcocho', 'Panqué', 'Galleta'];
  Map<String, bool> _disenos = {
    'Oblea': false,
    'Sin Oblea': false,
    'Normal': false,
    'Crema': false,
  };
  String _saborSeleccionado = 'Chocolate';
  List<String> _sabores = [
    'Chocolate',
    'Vainilla',
    'Fresa',
    'Zarzamora',
    'Oreo',
    'Guayaba',
    'PiñaCoco',
    'Mango'
  ];

  double _total = 0;
  double _restante = 0;

  void _calcularTotales() {
    double deposito = double.tryParse(_depositoController.text) ?? 0;
    double flete = double.tryParse(_fleteController.text) ?? 0;
    double anticipo = double.tryParse(_anticipoController.text) ?? 0;

    setState(() {
      _total = deposito + flete;
      _restante = _total - anticipo;
    });
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (fecha != null) setState(() => _fechaEntrega = fecha);
  }

  Future<void> _seleccionarHora(BuildContext context) async {
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (hora != null) setState(() => _horaEntrega = hora);
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Pedido', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CarritoScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ExpansionTile(
              initiallyExpanded: true,
              title: const Text('Cliente', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                const SizedBox(height: 8),
                TextFormField(controller: _nombreController, decoration: _inputDecoration('Nombre')),
                const SizedBox(height: 8),
                TextFormField(controller: _telefonoController, decoration: _inputDecoration('Teléfono'), keyboardType: TextInputType.phone),
                const SizedBox(height: 8),
              ],
            ),
            ExpansionTile(
              title: const Text('Datos de entrega', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        decoration: _inputDecoration(
                          _fechaEntrega != null
                              ? 'Fecha: ${_fechaEntrega!.day}/${_fechaEntrega!.month}/${_fechaEntrega!.year}'
                              : 'Seleccionar Fecha',
                        ),
                        onTap: () => _seleccionarFecha(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        decoration: _inputDecoration(
                          _horaEntrega != null
                              ? 'Hora: ${_horaEntrega!.format(context)}'
                              : 'Seleccionar Hora',
                        ),
                        onTap: () => _seleccionarHora(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(controller: _domicilioController, decoration: _inputDecoration('Domicilio')),
              ],
            ),
            ExpansionTile(
              title: const Text('Producto', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _productoSeleccionado,
                  items: ['Pastel'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _productoSeleccionado = val!),
                  decoration: _inputDecoration('Producto'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _tamanoSeleccionado,
                  items: [
                    'Individual', '4-5', '6-8', '10-12', 'Quma', '15-20', '25', '30', '40', '50', '60', '80', '100', '150', '200', '250', '300', '350', '400'
                  ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _tamanoSeleccionado = val!),
                  decoration: _inputDecoration('Tamaño'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(value: _doble, onChanged: (val) => setState(() => _doble = val!)),
                    const Text('Doble'),
                    const SizedBox(width: 16),
                    const Text('Sencillo'),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _pisos,
                  items: [1, 2, 3, 4].map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
                  onChanged: (val) => setState(() => _pisos = val!),
                  decoration: _inputDecoration('Pisos'),
                ),
                if (_tamanoSeleccionado == '150')
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: DropdownButtonFormField<String>(
                      value: _baseSeleccionada,
                      items: _bases.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => _baseSeleccionada = val),
                      decoration: _inputDecoration('Base'),
                    ),
                  ),
              ],
            ),
            ExpansionTile(
              title: const Text('Diseño del pastel', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                const SizedBox(height: 8),
                Column(
                  children: _disenos.keys.map((key) {
                    return CheckboxListTile(
                      title: Text(key),
                      value: _disenos[key],
                      onChanged: (val) => setState(() => _disenos[key] = val!),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }).toList(),
                ),
                TextFormField(
                  controller: _descripcionController,
                  decoration: _inputDecoration('Descripción'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _saborSeleccionado,
                  items: _sabores.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _saborSeleccionado = val!),
                  decoration: _inputDecoration('Sabor'),
                ),
                TextFormField(
                  controller: _mensajeController,
                  decoration: _inputDecoration('Mensaje'),
                  maxLines: 3,
                ),
              ],
            ),
            ExpansionTile(
              initiallyExpanded: true,
              title: const Text('Precio del pastel', style: TextStyle(fontWeight: FontWeight.bold)),
              children: [
                const SizedBox(height: 8),
                TextFormField(controller: _depositoController, decoration: _inputDecoration('Depósito'), keyboardType: TextInputType.number, onChanged: (_) => _calcularTotales()),
                TextFormField(controller: _fleteController, decoration: _inputDecoration('Flete'), keyboardType: TextInputType.number, onChanged: (_) => _calcularTotales()),
                TextFormField(controller: _anticipoController, decoration: _inputDecoration('Anticipo'), keyboardType: TextInputType.number, onChanged: (_) => _calcularTotales()),
                const SizedBox(height: 8),
                Text('Total: $_total', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Restante: $_restante', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Folio confirmado')));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: const Text('Confirmar Folio', style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
