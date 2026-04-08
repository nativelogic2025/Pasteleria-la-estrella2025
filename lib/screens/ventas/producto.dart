class Producto {
  final String nombre;
  final String imagen; // ruta a la imagen en assets
  final double precio;
  int cantidad;

  Producto({
    required this.nombre,
    required this.imagen,
    required this.precio,
    this.cantidad = 1,
  });
}