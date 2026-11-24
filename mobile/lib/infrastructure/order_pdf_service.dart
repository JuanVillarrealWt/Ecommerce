import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/order.dart';

class OrderPdfService {
  static final _ink = PdfColor.fromInt(0xFF24563B);
  static final _accent = PdfColor.fromInt(0xFF4F8A5B);
  static final _pale = PdfColor.fromInt(0xFFE7F3E8);
  static final _muted = PdfColor.fromInt(0xFF65736F);
  static final _line = PdfColor.fromInt(0xFFC9DEC9);

  static Future<Uint8List> build(OrderModel order) async {
    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 38, 42, 42),
        footer: (context) => pw.Column(
          children: [
            pw.Container(height: 1, color: _accent),
            pw.SizedBox(height: 9),
            pw.Text(
              'Gracias por tu compra en Entre Cumbres',
              style: pw.TextStyle(color: _ink, fontSize: 10),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Comprobante informativo generado desde el sistema de ventas.',
              style: pw.TextStyle(color: _muted, fontSize: 7),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(color: _muted, fontSize: 7),
            ),
          ],
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ),
            decoration: pw.BoxDecoration(
              color: _pale,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ENTRE CUMBRES',
                      style: pw.TextStyle(
                        color: _ink,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Comprobante de compra',
                      style: pw.TextStyle(color: _accent, fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      order.name,
                      style: pw.TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Fecha: ${_formatDate(order.createdAt)}',
                      style: pw.TextStyle(color: _accent, fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _infoCard('COMPRADOR', [
                  order.partnerName,
                  'Código de cliente: ${order.partnerId}',
                ]),
              ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: _infoCard('DETALLES DEL PEDIDO', [
                  'Referencia: ${order.name}',
                  'Estado: ${order.received ? 'Recibido' : _status(order.state)}',
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            'ARTÍCULOS DEL PEDIDO',
            style: pw.TextStyle(
              color: _ink,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 9),
          if (order.items.isEmpty)
            pw.Text(
              'No se recibieron líneas de detalle para este pedido.',
              style: pw.TextStyle(color: _muted, fontSize: 9),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                '#',
                'Código',
                'Descripción',
                'Cant.',
                'P. unitario',
                'Subtotal',
              ],
              data: [
                for (var index = 0; index < order.items.length; index++)
                  [
                    '${index + 1}',
                    '${order.items[index].productId}',
                    order.items[index].productName,
                    '${order.items[index].quantity}',
                    _money(order.items[index].unitPrice),
                    _money(order.items[index].subtotal),
                  ],
              ],
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: pw.BoxDecoration(color: _ink),
              cellStyle: pw.TextStyle(color: _ink, fontSize: 8),
              cellHeight: 27,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.center,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FixedColumnWidth(23),
                1: const pw.FixedColumnWidth(43),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FixedColumnWidth(42),
                4: const pw.FixedColumnWidth(66),
                5: const pw.FixedColumnWidth(66),
              },
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(color: _line, width: .5),
                bottom: pw.BorderSide(color: _line, width: .7),
              ),
            ),
          pw.SizedBox(height: 22),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 285,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: pw.BoxDecoration(
                color: _pale,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _summaryLine(
                          'Subtotal sin impuestos',
                          _money(order.amountUntaxed),
                        ),
                        pw.SizedBox(height: 6),
                        _summaryLine(
                          'IVA / impuestos',
                          _money(order.amountTax),
                        ),
                        pw.Divider(color: _line),
                        _summaryLine(
                          'TOTAL DEL PEDIDO',
                          _money(order.amountTotal),
                          bold: true,
                          large: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  static pw.Widget _infoCard(String heading, List<String> lines) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _line),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              heading,
              style: pw.TextStyle(
                color: _ink,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 7),
            for (var index = 0; index < lines.length; index++) ...[
              pw.Text(
                lines[index],
                style: pw.TextStyle(
                  color: index == 0 ? _ink : _muted,
                  fontSize: index == 0 ? 10 : 8,
                  fontWeight: index == 0
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
              if (index < lines.length - 1) pw.SizedBox(height: 4),
            ],
          ],
        ),
      );

  static pw.Widget _summaryLine(
    String label,
    String value, {
    bool bold = false,
    bool large = false,
  }) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          color: _ink,
          fontSize: large ? 11 : 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(
          color: _ink,
          fontSize: large ? 13 : 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    ],
  );

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static String _status(String state) => switch (state) {
    'sale' || 'done' => 'Confirmado',
    'cancel' => 'Cancelado',
    _ => 'Cotización',
  };

  static String _money(double amount) => '\$${amount.toStringAsFixed(2)}';
}
