import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void _guardarTicketEnSupabase(Uint8List pdfBytes, String folio) async {
  try {
    final supabase = Supabase.instance.client;
    // Nombramos el archivo, ej: ticket_EST-001.pdf
    final nombreArchivo = 'ticket_$folio.pdf';

    // Subimos los bytes directamente al Storage
    await supabase.storage.from('tickets').uploadBinary(
      nombreArchivo,
      pdfBytes,
      fileOptions: const FileOptions(
        contentType: 'application/pdf',
        upsert: true, // Si ya existe un ticket con ese folio, lo sobreescribe
      ),
    );

    print('✅ Ticket $folio guardado en Supabase Storage con éxito');
  } catch (e) {
    print('❌ Error al subir el ticket a Supabase: $e');
    // Como esto ocurre en segundo plano (background), es mejor solo 
    // imprimir el error en consola para no molestar al usuario con alertas rojas.
  }
}

/// Llama a esta función desde cualquier parte de tu app para mostrar el ticket
void mostrarModalTicketConDatos({
  required BuildContext context,
  required Map<String, dynamic> datosTicket,
  required VoidCallback alCerrarTicket,
}) {
  showDialog(
    context: context,
    barrierDismissible: false, // 1. 👇 ESTO EVITA QUE SE CIERRE AL TOCAR FUERA DEL MODAL
    builder: (context) {
      return PopScope(
        canPop: false, // Bloquea la acción nativa de retroceder
        child: Dialog(
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
                      // El modal ya está abierto, y aquí disparamos el hilo secundario.
                      // PdfPreview mostrará su animación de carga automáticamente.
                      build: (format) async {
                        // 1. Pausa para la animación suave del modal
                        await Future.delayed(const Duration(milliseconds: 300));
                        
                        // 2. Generamos el PDF con el trabajador en fondo
                        // El primer parámetro es el nombre de la función, el segundo son los datos
                        final pdfBytes = await compute(_construirPdfEnFondo, datosTicket);
                        
                        // 3. LA MAGIA (Fire and Forget)
                        // Llamamos a la función de subida pero SIN ponerle "await". 
                        // Esto hace que la subida ocurra en las sombras mientras el código sigue avanzando.
                        _guardarTicketEnSupabase(pdfBytes, datosTicket['folio'].toString());

                        // 4. Devolvemos los bytes inmediatamente para que la pantalla los dibuje al instante
                        return pdfBytes;
                      },
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
                  onPressed: () {
                    // 1. Cerramos el modal del ticket
                    Navigator.pop(context);
                    
                    // 2. 👈 EJECUTAMOS LA FUNCIÓN LIMPIADORA (El "control remoto")
                    alCerrarTicket(); 
                  },
                  child: const Text('Cerrar'),
                )
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Función privada que construye el PDF
Future<Uint8List> _construirPdfEnFondo(Map<String, dynamic> datos) async {
  final pdf = pw.Document();

  // 1. Cargamos las fuentes con soporte Unicode
  final fontRegular = await PdfGoogleFonts.robotoRegular();
  final fontBold = await PdfGoogleFonts.robotoBold();

  // Cargamos la imagen 
  final logoBytes = datos['logoBytes'] as Uint8List;
  final logoImage = pw.MemoryImage(logoBytes);

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
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
                  pw.Text('Folio: ${datos['folio'].toString()}'),
                  pw.Text('Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                ]
              )
            ),

            pw.Divider(borderStyle: pw.BorderStyle.dashed),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('1x ${datos['nombre_producto'].toString()}')),
                pw.Text('\$${datos['subtotal'].toStringAsFixed(2)}'),
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
                pw.Text(datos['tamaño'].toString()),
              ]
            ),
            if (datos['tipoPan'].isNotEmpty)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Tipo de pan')),
                pw.Text(datos['tipoPan'].toString()),
              ]
            ),
            if (datos['categoria'].toString() == 'Pasteles')
            ...[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('Tipo de armado')),
                  pw.Text(datos['tipoArmado'].toString()),
                ]
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('Numero de pisos')),
                  pw.Text(datos['numeroPisos'].toString()),
                ]
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(child: pw.Text('Diseño')),
                  pw.Text(datos['diseño'].toString()),
                ]
              ),
            ],
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Mensaje')),
                pw.Text(datos['mensaje'].toString()),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Notas adicionales')),
                pw.Text(datos['notasAdicionales'].toString()),
              ]
            ),
            
            pw.Divider(borderStyle: pw.BorderStyle.dashed),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Cliente')),
                pw.Text(datos['cliente'].toString()),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Teléfono')),
                pw.Text(datos['telefono'].toString()),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Fecha de entrega')),
                pw.Text(datos['fechaEntrega'].toString()),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Hora de entrega')),
                pw.Text(datos['horaEntrega'].toString()),
              ]
            ),
            if (datos['direccionEntrega'].toString().isNotEmpty)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Dirección de entrega')),
                pw.Text(datos['direccionEntrega'].toString()),
              ]
            ),
            if (datos['direccionEntrega'].toString().isEmpty)
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
                pw.Text(datos['subtotal'].toStringAsFixed(2)),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Otros cargos')),
                pw.Text(datos['otrosCargos'].toStringAsFixed(2)),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Flete')),
                pw.Text(datos['flete'].toStringAsFixed(2)),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Anticipo')),
                pw.Text(datos['anticipo'].toStringAsFixed(2)),
              ]
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('Resto por pagar')),
                pw.Text(datos['restoPorPagar'].toStringAsFixed(2)),
              ]
            ),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('\$${datos['total'].toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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