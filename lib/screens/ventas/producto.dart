class Producto {
  final String nombre;
  final String imagen; // ruta a la imagen en assets
  final double precio;
  int cantidad;
  final int? idProducto; // NUNCA puede ser null en producción, pero permitimos nulo por compatibilidad
  final int? idVariante; // NUNCA puede ser null en producción, pero permitimos nulo por compatibilidad

  Producto({
    required this.nombre,
    required this.imagen,
    required this.precio,
    this.cantidad = 1,
    this.idProducto,
    this.idVariante,
  });
}