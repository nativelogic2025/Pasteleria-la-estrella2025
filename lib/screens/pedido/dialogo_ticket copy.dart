import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // 👈 Necesario para cargar assets
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Llama a esta función desde cualquier parte de tu app para mostrar el ticket
void mostrarModalTicket({
  required BuildContext context,
  required String folio,
  required String nombreProducto,
  required double subtotal,
  required double total,
  required String tamano,
  required String categoria,
  required String tipoPan,
  required String tipoArmado,
  required String numeroPisos,
  required String diseno,
  required String mensaje,
  required String notasAdicionales,
  required String cliente,
  required String telefono,
  required String fechaEntrega,
  required String horaEntrega,
  required String direccionEntrega,
  required double otrosCargos,
  required double flete,
  required double anticipo,
  required double restoPorPagar,
  // Puedes agregar más parámetros aquí (sabor, flete, etc.)
}) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          height: 600,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Orden de Compra',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: PdfPreview(
                    // Le pasamos los datos a la función generadora
                    build: (format) => _generarDocumentoTicket(
                      format: format,
                      folio: folio,
                      nombreProducto: nombreProducto,
                      subtotal: subtotal,
                      total: total,
                      tamano: tamano,
                      categoria: categoria,
                      tipoPan: tipoPan,
                      tipoArmado: tipoArmado,
                      numeroPisos: numeroPisos,
                      diseno: diseno,
                      mensaje: mensaje,
                      notasAdicionales: notasAdicionales,
                      cliente: cliente,
                      telefono: telefono,
                      fechaEntrega: fechaEntrega,
                      horaEntrega: horaEntrega,
                      direccionEntrega: direccionEntrega,
                      otrosCargos: otrosCargos,
                      flete: flete,
                      anticipo: anticipo,
                      restoPorPagar: restoPorPagar,
                    ),
                    initialPageFormat: PdfPageFormat.roll80,
                    useActions: true,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              )
            ],
          ),
        ),
      );
    },
  );
}

/// Función privada que construye el PDF
Future<Uint8List> _generarDocumentoTicket({
  required PdfPageFormat format,
  required String folio,
  required String nombreProducto,
  required double subtotal,
  required double total,
  required String categoria,
  required String tamano,
  required String tipoPan,
  required String tipoArmado,
  required String numeroPisos,
  required String diseno,
  required String mensaje,
  required String notasAdicionales,
  required String cliente,
  required String telefono,
  required String fechaEntrega,
  required String horaEntrega,
  required String direccionEntrega,
  required double otrosCargos,
  required double flete,
  required double anticipo,
  required double restoPorPagar,
}) async {
  final pdf = pw.Document();

  // 1. Cargamos las fuentes con soporte Unicode
  final fontRegular = await PdfGoogleFonts.robotoRegular();
  final fontBold = await PdfGoogleFonts.robotoBold();

  // 1. Cargamos la imagen desde los assets antes de crear la página
  final imageByteData = await rootBundle.load('assets/logo_ticket.png');
  final logoBytes = imageByteData.buffer.asUint8List();
  final logoImage = pw.MemoryImage(logoBytes); // 👈 Convertimos a un formato que el paquete PDF entiende

  pdf.addPage(
    pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(12),
      // 2. Aplicamos la fuente a toda la página
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // 2. Colocamos la imagen
            pw.Image(logoImage, width: 140, height: 140), 
            pw.SizedBox(height: 8),

            pw.Center(
              child: pw.Text('PASTELERÍA LA ESTRELLA',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 12),

            // Regresamos la alineación a la izquierda para los detalles
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Folio: $folio'),
                  pw.Text('Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                ]
              )
            ),

            pw.Divider(borderStyle: pw.BorderStyle.dashed),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('1x $nombreProducto')),
                pw.Text('\$${subtotal.toStringAsFixed(2)}'),
              ]
            ),

            pw.Divider(borderStyle: pw.BorderStyle.dashed),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Detalles'),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Tamaño')),
                pw.Text(tamano),
              ]
            ),
            if (tipoPan.isNotEmpty)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Tipo de pan')),
                pw.Text(tipoPan),
              ]
            ),
            if (categoria == 'Pasteles')
            ...[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('Tipo de armado')),
                  pw.Text(tipoArmado),
                ]
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('Numero de pisos')),
                  pw.Text(numeroPisos),
                ]
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('Diseño')),
                  pw.Text(diseno),
                ]
              ),
            ],
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Mensaje')),
                pw.Text(mensaje),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Notas adicionales')),
                pw.Text(notasAdicionales),
              ]
            ),
            
            pw.Divider(borderStyle: pw.BorderStyle.dashed),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Cliente')),
                pw.Text(cliente),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Teléfono')),
                pw.Text(telefono),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Fecha de entrega')),
                pw.Text(fechaEntrega),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Hora de entrega')),
                pw.Text(horaEntrega),
              ]
            ),
            if (direccionEntrega.isNotEmpty)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Dirección de entrega')),
                pw.Text(direccionEntrega),
              ]
            ),
            if (direccionEntrega.isEmpty)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('')),
                pw.Text('Entrega en sucursal'),
              ]
            ),
            
            pw.Divider(borderStyle: pw.BorderStyle.dashed),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Subtotal')),
                pw.Text(subtotal.toStringAsFixed(2)),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Otros cargos')),
                pw.Text(otrosCargos.toStringAsFixed(2)),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Flete')),
                pw.Text(flete.toStringAsFixed(2)),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Anticipo')),
                pw.Text(anticipo.toStringAsFixed(2)),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Resto por pagar')),
                pw.Text(restoPorPagar.toStringAsFixed(2)),
              ]
            ),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('\$${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ]
            ),
            pw.SizedBox(height: 16),
            pw.Center(child: pw.Text('¡Gracias por su compra!', textAlign: pw.TextAlign.center)),
          ],
        );
      },
    ),
  );

  return pdf.save();
}