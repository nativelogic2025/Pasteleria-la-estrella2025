import 'package:flutter/material.dart';
import '../carrito/carrito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class PedidoScreen extends StatefulWidget {
  const PedidoScreen({super.key});

  @override
  State<PedidoScreen> createState() => _PedidoScreenState();
}

class _PedidoScreenState extends State<PedidoScreen> {
  // Form
  final _formKey = GlobalKey<FormState>();

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
  bool _ingredienteExtra = false;
  String? _baseSeleccionada;
  final List<String> _bases = ['Bizcocho', 'Panqué', 'Galleta'];

  final Map<String, bool> _disenos = {
    'Oblea': false,
    'Sin Oblea': false,
    'Normal': false,
    'Crema': false,
  };

  String _saborSeleccionado = '';
  List<String> _sabores = [];

  String? _productoSelId;
  String? _varianteSelId;
  String? _saborSelId;

  List<Map<String, dynamic>> _variantesFiltradas1 = [];
  List<Map<String, dynamic>> _variantesFiltradas2 = [];
  List<Map<String, dynamic>> _variantesSaboresFiltrados = [];
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
      //_productos = await supabase.from('productos').select('''*, categorias!inner(*)''').eq('categorias.nombre', 'Pasteles').order('nombre');
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

  double _total = 0;
  double _restante = 0;

  void _calcularTotales() {
    final deposito = double.tryParse(_depositoController.text) ?? 0;
    final flete = double.tryParse(_fleteController.text) ?? 0;
    final anticipo = double.tryParse(_anticipoController.text) ?? 0;
    setState(() {
      _total = deposito + flete;
      _restante = (_total - anticipo).clamp(0, double.infinity);
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
    _nombreController.dispose();
    _telefonoController.dispose();
    _domicilioController.dispose();
    _depositoController.dispose();
    _fleteController.dispose();
    _anticipoController.dispose();
    _descripcionController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Paleta sobria tipo Google Forms
    const bg = Color(0xFFFAFAFA);
    final divider = DividerThemeData(
      thickness: 1,
      space: 24,
      color: Colors.grey.shade200,
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: Colors.black,
        title: const Text('Pedido'),
        centerTitle: true,
        /*actions: [
          IconButton(
            tooltip: 'Carrito',
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CarritoScreen()),
              );
            },
          ),
        ],*/
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // Encabezado tipo Google Forms
                    _HeaderCard(
                      title: 'Formulario de Pedido',
                      subtitle:
                          'Completa la información del pedido del cliente. Los campos con * son obligatorios.',
                    ),

                    const SizedBox(height: 16),

                    // Sección: Cliente
                    _SectionCard(
                      title: 'Cliente',
                      children: [
                        TextFormField(
                          controller: _nombreController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre *',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telefonoController,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono *',
                            prefixIcon: Icon(Icons.call_outlined),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                        ),
                      ],
                    ),

                    
                    // Sección: Producto
                    _SectionCard(
                      title: 'Producto',
                      children: [
                        SearchAnchor(
                          builder: (BuildContext context, SearchController controller) {
                            // Si ya hay un producto seleccionado, mostramos su nombre en el campo
                            if (_productoSelId != null && controller.text.isEmpty) {
                              final p = _productos.firstWhere((element) => element['id_producto'].toString() == _productoSelId);
                              controller.text = p['nombre'];
                            }

                            return SearchBar(
                              controller: controller,
                              padding: const MaterialStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
                              onTap: () => controller.openView(),
                              onChanged: (_) => controller.openView(),
                              leading: const Icon(Icons.cake_outlined),
                              hintText: 'Buscar producto...',
                              elevation: const MaterialStatePropertyAll<double>(0),
                              backgroundColor: MaterialStatePropertyAll<Color>(Colors.grey.shade100),
                            );
                          },
                          suggestionsBuilder: (BuildContext context, SearchController controller) {
                            // Filtramos la lista según lo que el usuario escribe
                            final String input = controller.value.text.toLowerCase();
                            
                            return _productos
                                .where((p) => p['nombre'].toString().toLowerCase().contains(input))
                                .map((p) => ListTile(
                                      title: Text(p['nombre']),
                                      onTap: () {
                                        setState(() {
                                          _productoSelId = p['id_producto'].toString();
                                          controller.closeView(p['nombre']);
                                          
                                          // Lógica de limpieza y filtrado de variantes que ya tenías
                                          _varianteSelId = null;
                                          _saborSeleccionado = '';
                                          _ingredienteExtra = false;
                                          final vistos = <String>{};

                                          _variantesFiltradas1 = _variantes.where((variante) {
                                            final esMismoProducto = variante['id_producto'].toString() == _productoSelId;
                                            final nombreTamano = variante['tamaño'].toString().trim();
                                            final conIngredienteExtra = variante['tamaño'].toString().contains('Ingrediente Extra');
                                            if (esMismoProducto && !vistos.contains(nombreTamano) && !conIngredienteExtra) {
                                              vistos.add(nombreTamano);
                                              return true;
                                            }
                                            return false;
                                          }).toList();

                                          _variantesFiltradas2 = _variantes.where((variante) {
                                            final esMismoProducto = variante['id_producto'].toString() == _productoSelId;
                                            final nombreTamano = variante['tamaño'].toString().trim();
                                            final conIngredienteExtra = variante['tamaño'].toString().contains('Ingrediente Extra');
                                            if (esMismoProducto && !vistos.contains(nombreTamano) && conIngredienteExtra) {
                                              vistos.add(nombreTamano);
                                              return true;
                                            }
                                            return false;
                                          }).toList();

                                          _sabores = _variantes
                                              .where((variante) => variante['id_producto'].toString() == _productoSelId)
                                              .map((variante) => variante['sabor'].toString())
                                              .toSet() // 👈 Aquí ocurre la magia de la unicidad
                                              .toList();
                                          });                                        
                                      },
                                    ));
                          },
                        ),
                        const SizedBox(height: 12),
                        if(_sabores.length > 1)
                        ...[
                          Text("Tipo de pan *", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _sabores.map((sabor) {
                              // Es "selected" solo si coincide exactamente con nuestra variable única
                              final bool isSelected = _saborSeleccionado == sabor;
                              
                              return FilterChip(
                                selected: isSelected,
                                label: Text(sabor),
                                onSelected: (bool selected) {
                                  setState(() {
                                    if (selected) {
                                      // Si lo selecciona, reemplazamos el valor anterior
                                      _saborSeleccionado = sabor;
                                    } else {
                                      // Si lo deselecciona, podemos dejarlo en null o mantenerlo
                                      _saborSeleccionado = ''; 
                                    }
                                  });
                                },
                                // Estilos de La Estrella
                                shape: StadiumBorder(
                                  side: BorderSide(
                                    color: isSelected ? Colors.black87 : Colors.grey.shade300,
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                selectedColor: Colors.grey.shade200,
                                showCheckmark: true, // Aquí sí conviene el checkmark para indicar opción única
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if(_variantesFiltradas2.isNotEmpty) 
                        ...[
                          Row(
                            children: [
                              Switch(
                                value: _ingredienteExtra,
                                onChanged: (v) => setState(() {
                                  _ingredienteExtra = v; 
                                  _varianteSelId = null;
                                }),
                              ),
                              const SizedBox(width: 8),
                              const Text('Ingrediente extra'),
                              const SizedBox(width: 16),
                              Text(
                                _ingredienteExtra ? 'SI' : 'NO',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        DropdownButtonFormField<String>(
                          value: _varianteSelId,
                          // 1. DESHABILITAR si no hay producto seleccionado o si la lista filtrada está vacía
                          onChanged: (_productoSelId != null && _variantesFiltradas1.isNotEmpty && !_ingredienteExtra) || (_productoSelId != null && _variantesFiltradas2.isNotEmpty && _ingredienteExtra)
                              ? (v) => setState(() {
                              _varianteSelId = v; 
                              //_saborSelId = null; // 👈 CRÍTICO: Limpiar la selección anterior
                              
                              // 1. Creamos un Set vacío CADA VEZ que cambia el producto
                              //final vistos2 = <String>{}; 

                              // 2. Filtramos con limpieza
                              /*_variantesSaboresFiltrados = _variantes.where((variante) {
                                final esMismoProducto = variante['id_producto'].toString() == _productoSelId;
                                // Usamos trim() y toLowerCase() para evitar que "Grande " y "Grande" sean diferentes
                                final sabor = variante['sabor'].toString().trim();
                                
                                if (esMismoProducto && !vistos2.contains(sabor)) {
                                  vistos2.add(sabor);
                                  return true;
                                }
                                return false;
                              }).toList();*/
                            })
                              : null,
                          decoration: InputDecoration(
                            labelText: "Tamaño *",
                            // 2. ERROR VISUAL INMEDIATO: Si hay producto pero no tiene variantes, se pone en rojo
                            errorText: (_productoSelId != null && _variantesFiltradas1.isEmpty && !_ingredienteExtra) || (_productoSelId != null && _variantesFiltradas2.isEmpty && _ingredienteExtra)
                                ? 'Producto sin tamaños disponibles'
                                : null,
                            // 3. TEXTO DE AYUDA DINÁMICO
                            hintText: _productoSelId == null
                                ? 'Elija un producto primero'
                                : (_variantesFiltradas1.isEmpty && !_ingredienteExtra) || (_variantesFiltradas2.isEmpty && _ingredienteExtra)
                                    ? 'Inválido'
                                    : 'Seleccione tamaño',
                          ),
                          items: (_ingredienteExtra ? _variantesFiltradas2 : _variantesFiltradas1).map((v) {
                            return DropdownMenuItem(
                              value: v['id_variante'].toString(),
                              child: Text('${v['tamaño']}', overflow: TextOverflow.ellipsis, maxLines: 1),
                            );
                          }).toList(),
                          // 4. VALIDACIÓN ESTRICTA
                          validator: (v) {
                            if (_productoSelId != null && _variantesFiltradas1.isEmpty) {
                              return 'Cambie el producto';
                            }
                            return v == null ? 'Requerido' : null;
                          },
                        ),
                        /*const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _saborSelId,
                          // 1. DESHABILITAR si no hay producto seleccionado o si la lista filtrada está vacía
                          onChanged: (_varianteSelId != null && _variantesSaboresFiltrados.isNotEmpty)
                              ? (v) => setState(() => _saborSelId = v)
                              : null,
                          decoration: InputDecoration(
                            labelText: "Sabor *",
                            // 2. ERROR VISUAL INMEDIATO: Si hay producto pero no tiene variantes, se pone en rojo
                            errorText: (_varianteSelId != null && _variantesSaboresFiltrados.isEmpty)
                                ? 'Producto sin sabores disponibles'
                                : null,
                            // 3. TEXTO DE AYUDA DINÁMICO
                            hintText: _varianteSelId == null
                                ? 'Elija un producto y tamaño primero'
                                : (_variantesSaboresFiltrados.isEmpty ? 'Inválido' : 'Seleccione sabor'),
                          ),
                          items: _variantesSaboresFiltrados.map((v) {
                            return DropdownMenuItem(
                              value: v['id_variante'].toString(),
                              child: Text('${v['sabor']}', overflow: TextOverflow.ellipsis, maxLines: 1,),
                            );
                          }).toList(),
                          // 4. VALIDACIÓN ESTRICTA
                          validator: (v) {
                            if (_varianteSelId != null && _variantesSaboresFiltrados.isEmpty) {
                              return 'Cambie el tamaño';
                            }
                            return v == null ? 'Requerido' : null;
                          },
                        ),*/
                        /*Row(
                          children: [
                            Switch(
                              value: _doble,
                              onChanged: (v) => setState(() => _doble = v),
                            ),
                            const SizedBox(width: 8),
                            const Text('Doble'),
                            const SizedBox(width: 16),
                            Text(
                              _doble ? 'Seleccionado' : 'Sencillo',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<int>(
                          value: _pisos,
                          items: [1, 2, 3, 4]
                              .map((e) => DropdownMenuItem(
                                  value: e, child: Text(e.toString())))
                              .toList(),
                          onChanged: (val) => setState(() => _pisos = val!),
                          decoration: const InputDecoration(
                            labelText: 'Pisos',
                            prefixIcon: Icon(Icons.layers_outlined),
                          ),
                        ),
                        if (_tamanoSeleccionado == '150') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _baseSeleccionada,
                            items: _bases
                                .map((e) =>
                                    DropdownMenuItem(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _baseSeleccionada = val),
                            decoration: const InputDecoration(
                              labelText: 'Base',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                            ),
                          ),
                        ],*/
                      ],
                    ),

                    // Sección: Diseño del pastel
                    _SectionCard(
                      title: 'Diseño del pastel',
                      children: [
                        /*Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _disenos.keys.map((k) {
                            final selected = _disenos[k] ?? false;
                            return FilterChip(
                              selected: selected,
                              label: Text(k),
                              onSelected: (val) =>
                                  setState(() => _disenos[k] = val),
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: selected
                                      ? Colors.black87
                                      : Colors.grey.shade300,
                                ),
                              ),
                              selectedColor: Colors.grey.shade200,
                              showCheckmark: false,
                            );
                          }).toList(),
                        ),*/
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descripcionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Descripción',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                        ),
                        /*const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _saborSeleccionado,
                          items: _sabores
                              .map((e) =>
                                  DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (val) => setState(() {
                            _saborSeleccionado = val!;
                          }),
                          decoration: const InputDecoration(
                            labelText: 'Sabor',
                            prefixIcon: Icon(Icons.icecream_outlined),
                          ),
                        ),*/
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _mensajeController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Mensaje (en el pastel)',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.edit_note_outlined),
                          ),
                        ),
                      ],
                    ),

                    // Sección: Datos de entrega
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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _domicilioController,
                          decoration: const InputDecoration(
                            labelText: 'Domicilio',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                      ],
                    ),


                    // Sección: Precio
                    _SectionCard(
                      title: 'Precio del pastel',
                      children: [
                        TextFormField(
                          controller: _depositoController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Depósito',
                            prefixIcon: Icon(Icons.attach_money_outlined),
                          ),
                          onChanged: (_) => _calcularTotales(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _fleteController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Flete',
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                          ),
                          onChanged: (_) => _calcularTotales(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _anticipoController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Anticipo',
                            prefixIcon: Icon(Icons.savings_outlined),
                          ),
                          onChanged: (_) => _calcularTotales(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _TotalTile(
                                label: 'Total',
                                value: _total,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TotalTile(
                                label: 'Restante',
                                value: _restante,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'El restante se calcula como Total - Anticipo.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Botón final, ancho completo (Google Forms style)
                    SizedBox(
                      height: 52,
                      child: FilledButton.tonal(
                        style: ButtonStyle(
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          backgroundColor: WidgetStatePropertyAll(Colors.black),
                          foregroundColor:
                              const WidgetStatePropertyAll(Colors.white),
                        ),
                        onPressed: () {
                          if (_formKey.currentState?.validate() ?? false) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Folio confirmado')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Revisa los campos obligatorios')),
                            );
                          }
                        },
                        child: const Text('Confirmar Folio'),
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
}

/// Card de encabezado estilo Google Forms (título + descripción)
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
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(color: Colors.grey.shade700, height: 1.25),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card genérica para secciones (como “preguntas” de Google Forms)
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
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
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

/// Mini “tile” para totales (Total / Restante)
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
