import 'package:flutter/material.dart';

/// Modelo de un producto en stock
class StockItem {
  final String id;
  final String nombre;
  final IconData? icono;   // Usa este si no tienes imagen
  final String? assetPath; // Usa este si tienes imagen (assets/...)
  int cantidad;
  double precio;

  StockItem({
    required this.id,
    required this.nombre,
    this.icono,
    this.assetPath,
    required this.cantidad,
    required this.precio,
  });
}

/// ===============================
/// CATÁLOGO INICIAL (fuera del provider)
/// ===============================

// Extras
final List<StockItem> _extras = [
  StockItem(
    id: 'oblea',
    nombre: 'Oblea',
    icono: Icons.local_pizza,
    assetPath: 'assets/extras/oblea.png',
    cantidad: 0,
    precio: 20.0,
  ),
  StockItem(
    id: 'transfer',
    nombre: 'Transfer',
    icono: Icons.image,
    assetPath: 'assets/extras/transfer.png',
    cantidad: 0,
    precio: 20.0,
  ),
  StockItem(
    id: 'pan',
    nombre: 'Pan',
    icono: Icons.bakery_dining,
    assetPath: 'assets/extras/pan.png',
    cantidad: 0,
    precio: 20.0,
  ),
  StockItem(
    id: 'nata',
    nombre: 'Nata',
    icono: Icons.icecream,
    assetPath: 'assets/extras/nata.png',
    cantidad: 0,
    precio: 20.0,
  ),
];

// Pasteles (Vainilla + Chocolate)
final List<StockItem> _pasteles = [
  // Vainilla
  StockItem(id: 'cajeta', nombre: 'Cajeta', icono: Icons.cake, assetPath: 'assets/pasteles/cajeta.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'durazno', nombre: 'Durazno', icono: Icons.cake, assetPath: 'assets/pasteles/durazno.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'fresa', nombre: 'Fresa', icono: Icons.cake, assetPath: 'assets/pasteles/fresa.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'limon', nombre: 'Limon', icono: Icons.cake, assetPath: 'assets/pasteles/limon.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'pinacoco', nombre: 'PiñaCoco', icono: Icons.cake, assetPath: 'assets/pasteles/pinacoco.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'zarzamora', nombre: 'Zarzamora', icono: Icons.cake, assetPath: 'assets/pasteles/zarzamora.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'crema_irlandesa', nombre: 'Crema Irlandesa', icono: Icons.cake, assetPath: 'assets/pasteles/crema_irlandesa.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'fresa_con_nuez', nombre: 'Fresa con Nuez', icono: Icons.cake, assetPath: 'assets/pasteles/fresa_con_nuez.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'durazno_con_mango', nombre: 'Durazno con Mango', icono: Icons.cake, assetPath: 'assets/pasteles/durazno_con_mango.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'durazno_con_nuez', nombre: 'Durazno con Nuez', icono: Icons.cake, assetPath: 'assets/pasteles/durazno_con_nuez.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'moka', nombre: 'Moka', icono: Icons.cake, assetPath: 'assets/pasteles/moka.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'nutella', nombre: 'Nutella', icono: Icons.cake, assetPath: 'assets/pasteles/nutella.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'rompope_con_nuez', nombre: 'Rompope con Nuez', icono: Icons.cake, assetPath: 'assets/pasteles/rompope_con_nuez.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'queso_con_zarzamora', nombre: 'Queso con Zarzamora', icono: Icons.cake, assetPath: 'assets/pasteles/queso_con_zarzamora.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'queso_revuelto', nombre: 'Queso Revuelto', icono: Icons.cake, assetPath: 'assets/pasteles/queso_revuelto.png', cantidad: 0, precio: 50.0),
  // Chocolate
  StockItem(id: 'chocofresa', nombre: 'ChocoFresa', icono: Icons.cake, assetPath: 'assets/pasteles/chocofresa.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'chocomoka', nombre: 'ChocoMoka', icono: Icons.cake, assetPath: 'assets/pasteles/chocomoka.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'choconuez', nombre: 'ChocoNuez', icono: Icons.cake, assetPath: 'assets/pasteles/choconuez.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'choconutella', nombre: 'ChocoNutella', icono: Icons.cake, assetPath: 'assets/pasteles/choconutella.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'chocooreo', nombre: 'ChocoOreo', icono: Icons.cake, assetPath: 'assets/pasteles/chocooreo.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'chocozarzamora', nombre: 'ChocoZarzamora', icono: Icons.cake, assetPath: 'assets/pasteles/chocozarzamora.png', cantidad: 0, precio: 50.0),
];

// Postres
final List<StockItem> _postres = [
  StockItem(id: 'flan', nombre: 'Flan', icono: Icons.cake_outlined, assetPath: 'assets/postres/flan.png', cantidad: 0, precio: 35.0),
  StockItem(id: 'pay_de_limon', nombre: 'Pay de Limón', icono: Icons.cake_outlined, assetPath: 'assets/postres/pay_de_limon.png', cantidad: 0, precio: 35.0),
  StockItem(id: 'ensalada_de_manzana', nombre: 'Ensalada de Manzana', icono: Icons.icecream, assetPath: 'assets/postres/ensalada_de_manzana.png', cantidad: 0, precio: 35.0),
  StockItem(id: 'ensalada_de_zanahoria', nombre: 'Ensalada de Zanahoria', icono: Icons.icecream, assetPath: 'assets/postres/ensalada_de_zanahoria.png', cantidad: 0, precio: 35.0),
  StockItem(id: 'gelatina', nombre: 'Gelatina', icono: Icons.icecream, assetPath: 'assets/postres/gelatina.png', cantidad: 0, precio: 35.0),
  StockItem(id: 'fresas_con_crema', nombre: 'Fresas con Crema', icono: Icons.icecream, assetPath: 'assets/postres/fresas_con_crema.png', cantidad: 0, precio: 35.0),
  StockItem(id: 'arroz_con_leche', nombre: 'Arroz con Leche', icono: Icons.icecream, assetPath: 'assets/postres/arroz_con_leche.png', cantidad: 0, precio: 35.0),
  StockItem(id: 'pastelitos', nombre: 'Pastelitos', icono: Icons.cake, assetPath: 'assets/postres/pastelitos.png', cantidad: 0, precio: 35.0),
];

// Repostería (variantes)
final List<StockItem> _reposteriaVariantes = [
  // Tiramisú (3 tamaños)
  StockItem(id: 'tiramisu_chico', nombre: 'Tiramisú Chico', icono: Icons.local_cafe, assetPath: 'assets/reposteria/tiramisu.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'tiramisu_mediano', nombre: 'Tiramisú Mediano', icono: Icons.local_cafe, assetPath: 'assets/reposteria/tiramisu.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'tiramisu_grande', nombre: 'Tiramisú Grande', icono: Icons.local_cafe, assetPath: 'assets/reposteria/tiramisu.png', cantidad: 0, precio: 50.0),

  // Pastel Imposible (3 tamaños × 2 tipos)
  StockItem(id: 'pastel_imposible_chico_normal', nombre: 'Pastel Imposible Chico Normal', icono: Icons.cake, assetPath: 'assets/reposteria/pastel_imposible.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'pastel_imposible_mediano_normal', nombre: 'Pastel Imposible Mediano Normal', icono: Icons.cake, assetPath: 'assets/reposteria/pastel_imposible.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'pastel_imposible_grande_normal', nombre: 'Pastel Imposible Grande Normal', icono: Icons.cake, assetPath: 'assets/reposteria/pastel_imposible.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'pastel_imposible_chico_cafe', nombre: 'Pastel Imposible Chico Café', icono: Icons.cake, assetPath: 'assets/reposteria/pastel_imposible.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'pastel_imposible_mediano_cafe', nombre: 'Pastel Imposible Mediano Café', icono: Icons.cake, assetPath: 'assets/reposteria/pastel_imposible.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'pastel_imposible_grande_cafe', nombre: 'Pastel Imposible Grande Café', icono: Icons.cake, assetPath: 'assets/reposteria/pastel_imposible.png', cantidad: 0, precio: 50.0),

  // Mousse (sabores)
  StockItem(id: 'mousse_zarzamora', nombre: 'Mousse Zarzamora', icono: Icons.icecream, assetPath: 'assets/reposteria/mousse.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'mousse_fresa', nombre: 'Mousse Fresa', icono: Icons.icecream, assetPath: 'assets/reposteria/mousse.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'mousse_oreo', nombre: 'Mousse Oreo', icono: Icons.icecream, assetPath: 'assets/reposteria/mousse.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'mousse_guayaba', nombre: 'Mousse Guayaba', icono: Icons.icecream, assetPath: 'assets/reposteria/mousse.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'mousse_pinacoco', nombre: 'Mousse PiñaCoco', icono: Icons.icecream, assetPath: 'assets/reposteria/mousse.png', cantidad: 0, precio: 50.0),
  StockItem(id: 'mousse_mango', nombre: 'Mousse Mango', icono: Icons.icecream, assetPath: 'assets/reposteria/mousse.png', cantidad: 0, precio: 50.0),
];

// Velas (especiales + 30 variantes numéricas)
final List<StockItem> _velasNumeros = [
  // ---- Especiales (no numéricas) ----
  StockItem(
    id: 'chispas_pequenas',
    nombre: 'Chispas pequeñas',
    icono: Icons.auto_awesome,
    assetPath: 'assets/velas/chispas_pequenas.png',
    cantidad: 0,
    precio: 15.0,
  ),
  StockItem(
    id: 'chispas_grandes',
    nombre: 'Chispas grandes',
    icono: Icons.auto_awesome,
    assetPath: 'assets/velas/chispas_grandes.png',
    cantidad: 0,
    precio: 15.0,
  ),
  StockItem(
    id: 'magicas',
    nombre: 'Mágicas',
    icono: Icons.local_fire_department,
    assetPath: 'assets/velas/magicas.png',
    cantidad: 0,
    precio: 15.0,
  ),
  StockItem(
    id: 'personalizadas',
    nombre: 'Personalizadas',
    icono: Icons.brush,
    assetPath: 'assets/velas/personalizadas.png',
    cantidad: 0,
    precio: 15.0,
  ),
  StockItem(
    id: 'felicidades',
    nombre: 'Felicidades',
    icono: Icons.cake,
    assetPath: 'assets/velas/felicidades.png',
    cantidad: 0,
    precio: 15.0,
  ),

  // ---- No. Rosa 1–9 y ? ----
  for (int i = 1; i <= 9; i++)
    StockItem(
      id: 'no_rosa_$i',
      nombre: 'No. Rosa $i',
      icono: Icons.filter_1, // ícono ilustrativo
      assetPath: 'assets/velas/no_rosa_$i.png',
      cantidad: 0,
      precio: 15.0,
    ),
  StockItem(
    id: 'no_rosa_q',
    nombre: 'No. Rosa ?',
    icono: Icons.help_outline,
    assetPath: 'assets/velas/no_rosa_q.png',
    cantidad: 0,
    precio: 15.0,
  ),

  // ---- No. Azul 1–9 y ? ----
  for (int i = 1; i <= 9; i++)
    StockItem(
      id: 'no_azul_$i',
      nombre: 'No. Azul $i',
      icono: Icons.filter_1,
      assetPath: 'assets/velas/no_azul_$i.png',
      cantidad: 0,
      precio: 15.0,
    ),
  StockItem(
    id: 'no_azul_q',
    nombre: 'No. Azul ?',
    icono: Icons.help_outline,
    assetPath: 'assets/velas/no_azul_q.png',
    cantidad: 0,
    precio: 15.0,
  ),

  // ---- No. Arcoiris 1–9 y ? ----
  for (int i = 1; i <= 9; i++)
    StockItem(
      id: 'no_arcoiris_$i',
      nombre: 'No. Arcoiris $i',
      icono: Icons.filter_1,
      assetPath: 'assets/velas/no_arcoiris_$i.png',
      cantidad: 0,
      precio: 15.0,
    ),
  StockItem(
    id: 'no_arcoiris_q',
    nombre: 'No. Arcoiris ?',
    icono: Icons.help_outline,
    assetPath: 'assets/velas/no_arcoiris_q.png',
    cantidad: 0,
    precio: 15.0,
  ),
];

// Unificamos todo en una sola lista
final List<StockItem> _catalogoInicial = [
  ..._extras,
  ..._pasteles,
  ..._postres,
  ..._reposteriaVariantes,
  ..._velasNumeros,
];

/// ===============================
/// Provider del inventario
/// ===============================
class StockProvider extends ChangeNotifier {
  final List<StockItem> _items = [];

  StockProvider() {
    // Cargar todo el catálogo al iniciar
    _items.addAll(_catalogoInicial);
  }

  /// Devuelve copia inmutable
  List<StockItem> get items => List.unmodifiable(_items);

  // ---- CRUD ----
  void agregarProducto(StockItem nuevo) {
    _items.add(nuevo);
    notifyListeners();
  }

  void eliminarProducto(String id) {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void incrementar(String id) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _items[i].cantidad++;
    notifyListeners();
  }

  void decrementar(String id) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) return;
    if (_items[i].cantidad > 0) {
      _items[i].cantidad--;
      notifyListeners();
    }
  }

  void actualizarPrecio(String id, double nuevoPrecio) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i == -1) return;
    _items[i].precio = nuevoPrecio;
    notifyListeners();
  }

  // Utilidad: reemplazar todo (por si luego cargas de JSON/DB)
  void cargarInicial(List<StockItem> lista) {
    _items
      ..clear()
      ..addAll(lista);
    notifyListeners();
  }
}
