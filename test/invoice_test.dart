import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pd_centring/models/bill.dart';
import 'package:pd_centring/services/invoice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate exact sample pdf', () async {
    final now = DateTime(2022, 4, 1);
    final due = DateTime(2022, 4, 30);
    final dummyBill = Bill(
      id: 'dummy_123',
      customerId: 'cust_1',
      customerName: 'Vijayalashmi Constructions',
      site: 'Thoribakkam',
      billDate: now,
      billNumber: "1948",
      type: BillType.bill,
      materials: [
        RentalMaterial(name: '12" Palagai', quantity: 24.0, unit: 'ft', rate: 12.0, days: 30, dueDate: due),
        RentalMaterial(name: '9" Palagai', quantity: 118.5, unit: 'ft', rate: 10.0, days: 30, dueDate: due),
        RentalMaterial(name: '6" Palagai', quantity: 79.5, unit: 'ft', rate: 8.0, days: 30, dueDate: due),
        RentalMaterial(name: 'ரன்னர் (Runner)', quantity: 7.0, unit: 'ft', rate: 6.0, days: 30, dueDate: due),
        RentalMaterial(name: '3x2 Sheet', quantity: 35.0, unit: 'pcs', rate: 30.0, days: 30, dueDate: due),
      ],
      vehicleChargeUp: 750.0,
      vehicleChargeDown: 0.0,
      advancePaid: 0.0,
    );

    final bytes = await InvoiceService.generateInvoice(dummyBill);
    final output = File('sample_invoice_final.pdf');
    await output.writeAsBytes(bytes);
    print('Successfully saved sample_invoice_final.pdf');
  });
}
