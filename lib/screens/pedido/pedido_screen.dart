import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './resumen_pedido.dart';
import 'package:flutter_animate/flutter_animate.dart';

final _supabase = Supabase.instance.client;

// ─────── COLORES ────────────────────────────
const _cPrimary   = Color(0xFF8C5535);
const _cSecondary = Color(0xFFD4956A);
const _cBg        = Color(0xFFFAFAFA);
const _cSurface   = Color(0xFFFCF5EE);
const _cCard      = Color(0xFFFDFAF6);
const _cBorder    = Color(0xFFE5CEB3);
const _cBorderSoft= Color(0xFFFAE8D4);

// ─────── ICONS POR CATEGORÍA ────────────────
IconData _iconForCategory(String nombre) {
  final n = nombre.toLowerCase();
  if (n.contains('pastel'))  return Icons.cake;
  if (n.contains('cupcake')) return Icons.bakery_dining;
  if (n.contains('gelatina'))return Icons.water_drop;
  if (n.contains('galleta')) return Icons.cookie;
  if (n.contains('vela'))    return Icons.local_fire_department;
  if (n.contains('postre'))  return Icons.icecream;
  if (n.contains('oblea') || n.contains('transfer')) return Icons.branding_watermark;
  return Icons.restaurant;
}

// ─────── WIDGET ─────────────────────────────
class PedidoScreen extends StatefulWidget {
  const PedidoScreen({super.key});
  @override
  State<PedidoScreen> createState() => _PedidoScreenState();
}

class _PedidoScreenState extends State<PedidoScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _nombreCtrl      = TextEditingController();
  final _telCtrl         = TextEditingController();
  final _domCtrl         = TextEditingController();
  final _cpCtrl          = TextEditingController();
  final _coloniaCtrl     = TextEditingController();
  final _fleteCtrl       = TextEditingController(text: '0.00');
  final _anticipoCtrl    = TextEditingController(text: '0.00');
  final _descCtrl        = TextEditingController();
  final _msgCtrl         = TextEditingController();
  final _otrosCtrl       = TextEditingController(text: '0.00');

  // Wizard
  int  _step = 1;
  String?               _catNombre;
  Map<String, dynamic>? _productoSel;
  String?               _saborSel;
  Map<String, dynamic>? _varianteSel;
  int _cantidad = 1;
  double _precioUnitario = 0;

  // Opciones pastel
  String _armado = 'Sencillo';
  String _diseno = 'Normal (Crema/Betún)';
  String _pisos  = '1 Piso';

  // Entrega
  bool       _domicilio = false;
  DateTime?  _fecha;
  TimeOfDay? _hora;

  // Extra
  bool _extra = false;
  bool _anticipoManual = false;

  // BD
  List<Map<String,dynamic>> _productos = [];
  List<Map<String,dynamic>> _variantes = [];   // variantes del producto seleccionado
  List<String> _listaSabores = []; // sabores únicos del producto
  bool _cargando = true;
  bool _cargandoVariantes = false;

  // Totales
  double _subtotal = 0, _total = 0, _restante = 0;

  // Listas estáticas
  final _armadoList = const ['Sencillo','Doble'];
  final _pisosList  = const ['1 Piso','2 Pisos','3 Pisos','4 Pisos'];
  final _disenoList = const ['Normal (Crema/Betún)','Con Oblea Comestible'];

  // ── Derivados ───────────────────────────────
  Map<String,List<Map<String,dynamic>>> get _cats {
    final m = <String,List<Map<String,dynamic>>>{};
    for (final p in _productos) {
      final c = p['categorias']?['nombre']?.toString() ?? 'General';
      m.putIfAbsent(c, ()=>[]).add(p);
    }
    return m;
  }

  List<Map<String,dynamic>> get _prodsDecat => _cats[_catNombre] ?? [];

  bool get _esPastel => (_catNombre ?? '').toLowerCase().contains('pastel');

  // _variantes solo contiene las del producto seleccionado (deduplicadas por tamaño)
  List<String> get _saboresDisponibles {
    if (_productoSel == null || _listaSabores.isEmpty) return [];
    return _listaSabores;
  }

  List<Map<String,dynamic>> get _variantesFiltradas {
    if (_productoSel == null) return [];
    return _variantes.where((v) {
      final n = (v['tamaño'] ?? '').toString().toLowerCase();
      final esExtra = n.contains('ingrediente extra') || n.contains('especial');
      return _extra ? esExtra : !esExtra;
    }).toList();
  }

  bool get _hayExtra => _variantes.any((v) {
    final n = (v['tamaño'] ?? '').toString().toLowerCase();
    return n.contains('ingrediente extra') || n.contains('especial');
  });

  // ── Imagen producto ──────────────────────────
  String? _imgUrl(Map<String,dynamic> prod) {
    final f = prod['imagen_url'];
    if (f == null || f.toString().isEmpty) return null;
    return _supabase.storage.from('productos').getPublicUrl(f.toString());
  }

  // ── Init ────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _telCtrl.dispose(); _domCtrl.dispose();
    _cpCtrl.dispose(); _coloniaCtrl.dispose();
    _fleteCtrl.dispose();  _anticipoCtrl.dispose(); _descCtrl.dispose();
    _msgCtrl.dispose();    _otrosCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(()=>_cargando=true);
    try {
      // Solo cargamos productos; las variantes se cargan bajo demanda
      _productos = await _supabase.from('productos')
          .select('*, categorias!inner(*)')
          .order('nombre');
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(()=>_cargando=false);
    }
  }

  /// Carga variantes de un producto específico y deduplica por tamaño (suma stock)
  Future<void> _cargarVariantesProducto(dynamic idProducto) async {
    if (!mounted) return;
    setState(()=>_cargandoVariantes=true);
    try {
      final List<Map<String,dynamic>> res = await _supabase
          .from('producto_variantes')
          .select('id_variante, id_producto, stock, sabor, tamaño, precio_venta')
          .eq('id_producto', idProducto)
          .order('precio_venta', ascending: true);

      // Extraer todos los sabores únicos antes de deduplicar
      final Set<String> saboresSet = {};
      for (final v in res) {
        final saborStr = (v['sabor'] ?? 'Único').toString().trim();
        if (saborStr.isNotEmpty) {
          saboresSet.add(saborStr);
        }
      }
      if (saboresSet.isEmpty) saboresSet.add('Único');

      // Deduplicar por tamaño sumando stock (igual que en ventas_pasteles.dart)
      final Map<String, Map<String,dynamic>> unicos = {};
      for (final v in res) {
        final tamano = (v["tamaño"] ?? "").toString().trim();
        if (unicos.containsKey(tamano)) {
          final sa = (unicos[tamano]!['stock'] as num?)?.toInt() ?? 0;
          final sn = (v['stock'] as num?)?.toInt() ?? 0;
          unicos[tamano]!['stock'] = sa + sn;
        } else {
          unicos[tamano] = Map<String,dynamic>.from(v);
        }
      }

      final lista = unicos.values.toList();
      lista.sort((a,b) =>
          ((a['precio_venta'] as num?)?.toDouble() ?? 0)
          .compareTo((b['precio_venta'] as num?)?.toDouble() ?? 0));

      if (mounted) setState((){
        _listaSabores = saboresSet.toList();
        _variantes = lista;
        _cargandoVariantes = false;
      });
    } catch(e) {
      if (mounted) {
        setState(()=>_cargandoVariantes=false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar tamaños: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _evaluarFlete() {
    if (!_domicilio) {
      _fleteCtrl.text = '0.00';
      return;
    }
    bool envioGratis = false;
    if (_esPastel && _varianteSel != null) {
      final String tamanoStr = (_varianteSel!['tamaño'] ?? '').toString();
      final match = RegExp(r'\d+').firstMatch(tamanoStr);
      if (match != null) {
        int personas = int.tryParse(match.group(0) ?? '0') ?? 0;
        if (personas >= 80) envioGratis = true;
      }
    }
    _fleteCtrl.text = envioGratis ? '0.00' : '75.00';
  }

  // ── Cálculos ────────────────────────────────
  void _calcular() {
    double base = 0;
    if (_varianteSel != null) {
      base = double.tryParse(_varianteSel!['precio_venta'].toString()) ?? 0;
      if (_armado == 'Doble')     base += 150;
      if (_pisos  == '2 Pisos')   base += 200;
      if (_pisos  == '3 Pisos')   base += 400;
      if (_pisos  == '4 Pisos')   base += 600;
    }
    _precioUnitario = base;
    final otros    = double.tryParse(_otrosCtrl.text)   ?? 0;
    final flete    = double.tryParse(_fleteCtrl.text)   ?? 0;
    
    setState((){
      _subtotal = _precioUnitario * _cantidad;
      _total    = _subtotal + otros + flete;
      
      double anticipoVal = 0;
      if (!_anticipoManual && _total > 0) {
        anticipoVal = _total * 0.5;
        _anticipoCtrl.text = anticipoVal.toStringAsFixed(2);
      } else {
        anticipoVal = double.tryParse(_anticipoCtrl.text) ?? 0;
      }
      
      _restante = (_total - anticipoVal).clamp(0, double.infinity);
    });
  }

  // ── Fecha/Hora ──────────────────────────────
  Future<void> _pickFecha() async {
    final f = await showDatePicker(
      context: context,
      initialDate: _fecha ?? DateTime.now(),
      firstDate: DateTime.now(), lastDate: DateTime(2100),
    );
    if (f != null) setState(()=>_fecha=f);
  }

  Future<void> _pickHora() async {
    final h = await showTimePicker(
      context: context,
      initialTime: _hora ?? TimeOfDay.now(),
    );
    if (h != null) setState(()=>_hora=h);
  }

  // ── Wizard ──────────────────────────────────
  void _elegirCat(String nombre) => setState((){
    _catNombre=nombre; _productoSel=null; _saborSel=null; _varianteSel=null;
    _subtotal=_total=_restante=0; _step=2;
  });

  void _elegirProducto(Map<String,dynamic> p) {
    setState((){
      _productoSel=p; _saborSel=null; _varianteSel=null; _extra=false;
      _subtotal=_total=_restante=0;
      _variantes=[]; // limpiamos mientras cargan las nuevas
      _listaSabores=[];
      _step=2; // mostramos el paso 2 activo mientras cargamos
    });
    // Carga async: cuando termine determinamos si ir al paso 3 o 4
    _cargarVariantesProducto(p['id_producto']).then((_) {
      if (!mounted) return;
      final sabores = _listaSabores;
      setState((){
        _step = sabores.length == 1 ? 4 : 3;
        if (sabores.length == 1) _saborSel = sabores.first;
      });
    });
  }

  void _elegirSabor(String s) => setState((){
    _saborSel=s; _varianteSel=null; _step=4;
  });

  void _elegirVariante(Map<String,dynamic> v) => setState((){
    _varianteSel=v; _evaluarFlete(); _calcular();
  });

  void _resetStep(int s) => setState((){
    if (s<=1){_catNombre=null;}
    if (s<=2){_productoSel=null;}
    if (s<=3){_saborSel=null;}
    if (s<=4){_varianteSel=null; _subtotal=_total=_restante=0;}
    _step=s;
  });

  void _limpiar() => setState((){
    _nombreCtrl.clear(); _telCtrl.clear(); _domCtrl.clear();
    _cpCtrl.clear(); _coloniaCtrl.clear();
    _fleteCtrl.text='0.00'; _anticipoCtrl.text='0.00';
    _descCtrl.clear(); _msgCtrl.clear(); _otrosCtrl.text='0.00';
    _catNombre=null; _productoSel=null; _saborSel=null; _varianteSel=null;
    _step=1; _domicilio=false; _extra=false; _cantidad=1; _precioUnitario=0;
    _armado='Sencillo'; _diseno='Normal (Crema/Betún)'; _pisos='1 Piso';
    _fecha=null; _hora=null; _subtotal=_total=_restante=0;
    _anticipoManual=false;
    _listaSabores=[];
  });

  // ── Confirmar ────────────────────────────────
  void _confirmar() {
    if (_productoSel==null||_varianteSel==null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Completa los pasos del wizard primero.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (_saboresDisponibles.length > 1 && _saborSel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Por favor elige un tipo de pan/sabor.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los campos obligatorios.')));
      return;
    }

    if (_domicilio) {
      final cp = _cpCtrl.text.trim();
      if (!cp.startsWith('438')) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lo sentimos. Solo entregamos a domicilio dentro de Tizayuca, Hidalgo (C.P. 438XX).'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ));
        return;
      }
    }

    final datos = {
      'cliente':         _nombreCtrl.text.trim(),
      'telefono':        _telCtrl.text.trim(),
      'nombre_producto': _productoSel!['nombre'].toString(),
      'tamaño':          _varianteSel!['tamaño'].toString(),
      'flete':           double.tryParse(_fleteCtrl.text) ?? 0.0,
      'armado':          _armado,
      'piso':            _pisos,
      'diseno':          _diseno,
      'categoria':       _catNombre ?? '',
      'direccion':       _domicilio ? 'C.P: ${_cpCtrl.text.trim()}, Col: ${_coloniaCtrl.text.trim()}, Dom: ${_domCtrl.text.trim()}' : '',
    };

    final pedido = {
      'id_direccion': null,
      'fecha_entrega': _fecha?.toIso8601String().split('T')[0],
      'hora_entrega':  _hora != null
          ? '${_hora!.hour.toString().padLeft(2,'0')}:${_hora!.minute.toString().padLeft(2,'0')}:00'
          : null,
      'tipo_entrega':  _domicilio ? 'domicilio' : 'sucursal',
      'origen':        'sucursal',
      'tipo_pedido':   'normal',
      'subtotal':      _subtotal,
      'descuento':     double.tryParse(_otrosCtrl.text) ?? 0.0,
      'total':         _total,
      'anticipo':      double.tryParse(_anticipoCtrl.text) ?? 0.0,
      'restante':      _restante,
      'observaciones': _domicilio ? 'Dom: ${_domCtrl.text.trim()} - Col: ${_coloniaCtrl.text.trim()} - CP: ${_cpCtrl.text.trim()} - Cliente: ${_nombreCtrl.text.trim()} - Tel: ${_telCtrl.text.trim()}' : 'Cliente: ${_nombreCtrl.text.trim()} - Tel: ${_telCtrl.text.trim()}',
      'id_usuario':    null,
    };

    final detalles = {
      'id_variante':    _varianteSel!['id_variante'],
      'cantidad':       _cantidad,
      'precio_unitario':_precioUnitario,
      'sabor':          _saborSel ?? '',
      'dedicatoria':    _msgCtrl.text.trim(),
      'observaciones':  _descCtrl.text.trim(),
    };

    mostrarModalResumen(
      context: context,
      datos: datos,
      pedido: pedido,
      pedido_detalle: detalles,
      alTerminar: _limpiar,
    );
  }

  // ════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _cBg,
        foregroundColor: Colors.black87,
        title: const Text('Nuevo Pedido', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: _cPrimary))
          : Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final isWide = constraints.maxWidth >= 800;
                  return isWide
                      ? _buildWideLayout()
                      : _buildNarrowLayout();
                },
              ),
            ),
    );
  }

  // ── Layout ANCHO (≥800px) ───────────────────
  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna izquierda – Formulario scrollable
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 32),
            child: _buildFormContent(),
          ),
        ),
        // Columna derecha – Sidebar fijo
        SizedBox(
          width: 360,
          child: _buildSidebar(sticky: true),
        ),
      ],
    );
  }

  // ── Layout NARROW (<800px) ──────────────────
  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        children: [
          _buildFormContent(),
          const SizedBox(height: 16),
          _buildSidebar(sticky: false),
        ],
      ),
    );
  }

  // ── FORMULARIO IZQUIERDO ────────────────────
  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── CLIENTE (ARRIBA DE TODO) ────────────
        _sectionTitle('Datos del Cliente', Icons.person_outline),
        const SizedBox(height: 10),
        _card(Column(children: [
          _field(_nombreCtrl, 'Nombre del Cliente *', Icons.person_outline,
              validator: _req),
          const SizedBox(height: 12),
          _field(_telCtrl, 'Teléfono *', Icons.call_outlined,
              keyboardType: TextInputType.phone, validator: _req),
        ])),

        const SizedBox(height: 20),

        // ── WIZARD ─────────────────────────────
        _sectionTitle('Configura tu Pedido', Icons.tune),
        const SizedBox(height: 10),

        _wizardStep(1, '¿Qué tipo de antojo?',       _buildCatGrid(),      _catNombre,     ()=>_resetStep(1)),
        _wizardStep(2, 'Elige tu Producto',            _buildProdGrid(),     _productoSel?['nombre']?.toString(), ()=>_resetStep(2)),
        if (_step >= 3 && _saboresDisponibles.length > 1)
          _wizardStep(3, 'Tipo de Pan',               _buildSaborGrid(),    _saborSel,      ()=>_resetStep(3)),
        _wizardStep(4, '¿De qué tamaño será?',        _buildVarianteGrid(), _varianteSel?['tamaño']?.toString(), ()=>_resetStep(4)),

        // ── CONFIG PASTEL ───────────────────────
        if (_esPastel && _productoSel != null) ...[
          const SizedBox(height: 8),
          _buildConfigPastel(),
        ],

        const SizedBox(height: 20),

        // ── MENSAJE ─────────────────────────────
        _sectionTitle('Mensaje y Decoración', Icons.edit_note),
        const SizedBox(height: 10),
        _card(Column(children: [
          _field(_msgCtrl,  'Dedicatoria / Mensaje (Opcional)', Icons.favorite_border, maxLength: 50),
          const SizedBox(height: 12),
          _field(_descCtrl, 'Notas / Instrucciones',            Icons.notes, maxLines: 3, maxLength: 300),
        ])),

        const SizedBox(height: 20),

        // ── ENTREGA ─────────────────────────────
        _sectionTitle('Datos de Entrega', Icons.local_shipping_outlined),
        const SizedBox(height: 10),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Switch(value: _domicilio, activeColor: _cPrimary,
                onChanged: (v) => setState((){ _domicilio = v; _evaluarFlete(); _calcular(); })),
            const SizedBox(width: 8),
            const Text('Entrega en', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Text(_domicilio ? 'DOMICILIO' : 'SUCURSAL',
                style: const TextStyle(color: _cPrimary, fontWeight: FontWeight.bold)),
          ]),
          if (_domicilio) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(flex: 3, child: _field(_cpCtrl, 'C.P. *', Icons.markunread_mailbox_outlined, keyboardType: TextInputType.number, validator: _req)),
              const SizedBox(width: 12),
              Expanded(flex: 5, child: _field(_coloniaCtrl, 'Colonia *', Icons.holiday_village_outlined, validator: _req)),
            ]),
            const SizedBox(height: 12),
            _field(_domCtrl, 'Calle y Número *', Icons.location_on_outlined, validator: _req),
            const SizedBox(height: 12),
            _field(_fleteCtrl, 'Flete (\$)', Icons.delivery_dining,
                keyboardType: TextInputType.number, onChanged: (_) => _calcular()),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _datePicker()),
            const SizedBox(width: 12),
            Expanded(child: _timePicker()),
          ]),
        ])),
      ],
    );
  }

  // ── SIDEBAR DERECHO ─────────────────────────
  Widget _buildSidebar({required bool sticky}) {
    final content = Container(
      margin: EdgeInsets.only(top: sticky ? 16 : 0, right: sticky ? 20 : 0, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cBorderSoft, width: 2),
        boxShadow: [BoxShadow(color: _cPrimary.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0,6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del sidebar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: _cSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: _cBorderSoft)),
            ),
            child: const Row(children: [
              Icon(Icons.receipt_long, color: _cPrimary, size: 20),
              SizedBox(width: 8),
              Text('Resumen del Pedido',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _cPrimary)),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              // Selector de Cantidad
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cBorderSoft),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cantidad:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: _cPrimary),
                          onPressed: _cantidad > 1 ? () => setState(() { _cantidad--; _calcular(); }) : null,
                        ),
                        Text('$_cantidad', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: _cPrimary),
                          onPressed: () => setState(() { _cantidad++; _calcular(); }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Subtotal
              _priceRow('Precio Unitario:', '\$${_precioUnitario.toStringAsFixed(2)} MXN',
                  isTotal: false),
              const SizedBox(height: 8),
              _priceRow('Subtotal (${_cantidad}x):', '\$${_subtotal.toStringAsFixed(2)} MXN',
                  isTotal: false),
              const SizedBox(height: 8),
              _priceRow('Envío:', '\$${(double.tryParse(_fleteCtrl.text)??0).toStringAsFixed(2)} MXN',
                  isTotal: false),

              const SizedBox(height: 16),

              // Total grande
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cBorderSoft),
                ),
                child: Column(children: [
                  const Text('Costo Total',
                      style: TextStyle(fontSize: 11, color: Colors.grey, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text('\$${_total.toStringAsFixed(2)} MXN',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _cPrimary)),
                ]),
              ),

              const SizedBox(height: 16),

              // Anticipo / Restante
              _priceRow('Anticipo (50%):', '\$${(double.tryParse(_anticipoCtrl.text)??0).toStringAsFixed(2)} MXN',
                  color: _cSecondary),
              const SizedBox(height: 4),
              _priceRow('Restante a la entrega:', '\$${_restante.toStringAsFixed(2)} MXN'),

              const Divider(height: 28, color: Color(0xFFEEEEEE)),

              // Otros cargos y Anticipo editables
              _field(_otrosCtrl, 'Otros Cargos (\$)', Icons.add_circle_outline,
                  keyboardType: TextInputType.number, onChanged: (_) => _calcular()),
              const SizedBox(height: 12),
              _field(_anticipoCtrl, 'Anticipo (\$)', Icons.savings_outlined,
                  keyboardType: TextInputType.number, onChanged: (_) {
                    _anticipoManual = true;
                    _calcular();
                  }),

              const SizedBox(height: 24),

              // Botón confirmar
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _confirmar,
                  icon: const Icon(Icons.receipt_long, size: 20),
                  label: const Text('Ver Resumen',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (mounted) { showDialog(context: context, builder: (_) => AlertDialog(
                      title: const Text('¿Limpiar formulario?'),
                      actions: [
                        TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancelar')),
                        FilledButton(onPressed: (){ Navigator.pop(context); _limpiar(); },
                            child: const Text('Limpiar')),
                      ],
                    ));}
                  },
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: const Text('Limpiar Campos'),
                ),
              ),
            ]),
          ),
        ],
      ),
    );

    return sticky
        ? SingleChildScrollView(
            child: content,
          )
        : content;
  }

  Widget _priceRow(String label, String value, {bool isTotal = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
            color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
            fontSize: isTotal ? 16 : 13,
            color: color ?? (isTotal ? _cPrimary : Colors.black87))),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  PASOS DEL WIZARD
  // ═══════════════════════════════════════════
  Widget _wizardStep(int num, String titulo, Widget body, String? summaryVal, VoidCallback onReset) {
    final isActive    = _step == num;
    final isCompleted = _step >  num && summaryVal != null;
    final isDisabled  = _step <  num;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: isDisabled ? 0.45 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? _cPrimary : isCompleted ? _cBorder : Colors.grey.shade200,
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive ? [
            BoxShadow(color: _cPrimary.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0,4))
          ] : [],
        ),
        child: IgnorePointer(
          ignoring: isDisabled,
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? _cSurface : Colors.transparent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(children: [
                // Badge número
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? _cPrimary : isCompleted ? _cSecondary : Colors.grey.shade300,
                  ),
                  child: Center(child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text('$num', style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.bold, fontSize: 13))),
                ),
                const SizedBox(width: 10),
                Text(titulo, style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15,
                    color: isActive || isCompleted ? _cPrimary : Colors.grey.shade700)),
              ]),
            ),
            // Body
            if (isActive)
              Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 14), child: body),
            // Summary completado
            if (isCompleted && !isActive)
              Container(
                decoration: const BoxDecoration(
                  color: _cSurface,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: _cSecondary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(summaryVal!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  TextButton(
                    onPressed: onReset,
                    style: TextButton.styleFrom(
                      foregroundColor: _cPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      side: const BorderSide(color: _cPrimary),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    child: const Text('Cambiar'),
                  ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  // ── PASO 1: CATEGORÍAS ──────────────────────
  Widget _buildCatGrid() {
    final cats = _cats.keys.toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160, childAspectRatio: 1,
        mainAxisSpacing: 10, crossAxisSpacing: 10,
      ),
      itemCount: cats.length,
      itemBuilder: (_, i) {
        final cat = cats[i];
        final sel = _catNombre == cat;
        return _PillCard(
          selected: sel,
          onTap: () => _elegirCat(cat),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_iconForCategory(cat), size: 36, color: sel ? _cPrimary : _cSecondary),
            const SizedBox(height: 8),
            Text(cat, textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                    color: sel ? _cPrimary : Colors.black87)),
          ]),
        ).animate()
         .fade(duration: 400.ms, delay: (40 * i).ms)
         .scaleXY(begin: 0.9, end: 1.0, duration: 400.ms, delay: (40 * i).ms);
      },
    );
  }

  // ── PASO 2: PRODUCTOS (con foto de Supabase) ─
  Widget _buildProdGrid() {
    final prods = _prodsDecat;
    if (prods.isEmpty) return const Center(child: Text('No hay productos.'));

    if (_esPastel) {
      final chocolate = prods.where((r) {
        final n = (r['nombre']?.toString() ?? '').trim().toLowerCase();
        return n.contains('choco');
      }).toList();

      final vainilla = prods.where((r) {
        final n = (r['nombre']?.toString() ?? '').trim().toLowerCase();
        return !n.contains('choco');
      }).toList();

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Vainilla', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _cPrimary)),
                const SizedBox(height: 10),
                _buildGrid(vainilla, const Color.fromARGB(255, 255, 250, 230)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Chocolate', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _cPrimary)),
                const SizedBox(height: 10),
                _buildGrid(chocolate, const Color.fromARGB(255, 240, 230, 230)),
              ],
            ),
          ),
        ],
      );
    }

    return _buildGrid(prods, Colors.white);
  }

  Widget _buildGrid(List<Map<String, dynamic>> items, Color bgColor) {
    if (items.isEmpty) return const Center(child: Text('No hay opciones.'));
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160, childAspectRatio: 0.8,
        mainAxisSpacing: 10, crossAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final p   = items[i];
        final sel = _productoSel?['id_producto'] == p['id_producto'];
        final url = _imgUrl(p);
        return _PillCard(
          selected: sel,
          baseColor: bgColor,
          onTap: () => _elegirProducto(p),
          child: Column(children: [
            // FOTO del producto
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: url != null
                    ? Image.network(url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_,__,___) => _fallbackIcon(p['nombre']?.toString()??''))
                    : _fallbackIcon(p['nombre']?.toString()??''),
              ),
            ),
            const SizedBox(height: 6),
            Text(p['nombre']?.toString()??'',
                textAlign: TextAlign.center, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11,
                    color: sel ? _cPrimary : Colors.black87)),
          ]),
        ).animate()
         .fade(duration: 400.ms, delay: (30 * i).ms)
         .slideY(begin: 0.1, duration: 400.ms, delay: (30 * i).ms)
         .scaleXY(begin: 0.95, end: 1.0, duration: 400.ms, delay: (30 * i).ms);
      },
    );
  }

  Widget _fallbackIcon(String nombre) {
    return Container(
      color: _cSurface,
      child: Center(child: Icon(_iconForCategory(nombre), size: 32, color: _cSecondary)),
    );
  }

  // ── PASO 3: SABORES ─────────────────────────
  Widget _buildSaborGrid() {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _saboresDisponibles.map((s) {
        final sel = _saborSel == s;
        return GestureDetector(
          onTap: () => _elegirSabor(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: sel ? _cPrimary : _cBorder, width: sel ? 2 : 1),
              color: sel ? _cSurface : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(s, style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14,
                color: sel ? _cPrimary : Colors.black87)),
          ),
        ).animate().fade(duration: 300.ms).slideY(begin: 0.2);
      }).toList(),
    );
  }

  // ── PASO 4: VARIANTES / TAMAÑOS ─────────────
  Widget _buildVarianteGrid() {
    if (_step < 4) return const SizedBox.shrink();

    // Mostrar carga mientras se obtienen las variantes
    if (_cargandoVariantes) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: _cSecondary, strokeWidth: 3),
              SizedBox(height: 12),
              Text('Cargando tamaños...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final variantes = _variantesFiltradas;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Filtro extra
      if (_hayExtra) ...[
        Row(children: [
          _chip('Normales', !_extra, () => setState(()=>{ _extra=false, _varianteSel=null, _calcular() })),
          const SizedBox(width: 8),
          _chip('Con Ingrediente Extra', _extra, ()=> setState(()=>{ _extra=true, _varianteSel=null, _calcular() })),
        ]),
        const SizedBox(height: 12),
      ],
      if (variantes.isEmpty)
        const Padding(padding: EdgeInsets.all(16),
            child: Center(child: Text('No hay tamaños con este filtro.')))
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150,
            childAspectRatio: 0.95,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: variantes.length,
          itemBuilder: (_, i) {
            final v       = variantes[i];
            final stock   = (v['stock'] as num?)?.toInt() ?? 999;
            final agotado = stock == 0;
            final sel     = _varianteSel?['id_variante'] == v['id_variante'];
            final precio  = double.tryParse(v['precio_venta'].toString()) ?? 0;
            final tamano  = v['tamaño']?.toString() ?? '';

            return GestureDetector(
              onTap: agotado ? null : () => _elegirVariante(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: sel ? _cSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: sel ? _cPrimary : _cBorder,
                    width: sel ? 2 : 1,
                  ),
                  boxShadow: sel
                      ? [BoxShadow(color: _cPrimary.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 3))]
                      : [],
                ),
                child: Opacity(
                  opacity: agotado ? 0.45 : 1.0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (sel)
                          const Icon(Icons.check_circle, color: _cPrimary, size: 14),
                        Text(
                          tamano,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: sel ? _cPrimary : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '\$${precio.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: sel ? _cPrimary : _cSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (agotado)
                          _badge('Agotado', Colors.red.shade50, Colors.red)
                        else if (stock > 0 && stock < 10)
                          _badge('Quedan $stock', const Color(0xFFFFF3CD), const Color(0xFFD35400))
                        else
                          _badge('OK', Colors.green.shade50, Colors.green.shade700),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate()
             .fade(duration: 400.ms, delay: (30 * i).ms)
             .scaleXY(begin: 0.9, end: 1.0, duration: 400.ms, delay: (30 * i).ms);
          },
        ),
    ]);
  }

  Widget _badge(String txt, Color bg, Color fg) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(txt, style: TextStyle(fontSize: 9, color: fg, fontWeight: FontWeight.bold)),
  );

  Widget _chip(String label, bool sel, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: sel ? _cPrimary : _cBorder, width: sel ? 2 : 1),
        color: sel ? _cSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: sel ? _cPrimary : Colors.black54)),
    ),
  );

  // ── CONFIG PASTEL ────────────────────────────
  Widget _buildConfigPastel() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _cCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cBorderSoft),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.auto_awesome, color: _cPrimary, size: 18),
          SizedBox(width: 8),
          Text('Configuración del Pastel',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _cPrimary)),
        ]),
        const SizedBox(height: 14),
        _configRow('Armado',          _armadoList, _armado,  (v)=>setState(()=>{_armado=v,_calcular()})),
        const SizedBox(height: 12),
        _configRow('Pisos',           _pisosList,  _pisos,   (v)=>setState(()=>{_pisos=v,_calcular()})),
        const SizedBox(height: 12),
        _configRow('Diseño Principal',_disenoList, _diseno,  (v)=>setState(()=>_diseno=v)),
      ]),
    );
  }

  Widget _configRow(String label, List<String> opts, String current, void Function(String) onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 6,
        children: opts.map((o) {
          final sel = current == o;
          return GestureDetector(
            onTap: () => onTap(o),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: sel ? Colors.black87 : Colors.grey.shade300, width: sel ? 1.5 : 1),
                color: sel ? Colors.grey.shade100 : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (sel) ...[const Icon(Icons.check, size: 13), const SizedBox(width: 4)],
                Text(o, style: TextStyle(fontSize: 12,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? Colors.black87 : Colors.black54)),
              ]),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  // ── HELPERS FORM ─────────────────────────────
  Widget _sectionTitle(String t, IconData icon) => Row(children: [
    Icon(icon, color: _cPrimary, size: 20),
    const SizedBox(width: 8),
    Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _cPrimary)),
  ]);

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: child,
  );

  Widget _field(
    TextEditingController ctrl, String label, IconData icon, {
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1, int? maxLength,
    void Function(String)? onChanged,
  }) => TextFormField(
    controller: ctrl,
    keyboardType: keyboardType,
    maxLines: maxLines,
    maxLength: maxLength,
    onChanged: onChanged,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _cPrimary, width: 1.5)),
      filled: true, fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );

  Widget _datePicker() => GestureDetector(
    onTap: _pickFecha,
    child: AbsorbPointer(child: TextFormField(
      decoration: InputDecoration(
        labelText: _fecha != null
            ? 'Fecha: ${_fecha!.day}/${_fecha!.month}/${_fecha!.year}'
            : 'Fecha de Entrega *',
        prefixIcon: const Icon(Icons.event_outlined, color: Colors.grey, size: 20),
        suffixIcon: const Icon(Icons.edit_calendar_outlined, color: Colors.grey, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _cPrimary)),
        filled: true, fillColor: Colors.white, isDense: true,
      ),
      validator: (_) => _fecha == null ? 'Requerido' : null,
    )),
  );

  Widget _timePicker() => GestureDetector(
    onTap: _pickHora,
    child: AbsorbPointer(child: TextFormField(
      decoration: InputDecoration(
        labelText: _hora != null
            ? 'Hora: ${_hora!.format(context)}'
            : 'Hora Aproximada *',
        prefixIcon: const Icon(Icons.schedule_outlined, color: Colors.grey, size: 20),
        suffixIcon: const Icon(Icons.access_time, color: Colors.grey, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _cPrimary)),
        filled: true, fillColor: Colors.white, isDense: true,
      ),
      validator: (_) => _hora == null ? 'Requerido' : null,
    )),
  );

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null;
}

// ═══════════════════════════════════════════════
//  PILL CARD
// ═══════════════════════════════════════════════
class _PillCard extends StatelessWidget {
  final Widget child;
  final bool selected, disabled;
  final VoidCallback? onTap;
  final Color? baseColor;
  const _PillCard({required this.child, required this.selected,
      this.disabled=false, this.onTap, this.baseColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: selected ? _cSurface : (baseColor ?? Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _cPrimary : _cBorder, width: selected ? 2 : 1),
          boxShadow: selected ? [
            BoxShadow(color: _cPrimary.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0,3))
          ] : [],
        ),
        child: Opacity(opacity: disabled ? 0.4 : 1.0,
            child: Padding(padding: const EdgeInsets.all(8), child: child)),
      ),
    );
  }
}