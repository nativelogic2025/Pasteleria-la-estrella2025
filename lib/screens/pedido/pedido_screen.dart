import 'package:flutter/material.dart';
import 'package:pos_pasteleria_la_estrella/screens/ventas/producto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import './resumen_pedido.dart';

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
  final _fleteController = TextEditingController();
  final _anticipoController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _mensajeController = TextEditingController();
  final _otrosCargosController = TextEditingController();
  final SearchController _productoSearchController = SearchController();

  DateTime? _fechaEntrega;
  TimeOfDay? _horaEntrega;
  String? _categoriaProductoSel;
  String? _productoSelId;
  String? _varianteSelId;

  // Valores por defecto
  double _total = 0;
  double _restante = 0;
  double _subtotal = 0;

  // Producto
  bool _ingredienteExtra = false;
  bool _tipoEntrega = false; // false = recogida, true = entrega a domicilio

  // Seleccion por defecto
  String _saborSeleccionado = '';
  String _armadoSeleccionado = 'Sensillo';
  String _disenoSeleccionado = 'Norma (Crema/Betún)';
  String _pisoSeleccionado = '1 Piso';

  List<String> _sabores = [];
  List<Map<String, dynamic>> _variantesFiltradas1 = [];
  List<Map<String, dynamic>> _variantesFiltradas2 = [];
  List<Map<String, dynamic>> _variantes = [];
  List<Map<String, dynamic>> _productos = [];
  bool _cargando = true;

  // Listas Estaticas CORREGIR DB
  final List<String> _armadosList = ['Sensillo', 'Doble'];
  final List<String> _pisosList = ['1 Piso', '2 Pisos', '3 Pisos', '4 Pisos'];
  final List<String> _disenoList = ['Norma (Crema/Betún)', 'Con Oblea Comestible'];
  // Fin de Listas Estáticas

  @override
  void initState() {
    super.initState();
    _inicializar();
    _nombreController.text = '';
    _telefonoController.text = '';
    _domicilioController.text = '';

    _otrosCargosController.text = '0.00';
    _fleteController.text = '0.00';
    _anticipoController.text = '0.00';
  }

  Future<void> _inicializar() async {
    setState(() => _cargando = true);
    try {
      _variantes = await supabase.from('producto_variantes').select('*').order('tamaño');
      _productos = await supabase.from('productos').select('''*, categorias!inner(*)''').neq('categorias.nombre', 'Velas').order('nombre');
      //_productos = await supabase.from('productos').select('''*, categorias(*)''').order('nombre');
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

  void _calcularTotales() {
    _subtotal = _calcularSubtotal();
    final otrosCargos = double.tryParse(_otrosCargosController.text) ?? 0;
    final flete = double.tryParse(_fleteController.text) ?? 0;
    final anticipo = double.tryParse(_anticipoController.text) ?? 0;
    setState(() {
      _total = _subtotal + otrosCargos + flete;
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

  void _verificarSeleccionAutomatica() {
  // 1. Identificamos qué lista estamos usando actualmente
  final listaActual = _ingredienteExtra ? _variantesFiltradas2 : _variantesFiltradas1;

  // 2. Si la lista tiene EXACTAMENTE un elemento, lo seleccionamos
  if (listaActual.length == 1) {
    setState(() {
      _varianteSelId = listaActual.first['id_variante'].toString();
      _calcularTotales(); // Recalculamos totales y subtotal al seleccionar automáticamente la única variante disponible
    });
  } else {
    // Si hay más de una (o ninguna), mejor resetear para que el usuario elija
    setState(() {
      _varianteSelId = null;
      _calcularTotales(); // Recalculamos totales y subtotal al resetear la selección automática
    });
  }
}

  double _calcularSubtotal() {
    double precioBase = 0;

    if (_varianteSelId == null) return precioBase;
    final variante = _variantes.firstWhere((v) => v['id_variante'].toString() == _varianteSelId);
    precioBase = double.tryParse(variante['precio_venta'].toString()) ?? 0; // Precio base según la variante seleccionada

    // Ajustes adicionales según configuraciones exclusivas de pasteles
    if (_armadoSeleccionado == 'Doble') {
      precioBase += 150; // Costo adicional por armado doble
    }

    if (_pisoSeleccionado == '2 Pisos') {
      precioBase += 200; // Costo adicional por 2 pisos
    } else if (_pisoSeleccionado == '3 Pisos') {
      precioBase += 400; // Costo adicional por 3 pisos
    } else if (_pisoSeleccionado == '4 Pisos') {
      precioBase += 600; // Costo adicional por 4 pisos
    }

    return precioBase;
  }

  void _filtrarVariantes(){
    final vistos = <String>{};
    
    // Filtramos variantes en dos listas: una sin ingrediente extra y otra con ingrediente extra, ambas basadas en el producto seleccionado y el sabor (si aplica)
    _variantesFiltradas1 = _variantes.where((variante) {
      final esMismoProducto = variante['id_producto'].toString() == _productoSelId;
      final nombreTamano = variante['tamaño'].toString().trim();
      final conIngredienteExtra = variante['tamaño'].toString().contains('Ingrediente Extra');
      final TipoPan = variante['sabor'].toString().contains(_saborSeleccionado);
      if (esMismoProducto && TipoPan && !vistos.contains(nombreTamano) && !conIngredienteExtra) {
        vistos.add(nombreTamano);
        return true;
      }
      return false;
    }).toList();

    _variantesFiltradas2 = _variantes.where((variante) {
      final esMismoProducto = variante['id_producto'].toString() == _productoSelId;
      final nombreTamano = variante['tamaño'].toString().trim();
      final conIngredienteExtra = variante['tamaño'].toString().contains('Ingrediente Extra');
      final TipoPan = variante['sabor'].toString().contains(_saborSeleccionado);
      if (esMismoProducto && TipoPan && !vistos.contains(nombreTamano) && conIngredienteExtra) {
        vistos.add(nombreTamano);
        return true;
      }
      return false;
    }).toList();
  }

  void _limpiarFormulario() {
    setState(() {
      // 1. Limpiamos los controladores de texto
      _nombreController.clear();
      _telefonoController.clear();
      _domicilioController.clear();
      _fleteController.clear();
      _anticipoController.clear();
      _descripcionController.clear();
      _mensajeController.clear();
      _otrosCargosController.clear();
      _productoSearchController.clear();

      // 2. Reiniciamos variables y selecciones
      _productoSelId = null;
      _varianteSelId = null;
      _categoriaProductoSel = null;
      _subtotal = 0;
      _restante = 0;
      _total = 0;  
      _saborSeleccionado = '';
      _armadoSeleccionado = 'Sensillo';
      _disenoSeleccionado = 'Norma (Crema/Betún)';
      _pisoSeleccionado = '1 Piso';
      _ingredienteExtra = false;
      _tipoEntrega = false;
      _fechaEntrega = null;
      _horaEntrega = null;
      _sabores = [];
      _variantesFiltradas1 = [];
      _variantesFiltradas2 = [];
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _domicilioController.dispose();
    _fleteController.dispose();
    _anticipoController.dispose();
    _descripcionController.dispose();
    _mensajeController.dispose();
    _otrosCargosController.dispose();
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
                child: SingleChildScrollView(
                  child: Column(
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
                        FormField<String>(
                        // 1. Aquí validamos si se seleccionó un producto
                        validator: (_) {
                          if (_productoSelId == null || _productoSelId!.isEmpty) {
                            return 'Por favor selecciona un producto';
                          }
                          return null;
                        },
                        builder: (FormFieldState<String> state) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                SearchAnchor(
                                  searchController: _productoSearchController,
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
                                      hintText: '* Buscar producto...',
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
                                                  _categoriaProductoSel = p['categorias']['nombre'].toString();
                                                  _calcularTotales(); // Recalculamos totales y subtotal al cambiar de producto
                                                  controller.closeView(p['nombre']);
                                                  
                                                  // Lógica de limpieza y filtrado de variantes que ya tenías
                                                  _varianteSelId = null;
                                                  _saborSeleccionado = '';
                                                  _disenoSeleccionado = 'Norma (Crema/Betún)';
                                                  _armadoSeleccionado = 'Sensillo';
                                                  _pisoSeleccionado = '1 Piso';
                                                  _ingredienteExtra = false;
                                                  

                                                  // Filtramos variantes en dos listas: una sin ingrediente extra y otra con ingrediente extra, ambas basadas en el producto seleccionado y el sabor (si aplica)
                                                  _filtrarVariantes();

                                                  _sabores = _variantes
                                                      .where((variante) => variante['id_producto'].toString() == _productoSelId)
                                                      .map((variante) => variante['sabor'].toString())
                                                      .toSet() // 👈 Aquí ocurre la magia de la unicidad
                                                      .toList();
                                                  });

                                                  _verificarSeleccionAutomatica(); // Verificamos si hay que seleccionar automáticamente la variante por tener solo una opción                                      
                                              },
                                            ));
                                  },
                                ),
                                // 3. La Retroalimentación Visual (El mensaje de error)
                                if (state.hasError)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8, left: 16),
                                    child: Text(
                                      state.errorText!, // Aquí dirá "Por favor selecciona un producto"
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.error, // Rojo estándar de errores
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        if(_sabores.length > 1)
                        ...[
                          Text("Tipo de pan *", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                          FormField<String>(
                          // 1. Aquí validamos si se seleccionó un producto
                          validator: (_) {
                            if (_saborSeleccionado.isEmpty) {
                              return 'Por favor selecciona un sabor';
                            }
                            return null;
                          },
                          builder: (FormFieldState<String> state) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                              _varianteSelId = null; // Limpiamos la selección de variante al cambiar el sabor, ya que las variantes dependen del sabor
                                              _filtrarVariantes(); // Volvemos a filtrar variantes al cambiar el sabor, ya que algunas variantes pueden depender del sabor
                                              _calcularTotales(); // Recalculamos totales y subtotal al cambiar sabor
                                            } else {
                                              // Si lo deselecciona, podemos dejarlo en null o mantenerlo
                                              _saborSeleccionado = '';
                                              _varianteSelId = null; // Limpiamos la selección de variante al cambiar el sabor, ya que las variantes dependen del sabor
                                              _filtrarVariantes(); // Volvemos a filtrar variantes al cambiar el sabor, ya que algunas variantes pueden depender del sabor
                                              _calcularTotales(); // Recalculamos totales y subtotal al cambiar sabor
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
                                  // 3. La Retroalimentación Visual (El mensaje de error)
                                  if (state.hasError)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, left: 16),
                                      child: Text(
                                        state.errorText!, // Aquí dirá "Por favor selecciona un producto"
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.error, // Rojo estándar de errores
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
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
                                  _subtotal = 0; // Reiniciamos subtotal al cambiar de ingrediente extra
                                  _verificarSeleccionAutomatica(); // Verificamos si hay que seleccionar automáticamente la variante
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
                          onChanged: _sabores.length > 1 && _saborSeleccionado.isEmpty ? null : (_productoSelId != null && _variantesFiltradas1.isNotEmpty && !_ingredienteExtra) || (_productoSelId != null && _variantesFiltradas2.isNotEmpty && _ingredienteExtra)
                              ? (v) => setState(() {
                              _varianteSelId = v;
                              _calcularTotales(); // Recalculamos totales y subtotal al cambiar de variante
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
                            if (_productoSelId != null && _variantesFiltradas1.isEmpty && _variantesFiltradas2.isEmpty) {
                              return 'Cambie el producto';
                            }
                            return v == null ? 'Requerido' : null;
                          },
                        ),
                      ],
                    ),

                    // Sección:  Exclusivo pasteles
                    if(_categoriaProductoSel == 'Pasteles')
                    _SectionCard(
                      title: 'Configuración Exclusiva del Pastel ',
                      children: [
                        Text("Armado *", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _armadosList.map((armado) {
                            // Es "selected" solo si coincide exactamente con nuestra variable única
                            final bool isSelected = _armadoSeleccionado == armado;
                            
                            return FilterChip(
                              selected: isSelected,
                              label: Text(armado),
                              onSelected: (bool selected) {
                                setState(() {
                                  if (selected) {
                                    // Si lo selecciona, reemplazamos el valor anterior
                                    _armadoSeleccionado = armado;
                                    _calcularTotales(); // Recalculamos totales y subtotal al cambiar armado
                                  } else {
                                    // Si lo deselecciona, podemos dejarlo en null o mantenerlo
                                    _armadoSeleccionado = 'Sensillo';
                                    _calcularTotales(); // Recalculamos totales y subtotal al cambiar armado
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
                        Text("Pisos *", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _pisosList.map((piso) {
                            // Es "selected" solo si coincide exactamente con nuestra variable única
                            final bool isSelected = _pisoSeleccionado == piso;
                            
                            return FilterChip(
                              selected: isSelected,
                              label: Text(piso),
                              onSelected: (bool selected) {
                                setState(() {
                                  if (selected) {
                                    // Si lo selecciona, reemplazamos el valor anterior
                                    _pisoSeleccionado = piso;
                                    _calcularTotales(); // Recalculamos totales al cambiar piso
                                  } else {
                                    // Si lo deselecciona, podemos dejarlo en null o mantenerlo
                                    _pisoSeleccionado = '1 Piso';
                                    _calcularTotales(); // Recalculamos totales al cambiar piso
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
                        Text("Diseño Principal *", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _disenoList.map((diseno) {
                            // Es "selected" solo si coincide exactamente con nuestra variable única
                            final bool isSelected = _disenoSeleccionado == diseno;
                            
                            return FilterChip(
                              selected: isSelected,
                              label: Text(diseno),
                              onSelected: (bool selected) {
                                setState(() {
                                  if (selected) {
                                    // Si lo selecciona, reemplazamos el valor anterior
                                    _disenoSeleccionado = diseno;
                                  } else {
                                    // Si lo deselecciona, podemos dejarlo en null o mantenerlo
                                    _disenoSeleccionado = ''; 
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
                      ],
                    ),

                    // Sección: Diseño Perzonalizado (puede ser para cualquier producto, pero es más común en pasteles)
                    _SectionCard(
                      title: 'Diseño Personalizado',
                      children: [
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _mensajeController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Mensaje o Dedicatoria Corta (Opcional)',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.edit_note_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descripcionController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notas / Instrucciones Adicionales (Opcional)',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_outlined),
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
                        Row(
                          children: [
                            Switch(
                              value: _tipoEntrega,
                              onChanged: (v) => setState(() {
                                _tipoEntrega = v;
                              }),
                            ),
                            const SizedBox(width: 8),
                            const Text('Entrega en'),
                            const SizedBox(width: 16),
                            Text(
                              _tipoEntrega ? 'DOMICILIO' : 'ESTÁ SUCURSAL',
                              style: TextStyle(color: const Color.fromARGB(255, 182, 108, 225)),
                            ),
                          ],
                        ),
                        if(_tipoEntrega)
                        ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _domicilioController,
                            decoration: const InputDecoration(
                              labelText: 'Domicilio',
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                            validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          ),
                        ],
                      ],
                    ),

                    // Sección: Precio
                    _SectionCard(
                      title: 'Precio del pastel',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _TotalTile(
                                label: 'Subtotal \$',
                                value: _subtotal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _otrosCargosController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Otros cargos',
                            prefixIcon: Icon(Icons.attach_money_outlined),
                          ),
                          onChanged: (_) => _calcularTotales(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _fleteController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Flete *',
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                          ),
                          onChanged: (_) => _calcularTotales(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _anticipoController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Anticipo *',
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
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            // 1. Recolectamos la información de los controladores
                            final datos = {
                              'cliente': _nombreController.text.trim(),
                              'telefono': _telefonoController.text.trim(),
                              'nombre_producto': _productos.firstWhere((p) => p['id_producto'].toString() == _productoSelId)['nombre'],
                              'tamaño': _variantes.firstWhere((v) => v['id_variante'].toString() == _varianteSelId)['tamaño'],
                              'flete': double.tryParse(_fleteController.text.trim()) ?? 0.0,
                              'armado': _armadoSeleccionado,
                              'piso': _pisoSeleccionado,
                              'diseno': _disenoSeleccionado,
                              'categoria': _categoriaProductoSel,
                              'direccion': _domicilioController.text.trim(),
                            };

                            final nuevoPedido = {
                              // tabla pedidos
                              //'id_pedido': '', //db
                              //'folio': '', // db 
                              'id_direccion': null, // mal formulado
                              //'fecha_pedido': '', // current datetime
                              // 1. Extraemos solo la parte de la fecha (YYYY-MM-DD)
                              'fecha_entrega': _fechaEntrega != null 
                                  ? _fechaEntrega!.toIso8601String().split('T')[0] 
                                  : null, // 👈 Importante usar null en vez de ''
                              // 2. Armamos la hora en formato 24h (HH:MM:00)
                              'hora_entrega': _horaEntrega != null 
                                  ? "${_horaEntrega!.hour.toString().padLeft(2, '0')}:${_horaEntrega!.minute.toString().padLeft(2, '0')}:00"
                                  : null,
                              'tipo_entrega': _tipoEntrega ? 'domicilio' : 'sucursal',
                              //'estado': 'pendiente', // por defecto sería "pendiente" al crear un nuevo pedido
                              'origen': 'sucursal', // dependiendo de dónde se esté creando el pedido
                              'tipo_pedido': 'normal', // inecesario
                              'subtotal': _subtotal, // solo de productos, sin cargos adicionales
                              'descuento': double.tryParse(_otrosCargosController.text.trim()) ?? 0.0, // en este caso, usamos el campo de "otros cargos" para reflejar descuentos o cargos adicionales, dependiendo de si el valor es positivo o negativo cambiar si no
                              'total': _total,
                              'anticipo': double.tryParse(_anticipoController.text.trim()) ?? 0.0,
                              'restante': _restante,
                              'observaciones': 'Domicilio: ${_domicilioController.text.trim()} - Cliente: ${_nombreController.text.trim()} - Teléfono: ${_telefonoController.text.trim()}',
                              'id_usuario': null, // depende de quien crea el pedido
                            };

                            final nuevoPedidoDetalles = {
                                // tabla detalle_pedidos
                                //'id_detalle': '', //db
                                //'id_pedido': respuesta['id_pedido'], //db anterior
                                'id_variante': _varianteSelId ?? '',
                                'cantidad': '1',
                                'precio_unitario': _subtotal, // el subtotal refleja el precio del producto seleccionado sin cargos adicionales, por lo que es un buen candidato para ser el precio unitario en el detalle
                                'sabor': _saborSeleccionado,
                                'dedicatoria': _mensajeController.text.trim(),
                                'observaciones': _descripcionController.text.trim(),
                              };

                            //Abrir el modal de resumen con los datos actuales (sin folio ni nombre de producto, ya que eso se genera al guardar en la base de datos)
                            mostrarModalResumen(
                              context: context,
                              datos: datos,
                              pedido: nuevoPedido,
                              pedido_detalle: nuevoPedidoDetalles,
                              alTerminar: _limpiarFormulario,
                            );

                            /*ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Folio confirmado')),
                            );*/
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Revisa los campos obligatorios')),
                            );
                          }
                        },
                        child: const Text('Resumen del Pedido'),
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