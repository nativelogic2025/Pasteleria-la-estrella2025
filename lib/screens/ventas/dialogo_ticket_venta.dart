import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Ancho imprimible real de papel térmico 80mm = 72mm netos
final _roll72v = PdfPageFormat(
  72 * PdfPageFormat.mm,
  double.infinity,
  marginAll: 6,
);

// URL base de Supabase Storage (bucket: tickets)
const _supabaseUrl =
    'https://wvogrcteltoljtjvneyv.supabase.co/storage/v1/object/public/tickets';

// ─── Subida a Supabase ────────────────────────────────────────────────────────
void _guardarTicketVentaEnSupabase(Uint8List pdfBytes, String folio) async {
  try {
    final supabase = Supabase.instance.client;
    final nombreArchivo = 'ticket_venta_$folio.pdf';
    await supabase.storage.from('tickets').uploadBinary(
      nombreArchivo,
      pdfBytes,
      fileOptions: const FileOptions(
        contentType: 'application/pdf',
        upsert: true,
      ),
    );
    debugPrint('✅ Ticket de Venta $folio guardado en Supabase Storage');
  } catch (e) {
    debugPrint('❌ Error al subir el ticket de Venta: $e');
  }
}

// ─── Modal de ticket de venta ─────────────────────────────────────────────────
void mostrarModalTicketVenta({
  required BuildContext context,
  required Map<String, dynamic> datosTicket,
  required VoidCallback alCerrarTicket,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 420,
            height: 660,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── Header éxito ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 40),
                      const SizedBox(height: 6),
                      const Text('¡Venta Completada!',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                      const SizedBox(height: 4),
                      Text(
                        'Folio: ${datosTicket['folio']}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8C5535),
                            letterSpacing: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Vista previa PDF ──────────────────────────────────────
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PdfPreview(
                      build: (format) async {
                        await Future.delayed(const Duration(milliseconds: 300));
                        final pdfBytes =
                            await _construirPdfVentaEnFondo(datosTicket);
                        _guardarTicketVentaEnSupabase(
                            pdfBytes, datosTicket['folio'].toString());
                        return pdfBytes;
                      },
                      initialPageFormat: _roll72v,
                      useActions: true,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Botón cerrar ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8C5535),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      alCerrarTicket();
                    },
                    icon: const Icon(Icons.point_of_sale_rounded, size: 20),
                    label: const Text('Cerrar y Nueva Venta',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ─── Construcción del PDF en isolate ──────────────────────────────────────────
Future<Uint8List> _construirPdfVentaEnFondo(
    Map<String, dynamic> datos) async {
  final pdf       = pw.Document();
  final fontReg   = await PdfGoogleFonts.robotoRegular();
  final fontBold  = await PdfGoogleFonts.robotoBold();
  final logoBytes = datos['logoBytes'] as Uint8List;
  // Sin forzar DPI — el tamaño se controla con width en pw.Image()
  final logoImg   = pw.MemoryImage(logoBytes);

  final folio      = datos['folio'].toString();
  final total      = (datos['total'] as num?)?.toDouble() ?? 0;
  final metodo     = datos['metodoPago']?.toString() ?? '';
  final recibido   = (datos['pagoRecibido'] as num?)?.toDouble();
  final cambio     = (datos['cambio'] as num?)?.toDouble();
  final productos  = (datos['productos'] as List).cast<Map<String, dynamic>>();

  // URL pública del PDF para el QR
  final urlTicket = '$_supabaseUrl/ticket_venta_$folio.pdf';

  // Fecha y hora actuales
  final now      = DateTime.now();
  final fechaStr = '${now.day.toString().padLeft(2, '0')}/'
      '${now.month.toString().padLeft(2, '0')}/${now.year}';
  final horaStr  = '${now.hour.toString().padLeft(2, '0')}:'
      '${now.minute.toString().padLeft(2, '0')}';

  pdf.addPage(
    pw.Page(
      pageFormat: _roll72v,
      margin: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      theme: pw.ThemeData.withFont(base: fontReg, bold: fontBold),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Logo — 45mm, proporcional al original
            pw.Center(
              child: pw.Image(logoImg,
                  width: 45 * PdfPageFormat.mm,
                  height: 45 * PdfPageFormat.mm,
                  fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(height: 6),
            pw.Text('PASTELERIA LA ESTRELLA',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.Text('Venta de Mostrador',
                style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 10),

            // Folio / fecha / hora
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _vFila('Folio:', folio, bold: true),
                  _vFila('Fecha:', fechaStr),
                  _vFila('Hora:', horaStr),
                  _vFila('Metodo:', metodo.toUpperCase()),
                ],
              ),
            ),

            pw.Divider(borderStyle: pw.BorderStyle.dashed),

            // Encabezado tabla productos
            pw.Row(children: [
              pw.Expanded(
                  flex: 3,
                  child: pw.Text('Cant  Descripcion',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9))),
              pw.Text('Total',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ]),
            pw.SizedBox(height: 4),

            // Productos
            ...productos.map((prod) {
              final cant   = prod['cantidad'] as int? ?? 1;
              final nombre = prod['nombre']?.toString() ?? '';
              final precio = (prod['precio'] as num?)?.toDouble() ?? 0;
              final subP   = cant * precio;
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                        flex: 3,
                        child: pw.Text('${cant}x $nombre',
                            style: const pw.TextStyle(fontSize: 9))),
                    pw.Text('\$${subP.toStringAsFixed(2)}',
                        textAlign: pw.TextAlign.right,
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              );
            }),

            pw.Divider(borderStyle: pw.BorderStyle.dashed),

            // Total
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.Text('\$${total.toStringAsFixed(2)} MXN',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 13)),
              ],
            ),

            // Efectivo / cambio
            if (metodo == 'efectivo' && recibido != null) ...[
              pw.SizedBox(height: 4),
              _vFila('Recibido:', '\$${recibido.toStringAsFixed(2)}'),
              _vFila('Cambio:', '\$${(cambio ?? 0).toStringAsFixed(2)}'),
            ],

            pw.SizedBox(height: 8),

            // Badge PAGADO
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 6),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.green700, width: 1.5),
              ),
              child: pw.Center(
                child: pw.Text('** VENTA COMPLETADA **',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                        color: PdfColors.green800)),
              ),
            ),

            pw.SizedBox(height: 14),

            // QR Code
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: urlTicket,
                width: 110,
                height: 110,
                drawText: false,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text('Escanea para ver tu comprobante digital',
                  style: const pw.TextStyle(fontSize: 8)),
            ),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(folio,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),

            pw.SizedBox(height: 14),
            pw.Center(
              child: pw.Text('Gracias por su compra!',
                  textAlign: pw.TextAlign.center),
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

// ─── Helper fila PDF ──────────────────────────────────────────────────────────
pw.Widget _vFila(String label, String valor, {bool bold = false}) => pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(label,
        style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    pw.SizedBox(width: 4),
    pw.Flexible(
      child: pw.Text(valor,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    ),
  ],
);
