class Producto {
  final String nombre;
  final String emoji;
  final double precio;
  int cantidad;

  Producto({
    required this.nombre,
    required this.emoji,
    required this.precio,
    this.cantidad = 1,
  });
}
