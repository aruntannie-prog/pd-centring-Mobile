import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bill.dart';
import 'pdf_downloader.dart';

class InvoiceService {
  // ── Static asset cache ─────────────────────────────────────────────
  // Populated once in preloadAssets(). Subsequent calls reuse these.
  static pw.MemoryImage? _cachedTemplate;
  static pw.Font? _cachedTtfRegular;
  static pw.Font? _cachedTtfBold;
  static pw.Font? _cachedRoboto;
  static pw.Font? _cachedRobotoBold;

  /// Call this early (e.g. in initState of BillDetailScreen) to load
  /// assets in the background BEFORE the user taps "Print/Share PDF".
  /// Safe to call multiple times — only loads once.
  static Future<void> preloadAssets() async {
    if (_cachedTemplate != null) return; // Already loaded

    await Future.delayed(Duration.zero); // yield to UI first

    final templateBytes = await rootBundle.load('assets/images/invoice_template_clean.png');
    _cachedTemplate = pw.MemoryImage(templateBytes.buffer.asUint8List());

    await Future.delayed(Duration.zero);

    final fontData     = await rootBundle.load('assets/fonts/NotoSansTamil-Regular.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/NotoSansTamil-Bold.ttf');
    final robotoData   = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final robotoBoldData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');

    _cachedTtfRegular = pw.Font.ttf(fontData.buffer.asByteData());
    _cachedTtfBold    = pw.Font.ttf(fontBoldData.buffer.asByteData());
    _cachedRoboto     = pw.Font.ttf(robotoData.buffer.asByteData());
    _cachedRobotoBold = pw.Font.ttf(robotoBoldData.buffer.asByteData());
  }

  /// Generates the invoice PDF and returns it as bytes.
  /// If [preloadAssets] was called earlier, asset loading is skipped.
  static Future<Uint8List> generateInvoice(Bill bill) async {
    final pdf = pw.Document();

    final pageFormat = PdfPageFormat.a4.copyWith(
      marginTop: 0,
      marginBottom: 0,
      marginLeft: 0,
      marginRight: 0,
    );

    // Use cached assets if available; otherwise load now
    if (_cachedTemplate == null) await preloadAssets();

    final templateImage = _cachedTemplate!;
    final ttfRegular    = _cachedTtfRegular!;
    final ttfBold       = _cachedTtfBold!;
    final roboto        = _cachedRoboto!;
    final robotoBold    = _cachedRobotoBold!;

    // Yield before building the PDF so the spinner can paint one more frame
    await Future.delayed(Duration.zero);

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        theme: pw.ThemeData(
        defaultTextStyle: pw.TextStyle(
          font: roboto,
          fontFallback: [ttfRegular],
        ),
      ),
        build: (pw.Context context) {
          return pw.Container(
            width: pageFormat.width,
            height: pageFormat.height,
            decoration: pw.BoxDecoration(
              image: pw.DecorationImage(
                image: templateImage,
                fit: pw.BoxFit.fill,
              ),
            ),
            child: pw.Stack(
              children: [
                // 1. Header Information
                pw.Positioned(left: 88, top: 112, child: pw.Text('${bill.billNumber}', style: pw.TextStyle(font: roboto, fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black))),
                pw.Positioned(left: 70, top: 129, child: pw.Text('${bill.customerName}', style: pw.TextStyle(font: roboto, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black))),
                // bill.customerId is typically the phone number in this app structure
                if (bill.customerId.isNotEmpty)
                  pw.Positioned(left: 432, top: 129, child: pw.Text('${bill.customerId}', style: pw.TextStyle(font: roboto, fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black))),
                if (bill.site != null && bill.site!.isNotEmpty)
                  pw.Positioned(left: 70, top: 144, child: pw.Text('${bill.site}', style: pw.TextStyle(font: roboto, fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.black))),
                pw.Positioned(left: 105, top: 205, child: pw.Text('PD', style: pw.TextStyle(font: roboto, fontSize: 10, color: PdfColors.black))),
                pw.Positioned(left: 439, top: 203, child: pw.Text('${bill.billDate.day.toString().padLeft(2, '0')}-${bill.billDate.month.toString().padLeft(2, '0')}-${bill.billDate.year}', style: pw.TextStyle(font: roboto, fontSize: 10, color: PdfColors.black))),

                // Consolidated DCs info
                if (bill.linkedDcIds.isNotEmpty)
                  pw.Positioned(
                    left: 70, 
                    top: 158, 
                    child: pw.Text('Consolidated from: ${bill.linkedDcIds.length} DCs', style: pw.TextStyle(font: roboto, fontSize: 8, color: PdfColors.grey700))
                  ),

                // 2. Dynamic Items List (Spanning the full scrubbed width)
                // 2. Dynamic Items (Rendering quantities over the scrubbed right box area)
                // The right area inner box bounds are X: 249 to 525, Y: 245 to 350.
                pw.Positioned(
                  left: 255, 
                  top: 250, 
                  child: pw.Container(
                    width: 265,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: bill.materials.map((m) {
                        return pw.Padding(
                          padding: pw.EdgeInsets.only(bottom: 6),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Container(
                                width: 110,
                                child: pw.Text('${m.name}', style: pw.TextStyle(font: robotoBold, fontFallback: [ttfRegular], fontSize: 10, color: PdfColors.black)),
                              ),
                              pw.Container(
                                width: 85,
                                alignment: pw.Alignment.center,
                                child: pw.Text('${m.quantity.toString().replaceAll(RegExp(r'\\.0\$'), '')} x ${m.rate.toString().replaceAll(RegExp(r'\\.0\$'), '')} x ${m.days}', style: pw.TextStyle(font: roboto, fontSize: 10, color: PdfColors.black)),
                              ),
                              pw.Container(
                                width: 60,
                                alignment: pw.Alignment.centerRight,
                                child: pw.Text('${(m.quantity * m.rate * (m.days > 0 ? m.days : 1)).toStringAsFixed(2)}', style: pw.TextStyle(font: robotoBold, fontSize: 10, color: PdfColors.black)),
                              ),
                            ]
                          )
                        );
                      }).toList(),
                    )
                  )
                ),

                // Map specific left-side quantities if the name matches standard expectations
                // ..._buildLeftMatrixQuantities(bill, robotoBold, ttfBold),

                
                // 3. Totals Box
                pw.Positioned(left: 529, top: 355, child: pw.Container(width: 48, alignment: pw.Alignment.centerRight, child: pw.Text('${_calculateSubtotal(bill).toStringAsFixed(2)}', style: pw.TextStyle(font: roboto, fontSize: 10, color: PdfColors.black)))),
                pw.Positioned(left: 529, top: 373, child: pw.Container(width: 48, alignment: pw.Alignment.centerRight, child: pw.Text('${bill.vehicleChargeUp.toStringAsFixed(2)}', style: pw.TextStyle(font: roboto, fontSize: 10, color: PdfColors.black)))),
                pw.Positioned(left: 529, top: 394, child: pw.Container(width: 48, alignment: pw.Alignment.centerRight, child: pw.Text('0.00', style: pw.TextStyle(font: roboto, fontSize: 10, color: PdfColors.black)))),
                pw.Positioned(left: 529, top: 412, child: pw.Container(width: 48, alignment: pw.Alignment.centerRight, child: pw.Text('${_calculateTotal(bill).toStringAsFixed(2)}', style: pw.TextStyle(font: roboto, fontSize: 10, color: PdfColors.black)))),
                pw.Positioned(left: 529, top: 429, child: pw.Container(width: 48, alignment: pw.Alignment.centerRight, child: pw.Text('${(bill.advancePaid ?? 0.0).toStringAsFixed(2)}', style: pw.TextStyle(font: roboto, fontSize: 10, color: PdfColors.black)))),
                pw.Positioned(left: 529, top: 446, child: pw.Container(width: 48, alignment: pw.Alignment.centerRight, child: pw.Text('${_calculateBalance(bill).toStringAsFixed(2)}', style: pw.TextStyle(font: roboto, fontSize: 10, color: PdfColors.black)))),
              ],
            ),
          );
        },
      ),
    );

    // Yield before the most expensive step: encoding the PDF bytes
    await Future.delayed(Duration.zero);
    return pdf.save();
  }

  static double _calculateSubtotal(Bill bill) {
    return bill.materials.fold(0, (sum, item) => sum + (item.quantity * item.rate * (item.days > 0 ? item.days : 1)));
  }

  static double _calculateTotal(Bill bill) {
    return _calculateSubtotal(bill) + bill.vehicleChargeUp + bill.vehicleChargeDown;
  }

  static double _calculateBalance(Bill bill) {
    return _calculateTotal(bill) - (bill.advancePaid ?? 0.0);
  }


  static pw.Widget _buildTitle(Bill bill, pw.Font ttfBold, pw.Font robotoBold) {
    return pw.Stack(
      children: [
        // Center content
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              bill.type == BillType.bill ? 'ESTIMATION BILL' : 'DELIVERY CHALLAN',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'PD சென்டரிங்ஸ்',
              style: pw.TextStyle(
                font: robotoBold,
                fontFallback: [ttfBold],
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red900,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'நேரு முக்லையா நகர், மெடவாக்கம் மெயின் ரோடு,\nகோவிலம்பாக்கம், சென்னை - 600 129.',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
        // Top right content
        pw.Positioned(
          right: 0,
          top: 0,
          child: pw.Text(
            'செல்: 9677000399\n         9443135118\n         9566155418',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red900,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildHeaderInfo(Bill bill) {
    // 2-column grid layout without outer borders
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left Column
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInfoRow('பில் எண்', bill.billNumber.toString()),
                pw.SizedBox(height: 4),
                _buildInfoRow('பெயர்', bill.customerName, isBoldValue: true),
                pw.SizedBox(height: 4),
                _buildInfoRow('முகவரி', '-'), // Address usually in customer profile, omitting for now
                pw.SizedBox(height: 4),
                _buildInfoRow('வண்டி எண்', 'PD'),
              ],
            ),
          ),
          // Right Column
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInfoRow('தேதி', bill.billDateFormatted),
                pw.SizedBox(height: 4),
                _buildInfoRow('போன்நம்பர்', '-'), // Phone usually in customer profile
                pw.SizedBox(height: 4),
                _buildInfoRow('செல்லுமிடம்', bill.site.isNotEmpty ? bill.site : '-'),
                pw.SizedBox(height: 4),
                _buildInfoRow('ரிட்டன் தேதி', ''),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value, {bool isBoldValue = false}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 80,
          child: pw.Text('$label', style: const pw.TextStyle(fontSize: 11)),
        ),
        pw.Text(' : ', style: const pw.TextStyle(fontSize: 11)),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isBoldValue ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTable(Bill bill, pw.Font ttfBold, pw.Font robotoBold) {
    // Left half is just descriptive, right half is the table
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 2.0),
          bottom: pw.BorderSide(width: 2.0),
        ),
      ),
      child: pw.Column(
        children: [
          // Header row
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('பொருளடக்கம்', style: pw.TextStyle(font: robotoBold, fontFallback: [ttfBold], fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('தொகை ரூ', style: pw.TextStyle(font: robotoBold, fontFallback: [ttfBold], fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.Divider(thickness: 1.0),
          // Content
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left side - Dimensions (We don't have this data, leaving blank)
              pw.Expanded(
                flex: 3,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.SizedBox(height: 100), // Min height
                ),
              ),
              // Right side - Pricing Summary
              pw.Expanded(
                flex: 4,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Table(
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(1),
                      3: const pw.FlexColumnWidth(1.5),
                    },
                    children: [
                      // Sub headers
                      pw.TableRow(
                        children: [
                          pw.Text('Item Name', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Qty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ]
                      ),
                      pw.TableRow(children: [pw.SizedBox(height: 4), pw.SizedBox(height: 4), pw.SizedBox(height: 4), pw.SizedBox(height: 4)]),
                      // Data: Materials
                      ...bill.materials.map((m) {
                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 2),
                              child: pw.Text(m.name, style: const pw.TextStyle(fontSize: 11)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 2),
                              child: pw.Text('${m.quantity.toStringAsFixed(0)} ${m.unit}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 2),
                              child: pw.Text(m.rate.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 2),
                              child: pw.Text(m.amount.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11)),
                            ),
                          ]
                        );
                      }).toList(),
                      // Data: Column Boxes
                      ...bill.columnBoxes.expand((b) {
                        final rows = <pw.TableRow>[];
                        for (final r in b.heightRows) {
                          if (r.qty > 0) {
                            rows.add(
                              pw.TableRow(
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                    child: pw.Text('Col Box ${b.sizeKey} (${r.heightFt}ft)', style: const pw.TextStyle(fontSize: 11)),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                    child: pw.Text('${r.qty} pcs', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11)),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                    child: pw.Text(r.rate.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11)),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                    child: pw.Text(r.amount.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11)),
                                  ),
                                ]
                              )
                            );
                          }
                        }
                        if (b.shoe != null && b.shoe!.qty > 0) {
                          rows.add(
                            pw.TableRow(
                              children: [
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                  child: pw.Text('Col Shoe ${b.sizeKey}', style: const pw.TextStyle(fontSize: 11)),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                  child: pw.Text('${b.shoe!.qty} pcs', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11)),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                  child: pw.Text(b.shoe!.rate.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11)),
                                ),
                                pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                                  child: pw.Text(b.shoe!.amount.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 11)),
                                ),
                              ]
                            )
                          );
                        }
                        return rows;
                      }).toList(),
                    ]
                  ),
                ),
              ),
            ],
          ),
        ],
      )
    );
  }

  static pw.Widget _buildTotals(Bill bill) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: pw.SizedBox()), // empty left side
        pw.Container(
          width: 250,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _buildTotalRow('வாடகை', bill.rentTotal),
              _buildTotalRow('UPவண்டித் தொகை', bill.vehicleChargeUp),
              _buildTotalRow('டெப்பாசிட்', 0.0),
              pw.Divider(color: PdfColors.black, thickness: 1.0),
              _buildTotalRow('மொத்த தொகை', bill.grandTotal, isBold: true),
              pw.Divider(color: PdfColors.black, thickness: 1.0),
              _buildTotalRow('வரவு', bill.advancePaid),
              pw.SizedBox(height: 4),
              _buildTotalRow('மீதி தொகை', bill.balanceDue, isBold: true),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTotalRow(String label, double amount,
      {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                fontSize: 11,
                color: PdfColors.teal900,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              )),
          pw.Text(amount.toStringAsFixed(2),
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              )),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Font ttfBold, pw.Font robotoBold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Box 1: Receiver Signature & rules
        pw.Container(
          width: 180,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border.all(width: 0.5)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('பொருள் எடுப்பவர் கையொப்பம்', style: pw.TextStyle(font: robotoBold, fontFallback: [ttfBold], fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 30),
              pw.Text('குறிப்பு: வாடகை பொருள் உடைந்தால்,\nதொலைந்தால் முழு பணம் வசூலிக்கப்படும்.',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.red900)),
            ],
          ),
        ),
        // Box 2: Blessing
        pw.Container(
          width: 140,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border.all(width: 0.5)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('வாழ்க வளமுடன்', style: pw.TextStyle(font: robotoBold, fontFallback: [ttfBold], fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('பொருட்கள் நல்ல முறையில்\nதிரும்ப ஒப்படைக்கப்பட வேண்டும்.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ),
        // Box 3: Company Signature
        pw.Container(
          width: 140,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border.all(width: 0.5)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('for PD சென்டரிங்ஸ்', style: pw.TextStyle(font: robotoBold, fontFallback: [ttfBold], fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('நேரம்: காலை 8:00 முதல்\nமாலை 5:00 வரை',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        ),
      ],
    );
  }

  /// Print or Download the invoice
  static Future<void> printInvoice(Bill bill) async {
    final bytes = await generateInvoice(bill);
    final filename = 'Invoice_${bill.billNumber}.pdf';

    if (kIsWeb) {
      await downloadPdfWeb(bytes, filename);
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: filename,
      );
    }
  }

  /// Share the invoice
  static Future<void> shareInvoice(Bill bill) async {
    final bytes = await generateInvoice(bill);
    final filename = 'Invoice_${bill.billNumber}.pdf';

    if (kIsWeb) {
      await downloadPdfWeb(bytes, filename);
    } else {
      await Printing.sharePdf(bytes: bytes, filename: filename);
    }
  }
}

class _Point {
  final double x;
  final double y;
  const _Point(this.x, this.y);
}
