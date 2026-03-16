import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() async {
  final pdf = pw.Document();

  final pageFormat = PdfPageFormat.a4.copyWith(
    marginTop: 30,
    marginBottom: 30,
    marginLeft: 30,
    marginRight: 30,
  );

  final regularFontData = File('assets/fonts/NotoSansTamil-Regular.ttf').readAsBytesSync();
  final boldFontData = File('assets/fonts/NotoSansTamil-Bold.ttf').readAsBytesSync();

  final ttfRegular = pw.Font.ttf(regularFontData.buffer.asByteData());
  final ttfBold = pw.Font.ttf(boldFontData.buffer.asByteData());

  pdf.addPage(
    pw.Page(
      pageFormat: pageFormat,
      theme: pw.ThemeData.withFont(
        base: ttfRegular,
        bold: ttfBold,
      ),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildTitle(),
            pw.SizedBox(height: 10),
            _buildHeaderInfo(),
            pw.SizedBox(height: 20),
            _buildTable(),
            pw.SizedBox(height: 20),
            _buildTotals(),
            pw.Spacer(),
            _buildFooter(),
          ],
        );
      },
    ),
  );

  final output = File('sample_invoice.pdf');
  await output.writeAsBytes(await pdf.save());
  print('Saved sample_invoice.pdf');
}

pw.Widget _buildTitle() {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Text('PD சென்ட்ரிங்',
        style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
      pw.SizedBox(height: 4),
      pw.Text('No: 6, Muthaiah Nagar, Medavakkam Main Road, Kovilambakkam, Chennai - 600 129.', style: pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 2),
      pw.Text('Cell: 9677000399, 9443135118, 9566155418', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 12),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1.0),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Text('ESTIMATION BILL', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ),
    ],
  );
}

pw.Widget _buildHeaderInfo() {
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.0)),
    padding: const pw.EdgeInsets.all(10),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Bill No: 1948', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text('Date: 01-04-2022', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text('Name: Vijayalashmi Constructions', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Vehicle No: PD', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Return Date: 30-04-2022', style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Phone: ', style: const pw.TextStyle(fontSize: 11)),
            pw.Text('Destination: Thoribakkam', style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildTable() {
  final headers = ['S.No', 'Description', 'Qty', 'Unit', 'Rate (₹)', 'Amount (₹)'];
  final data = [
    ['1', '12" Palagai (ft)', '24.0', 'ft', '12.00', '288.00'],
    ['2', '9" Palagai (ft)', '118.5', 'ft', '10.00', '1185.00'],
    ['3', '6" Palagai (ft)', '79.5', 'ft', '8.00', '636.00'],
    ['4', 'ரன்னர் (Runner) (ft)', '7.0', 'ft', '6.00', '42.00'],
    ['5', '3x2 Sheet (pcs)', '35.0', 'pcs', '30.00', '1050.00'],
  ];

  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: data,
    border: pw.TableBorder.all(color: PdfColors.black, width: 1.0),
    headerStyle: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellStyle: const pw.TextStyle(fontSize: 11),
    cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerLeft, 2: pw.Alignment.center, 3: pw.Alignment.center, 4: pw.Alignment.centerRight, 5: pw.Alignment.centerRight},
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  );
}

pw.Widget _buildTotals() {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(child: pw.SizedBox()),
      pw.Container(
        width: 300,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            _buildTotalRow('வாடகை', 3201.00),
            _buildTotalRow('UP வண்டிதொகை', 750.00),
            _buildTotalRow('டெப்பாசிட்', 0.0),
            pw.Divider(color: PdfColors.black, thickness: 1.0),
            _buildTotalRow('மொத்த தொகை', 3951.00, isBold: true),
            pw.Divider(color: PdfColors.black, thickness: 1.0),
            _buildTotalRow('வரவு', 0.0),
            pw.SizedBox(height: 4),
            _buildTotalRow('மீதி தொகை', 3951.00, isBold: true),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 12, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text('₹${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    ),
  );
}

pw.Widget _buildFooter() {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text('1. Materials must be returned in good condition.', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('2. Missing/damaged items will be charged separately.', style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.SizedBox(height: 50),
          pw.Text('Authorized Signature', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ],
  );
}
