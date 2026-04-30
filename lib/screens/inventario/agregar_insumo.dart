import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

final supabase = Supabase.instance.client;

class AgregarInsumoScreen extends StatefulWidget {
  const AgregarInsumoScreen({super.key});

  @override
  State<AgregarInsumoScreen> createState() => _AgregarInsumoScreenState();
}

class _AgregarInsumoScreenState extends State<AgregarInsumoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _unidadCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _costoCtrl = TextEditingController(text: '0.0');

  bool _guardando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _unidadCtrl.dispose();
    _stockCtrl.dispose();
    _costoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarInsumo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final nombre = _nombreCtrl.text.trim();
      final unidad = _unidadCtrl.text.trim();
      final stock = int.tryParse(_stockCtrl.text) ?? 0;
      final costo = double.tryParse(_costoCtrl.text) ?? 0.0;

      await supabase.from('ingredientes').insert({
        'nombre': nombre,
        'unidad_medida': unidad,
        'stock_actual': stock,
        'costo_unitario': costo,
      });

      if (mounted) Navigator.pop(context, true);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar insumo: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Insumo', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 40, 40, 40),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.orange),
            onPressed: _guardando ? null : _guardarInsumo,
          )
        ],
      ),
      body: _guardando
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre del insumo (Ej: Harina, Azúcar)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _unidadCtrl,
                      decoration: InputDecoration(
                        labelText: 'Unidad de medida (Ej: Kg, Lts, Pzas)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Stock Inicial',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _costoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Costo (\$)',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 40, 40, 40),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _guardando ? null : _guardarInsumo,
                      icon: const Icon(Icons.check, color: Colors.orange),
                      label: const Text('GUARDAR INSUMO', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
