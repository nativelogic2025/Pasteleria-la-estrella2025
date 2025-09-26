import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'agregar_producto.dart'; // 👈 pantalla para crear productos

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen>
    with SingleTickerProviderStateMixin {
  // 🔧 Cambia a tu servidor si aplica
  final pb = PocketBase('http://127.0.0.1:8090');

  // Pestañas/categorías
  final List<String> _tabsLabels = const [
    'Todos',
    'Pasteles',
    'Postres',
    'Velas',
    'Reposteria',
    'Extras',
  ];

  late final TabController _tabController;

  List<RecordModel> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabsLabels.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _recargarSegunTab();
    });
    _cargar(); // carga inicial (Todos)
  }

  // ---------- Helpers (lectura de campos) ----------
  String _nombre(RecordModel r) =>
      (r.data['Nombre'] ?? r.data['producto'] ?? '').toString();

  String _categoria(RecordModel r) =>
      (r.data['Categoria'] ?? r.data['categoria'] ?? '').toString();

  int _cantidad(RecordModel r) {
    final v = r.data['cantidad'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  double _precio(RecordModel r) {
    final v = r.data['precio'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0.0;
  }

  // URL del archivo 'icon' en PocketBase (si existe)
  String? _iconUrl(RecordModel r) {
    final file = r.data['icon'];
    if (file == null || file.toString().isEmpty) return null;
    final uri = pb.files.getUrl(r, file.toString(), thumb: '100x100');
    return uri.toString();
  }

  // ---------- Data (PB) ----------
  Future<void> _cargar({String? categoria}) async {
    setState(() => _loading = true);
    try {
      final res = await pb.collection('productos').getList(
            perPage: 200,
            filter: categoria == null ? null : 'Categoria = "$categoria"',
            sort: 'Nombre', // orden alfabético dentro de la categoría
          );
      setState(() {
        _items = res.items;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar: $e')),
      );
    }
  }

  void _recargarSegunTab() {
    final sel = _tabsLabels[_tabController.index];
    _cargar(categoria: sel == 'Todos' ? null : sel);
  }

  Future<void> _incrementar(RecordModel r) async {
    await pb.collection('productos').update(r.id, body: {
      'cantidad': _cantidad(r) + 1,
    });
    _recargarSegunTab();
  }

  Future<void> _decrementar(RecordModel r) async {
    final nueva = (_cantidad(r) - 1).clamp(0, 1 << 31);
    await pb.collection('productos').update(r.id, body: {'cantidad': nueva});
    _recargarSegunTab();
  }

  Future<void> _actualizarPrecio(RecordModel r, double nuevo) async {
    await pb.collection('productos').update(r.id, body: {'precio': nuevo});
    _recargarSegunTab();
  }

  Future<void> _eliminar(RecordModel r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${_nombre(r)}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await pb.collection('productos').delete(r.id);
    _recargarSegunTab();
  }

  Future<double?> _pedirNuevoPrecio(BuildContext context, double actual) async {
    final controller = TextEditingController(text: actual.toStringAsFixed(2));
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actualizar precio'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: '\$ ',
            hintText: 'Ej. 89.90',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final t = controller.text.replaceAll(',', '.').trim();
              final v = double.tryParse(t);
              if (v == null || v < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Precio inválido')),
                );
                return;
              }
              Navigator.pop(context, v);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final table = _loading
        ? const Center(child: CircularProgressIndicator())
        : DataTable(
            columnSpacing: 24,
            headingRowHeight: 48,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 72,
            columns: const [
              DataColumn(label: Text('Producto')),
              DataColumn(label: Text('Categoría')),
              DataColumn(label: Text('Cantidad')),
              DataColumn(label: Text('Precio')),
              DataColumn(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Icon(Icons.delete, size: 18), SizedBox(width: 6), Text('Eliminar')],
                ),
              ),
            ],
            rows: _items.map((r) {
              final nombre = _nombre(r);
              final categoria = _categoria(r);
              final cantidad = _cantidad(r);
              final precio = _precio(r);
              final url = _iconUrl(r);

              return DataRow(cells: [
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ProductoIcono(url: url),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        nombre,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                )),
                DataCell(Text(categoria.isEmpty ? '—' : categoria)),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.outlined(
                      icon: const Icon(Icons.remove),
                      onPressed: cantidad > 0 ? () => _decrementar(r) : null,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      style: IconButton.styleFrom(padding: EdgeInsets.zero),
                      tooltip: 'Disminuir',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '$cantidad',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton.outlined(
                      icon: const Icon(Icons.add),
                      onPressed: () => _incrementar(r),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      style: IconButton.styleFrom(padding: EdgeInsets.zero),
                      tooltip: 'Aumentar',
                    ),
                  ],
                )),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('\$${precio.toStringAsFixed(2)}'),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Editar precio',
                      onPressed: () async {
                        final nuevo = await _pedirNuevoPrecio(context, precio);
                        if (nuevo != null) _actualizarPrecio(r, nuevo);
                      },
                    ),
                  ],
                )),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Eliminar producto',
                    onPressed: () => _eliminar(r),
                  ),
                ),
              ]);
            }).toList(),
          );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Stock'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabsLabels.map((e) => Tab(text: e)).toList(),
        ),
        actions: [
          IconButton(
            tooltip: 'Agregar producto',
            icon: const Icon(Icons.add),
            onPressed: () async {
              final categoriaActual = _tabsLabels[_tabController.index];
              final creada = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => AgregarProductoScreen(
                    categoriaInicial:
                        categoriaActual == 'Todos' ? null : categoriaActual,
                  ),
                ),
              );
              if (creada == true) _recargarSegunTab();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: table,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _recargarSegunTab,
        tooltip: 'Recargar',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class _ProductoIcono extends StatelessWidget {
  const _ProductoIcono({this.url});
  final String? url; // desde PB

  @override
  Widget build(BuildContext context) {
    const double size = 50;
    const Widget fallback = Icon(Icons.image_not_supported, size: 28);

    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }
    return fallback; // si no hay archivo 'icon'
  }
}
