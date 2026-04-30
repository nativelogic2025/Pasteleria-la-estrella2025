import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'agregar_insumo.dart';
import 'package:flutter_animate/flutter_animate.dart';

final supabase = Supabase.instance.client;

class InsumosTab extends StatefulWidget {
  const InsumosTab({super.key});

  @override
  State<InsumosTab> createState() => _InsumosTabState();
}

class _InsumosTabState extends State<InsumosTab> {
  List<Map<String, dynamic>> _insumos = [];
  bool _cargando = true;

  final Map<String, TextEditingController> _stockCtrls = {};
  final Map<String, int> _stockOriginal = {};
  bool _hayCambios = false;

  @override
  void initState() {
    super.initState();
    _cargarInsumos();
  }

  @override
  void dispose() {
    for (var c in _stockCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarInsumos() async {
    setState(() => _cargando = true);

    for (var c in _stockCtrls.values) {
      c.dispose();
    }
    _stockCtrls.clear();
    _stockOriginal.clear();
    _hayCambios = false;

    try {
      final response = await supabase
          .from('ingredientes')
          .select()
          .order('nombre');

      _insumos = List<Map<String, dynamic>>.from(response);

      for (var insumo in _insumos) {
        final id = insumo['id_ingrediente'].toString();
        // stock_actual can be numeric, parse to int for textfield representation or keep double
        final stock = (insumo['stock_actual'] as num?)?.toInt() ?? 0;

        _stockOriginal[id] = stock;
        _stockCtrls[id] = TextEditingController(text: stock.toString())
          ..addListener(() {
            final detectado = _detectarCambios();
            if (detectado != _hayCambios) {
              setState(() => _hayCambios = detectado);
            }
          });
      }

      setState(() => _cargando = false);
    } catch (e) {
      setState(() => _cargando = false);
      // Solo mostramos si no es que la tabla no exista aún
      if (!e.toString().contains('relation "public.insumos" does not exist')) {
         _mostrarError('Error al cargar insumos: $e');
      } else {
         // Silently fail if table not created by user yet
         _insumos = [];
      }
    }
  }

  bool _detectarCambios() {
    for (final entry in _stockCtrls.entries) {
      final original = _stockOriginal[entry.key];
      final actual = int.tryParse(entry.value.text);

      if (original != null && actual != null && original != actual) {
        return true;
      }
    }
    return false;
  }

  Future<void> _guardarCambiosStock() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final futures = <Future>[];

      for (final entry in _stockCtrls.entries) {
        final id = entry.key;
        final nuevo = int.tryParse(entry.value.text);
        final original = _stockOriginal[id];

        if (nuevo != null && original != null && nuevo != original) {
          futures.add(
            supabase
                .from('ingredientes')
                .update({'stock_actual': nuevo})
                .eq('id_ingrediente', id),
          );
        }
      }

      await Future.wait(futures);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Stock de insumos actualizado'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _cargarInsumos();
    } catch (e) {
      _mostrarError('Error al guardar cambios: $e', scaffoldMessenger: scaffoldMessenger);
    }
  }

  Future<void> _actualizarPrecio(String idInsumo, double nuevo) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      await supabase
          .from('ingredientes')
          .update({'costo_unitario': nuevo})
          .eq('id_ingrediente', idInsumo);

      _cargarInsumos();
    } catch (e) {
      _mostrarError('Error al actualizar precio: $e', scaffoldMessenger: scaffoldMessenger);
    }
  }

  Future<bool> _eliminarInsumo(String idInsumo) async {
    try {
      await supabase
          .from('ingredientes')
          .delete()
          .eq('id_ingrediente', idInsumo);

      await _cargarInsumos();
      return true;
    } catch (e) {
      debugPrint('Error al eliminar insumo: $e');
      return false;
    }
  }

  void _mostrarError(String mensaje, {ScaffoldMessengerState? scaffoldMessenger}) {
    if (!mounted) return;
    if (scaffoldMessenger != null) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_insumos.isEmpty) {
      return Stack(
        children: [
          const Center(
            child: Text(
              'No hay insumos registrados aún.\nAsegúrate de haber creado la tabla "ingredientes" en Supabase.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'add_insumo',
              backgroundColor: const Color.fromARGB(255, 40, 40, 40),
              child: const Icon(Icons.add, color: Colors.orange),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AgregarInsumoScreen()),
                ).then((_) => _cargarInsumos());
              },
            ),
          )
        ],
      );
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(12).copyWith(bottom: 80),
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
                  columns: const [
                    DataColumn(label: Text('Nombre', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Stock Actual', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('U. Medida', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Costo', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _insumos.map((i) {
                    final id = i['id_ingrediente'].toString();
                    final costo = (i['costo_unitario'] as num?)?.toDouble() ?? 0.0;

                    return DataRow(cells: [
                      DataCell(Text(i['nombre']?.toString() ?? 'Sin nombre')),
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _stockCtrls[id],
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(i['unidad_medida']?.toString() ?? '-')),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('\$${costo.toStringAsFixed(2)}'),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                            onPressed: () async {
                              final ctrl = TextEditingController(text: costo.toStringAsFixed(2));
                              final nuevo = await showDialog<double>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Actualizar Costo'),
                                  content: TextField(
                                    controller: ctrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: const Color.fromARGB(255, 40, 40, 40)),
                                      onPressed: () {
                                        final val = double.tryParse(ctrl.text);
                                        if (val != null) Navigator.pop(context, val);
                                      },
                                      child: const Text('Guardar', style: TextStyle(color: Colors.orange)),
                                    )
                                  ],
                                ),
                              );

                              if (nuevo != null) _actualizarPrecio(id, nuevo);
                            },
                          )
                        ],
                      )),
                      DataCell(IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmarEliminacion(context, id, i['nombre']),
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ).animate().fade(duration: 400.ms).slideY(begin: 0.02),
          ],
        ),
        
        // Floating action buttons at the bottom
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_hayCambios)
                FloatingActionButton.extended(
                  heroTag: 'save_stock_insumos',
                  backgroundColor: Colors.green,
                  onPressed: _guardarCambiosStock,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar cambios'),
                ),
              if (_hayCambios) const SizedBox(height: 10),
              FloatingActionButton.extended(
                heroTag: 'add_insumo',
                backgroundColor: const Color.fromARGB(255, 40, 40, 40),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AgregarInsumoScreen()),
                  ).then((_) => _cargarInsumos());
                },
                icon: const Icon(Icons.add, color: Colors.orange),
                label: const Text('Nuevo Insumo', style: TextStyle(color: Colors.orange)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmarEliminacion(BuildContext context, String idInsumo, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar insumo'),
        content: Text('¿Seguro que deseas eliminar "$nombre"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
             style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final res = await _eliminarInsumo(idInsumo);
      if (res && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insumo eliminado'), backgroundColor: Colors.green),
        );
      }
    }
  }
}
