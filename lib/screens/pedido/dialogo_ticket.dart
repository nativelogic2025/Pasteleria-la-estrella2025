import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Ancho imprimible real de papel térmico 80mm
// (80mm - ~4mm de cada lado que sujeta el mecanismo = 72mm)
final _roll72 = PdfPageFormat(
  72 * PdfPageFormat.mm,
  double.infinity,
  marginAll: 6, // 6pt ≈ 2.1mm márgen suave
);

void _guardarTicketEnSupabase(Uint8List pdfBytes, String folio) async {
  try {
    final supabase = Supabase.instance.client;
    final nombreArchivo = 'ticket_$folio.pdf';
    await supabase.storage.from('tickets').uploadBinary(
      nombreArchivo,
      pdfBytes,
      fileOptions: const FileOptions(
        contentType: 'application/pdf',
        upsert: true,
      ),
    );
    debugPrint('✅ Ticket $folio guardado en Supabase Storage');
  } catch (e) {
    debugPrint('❌ Error al subir el ticket: $e');
  }
}


/// Muestra el modal del ticket con vista previa del PDF
void mostrarModalTicketConDatos({
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 420,
            height: 640,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── Header éxito ─────────────────────────────────
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
                          color: Colors.green, size: 44),
                      const SizedBox(height: 6),
                      const Text('¡Pedido Confirmado!',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                      const SizedBox(height: 6),
                      Text(
                        'Folio: ${datosTicket['folio']}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8C5535),
                            letterSpacing: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Vista previa PDF ────────────────────────────────────
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: PdfPreview(
                      build: (format) async {
                        await Future.delayed(
                            const Duration(milliseconds: 300));
                        final pdfBytes =
                            await _construirPdfEnFondo(datosTicket);
                        _guardarTicketEnSupabase(
                            pdfBytes, datosTicket['folio'].toString());
                        return pdfBytes;
                      },
                      initialPageFormat: _roll72,
                      useActions: true,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Botón cerrar ────────────────────────────────────────
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
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    label: const Text('Cerrar y Nuevo Pedido',
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

/// Construye el PDF en un isolate secundario (requiere Map serializable)
Future<Uint8List> _construirPdfEnFondo(Map<String, dynamic> datos) async {
  final pdf = pw.Document();

  final fontRegular = await PdfGoogleFonts.robotoRegular();
  final fontBold    = await PdfGoogleFonts.robotoBold();

  final logoBytes = datos['logoBytes'] as Uint8List;
  // Sin forzar DPI — el tamaño se controla con width/height en pw.Image()
  final logoImage = pw.MemoryImage(logoBytes);

  // QR: generamos con la lib qr_flutter — pero en isolate no podemos usar UI
  // Usamos el barcode_widget de pdf en su lugar
  final folio = datos['folio'].toString();
  final bool pagoCompleto = datos['pagoCompleto'] == true;
  final double montoPagado   = (datos['montoPagado'] as num?)?.toDouble() ?? 0;
  final double montoRestante = (datos['montoRestante'] as num?)?.toDouble() ?? 0;
  final String metodoPago = datos['metodoPago']?.toString() ?? '';

  pdf.addPage(
    pw.Page(
      pageFormat: _roll72,
      margin: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Logo centrado — 45mm, proporcional al original
            pw.Center(
              child: pw.Image(logoImage,
                  width: 45 * PdfPageFormat.mm,
                  height: 45 * PdfPageFormat.mm,
                  fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(height: 6),
            pw.Text('PASTELERÍA LA ESTRELLA',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Tel: (55) 1234-5678 | pasteleriaestrella.com',
                style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 10),

            // Folio y fecha
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _pdfFila('Folio:', folio, bold: true),
                  _pdfFila('Fecha:',
                      '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                ],
              ),
            ),

            pw.Divider(borderStyle: pw.BorderStyle.dashed),

            // Producto
            _pdfFila('Producto:', datos['nombre_producto'].toString()),
            if (datos['cantidad'] != null && datos['cantidad'].toString().isNotEmpty)
              _pdfFila('Cantidad:', '${datos['cantidad']}x'),
            _pdfFila('Tamaño:', datos['tamaño'].toString()),
            if ((datos['tipoPan'] ?? '').toString().isNotEmpty)
              _pdfFila('Tipo de pan:', datos['tipoPan'].toString()),
            if (datos['categoria'].toString() == 'Pasteles') ...[
              _pdfFila('Armado:', datos['tipoArmado'].toString()),
              _pdfFila('Pisos:', datos['numeroPisos'].toString()),
              _pdfFila('Diseño:', datos['diseño'].toString()),
            ],
            if ((datos['mensaje'] ?? '').toString().isNotEmpty)
              _pdfFila('Mensaje:', datos['mensaje'].toString()),
            if ((datos['notasAdicionales'] ?? '').toString().isNotEmpty)
              _pdfFila('Notas:', datos['notasAdicionales'].toString()),

            pw.Divider(borderStyle: pw.BorderStyle.dashed),

            // Cliente / Entrega
            _pdfFila('Cliente:', datos['cliente'].toString()),
            _pdfFila('Teléfono:', datos['telefono'].toString()),
            _pdfFila('Entrega:', datos['fechaEntrega'].toString()),
            _pdfFila('Hora:', datos['horaEntrega'].toString()),
            if (datos['direccionEntrega'].toString().isNotEmpty)
              _pdfFila('Dirección:', datos['direccionEntrega'].toString())
            else
              _pdfFila('', 'Recoger en sucursal'),

            pw.Divider(borderStyle: pw.BorderStyle.dashed),

            // Precios
            _pdfFila('Subtotal:', '\$${(datos['subtotal'] as num).toStringAsFixed(2)}'),
            if ((datos['otrosCargos'] as num? ?? 0) > 0)
              _pdfFila('Otros cargos:', '\$${(datos['otrosCargos'] as num).toStringAsFixed(2)}'),
            if ((datos['flete'] as num? ?? 0) > 0)
              _pdfFila('Flete:', '\$${(datos['flete'] as num).toStringAsFixed(2)}'),

            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL:',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.Text('\$${(datos['total'] as num).toStringAsFixed(2)} MXN',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 13)),
              ],
            ),

            pw.Divider(borderStyle: pw.BorderStyle.dashed),

            // Estado de pago
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: pagoCompleto
                    ? PdfColors.green50
                    : PdfColors.orange50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    pagoCompleto ? '** LIQUIDADO **' : '-- ANTICIPO PAGADO --',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                        color: pagoCompleto
                            ? PdfColors.green800
                            : PdfColors.orange800),
                  ),
                  pw.SizedBox(height: 4),
                  _pdfFila('Método:', metodoPago),
                  _pdfFila('Monto pagado:',
                      '\$${montoPagado.toStringAsFixed(2)} MXN'),
                  if (!pagoCompleto)
                    _pdfFila('Pendiente:',
                        '\$${montoRestante.toStringAsFixed(2)} MXN'),
                ],
              ),
            ),

            pw.SizedBox(height: 12),

            // QR Code — apunta al PDF público en Supabase Storage
            pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: 'https://wvogrcteltoljtjvneyv.supabase.co'
                    '/storage/v1/object/public/tickets/ticket_$folio.pdf',
                width: 110,
                height: 110,
                drawText: false,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text('Escanea para ver tu ticket digital',
                  style: const pw.TextStyle(fontSize: 8)),
            ),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(folio,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),

            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text('¡Gracias por su preferencia!',
                  textAlign: pw.TextAlign.center),
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

pw.Widget _pdfFila(String label, String value, {bool bold = false}) =>
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.SizedBox(width: 4),
        pw.Flexible(
          child: pw.Text(value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ),
      ],
    );