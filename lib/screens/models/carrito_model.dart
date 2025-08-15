import 'package:flutter/foundation.dart';
import '../producto.dart';

class CarritoModel extends ChangeNotifier {
  final List<Producto> _productos = [];

  List<Producto> get productos => _productos;

  int get totalProductos =>
      _productos.fold(0, (sum, item) => sum + item.cantidad);

  double get totalPrecio =>
      _productos.fold(0, (sum, item) => sum + item.cantidad * item.precio);

  void agregarProducto(Producto producto) {
    final index = _productos.indexWhere((p) => p.nombre == producto.nombre);
    if (index >= 0) {
      _productos[index].cantidad++;
    } else {
      _productos.add(producto);
    }
    notifyListeners();
  }

  void quitarProducto(Producto producto) {
    final index = _productos.indexWhere((p) => p.nombre == producto.nombre);
    if (index >= 0) {
      if (_productos[index].cantidad > 1) {
        _productos[index].cantidad--;
      } else {
        _productos.removeAt(index);
      }
      notifyListeners();
    }
  }

  void vaciarCarrito() {
    _productos.clear();
    notifyListeners();
  }
}
