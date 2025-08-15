  import 'package:flutter/foundation.dart';
  import 'producto.dart'; // Usamos la misma clase Producto

  class CarritoProvider with ChangeNotifier {
    final List<Producto> _productos = [];

    List<Producto> get productos => _productos;

    void agregarProducto(Producto producto) {
      // Si ya existe, aumentamos cantidad
      final index = _productos.indexWhere((p) => p.nombre == producto.nombre);
      if (index != -1) {
        _productos[index].cantidad += 1;
      } else {
        _productos.add(producto);
      }
      notifyListeners();
    }

    void eliminarProducto(Producto producto) {
      final index = _productos.indexWhere((p) => p.nombre == producto.nombre);
      if (index != -1) {
        if (_productos[index].cantidad > 1) {
          _productos[index].cantidad -= 1;
        } else {
          _productos.removeAt(index);
        }
        notifyListeners();
      }
    }

    double get total => _productos.fold(0, (sum, item) => sum + item.precio * item.cantidad);

    int get cantidadTotal => _productos.fold(0, (sum, item) => sum + item.cantidad);
  }
