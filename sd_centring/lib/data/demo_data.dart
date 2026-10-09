import '../config/brand.dart';
import '../core/dates.dart';
import '../models/customer.dart';
import '../models/rental.dart';

/// Sample records for demo mode, dated relative to [today] so every status
/// (expired, today, soon, active, returned) is visible on first launch.
({List<Customer> customers, List<Rental> rentals}) demoData(DateTime today) {
  final created = DateTime(today.year, today.month, today.day);
  final c1 = Customer(
    id: 'demo-c1',
    name: 'Murugan Builders',
    phone: '9840012345',
    address: 'Tambaram',
    createdAt: created,
  );
  final c2 = Customer(
    id: 'demo-c2',
    name: 'Lakshmi Constructions',
    phone: '9876543210',
    address: 'Medavakkam',
    createdAt: created,
  );
  final c3 = Customer(
    id: 'demo-c3',
    name: 'Ravi Kumar',
    phone: '9123456780',
    createdAt: created,
  );

  Rental rental(
    String id,
    int n,
    Customer c,
    String site,
    int issuedAgo,
    int expiresIn,
    List<RentalItem> items, [
    List<ReturnEntry> returns = const [],
  ]) => Rental(
    id: id,
    dcNumber: '${Brand.dcPrefix}$n',
    customerId: c.id,
    customerName: c.name,
    site: site,
    issuedOn: addDays(today, -issuedAgo),
    expiresOn: addDays(today, expiresIn),
    items: items,
    returns: returns,
    createdAt: created,
    updatedAt: created,
  );

  return (
    customers: [c1, c2, c3],
    rentals: [
      rental(
        'demo-r1',
        1001,
        c1,
        'Selaiyur',
        34,
        -4,
        const [
          RentalItem(id: 'i1', name: 'Column Box', qty: 24),
          RentalItem(id: 'i2', name: 'Props', qty: 40),
        ],
        [
          ReturnEntry(
            id: 'x1',
            itemId: 'i2',
            qty: 15,
            date: addDays(today, -6),
          ),
        ],
      ),
      rental('demo-r2', 1002, c2, 'Velachery', 30, 0, const [
        RentalItem(id: 'i1', name: 'Side Sheet', qty: 60),
      ]),
      rental('demo-r3', 1003, c3, '', 13, 2, const [
        RentalItem(id: 'i1', name: 'Palagai', qty: 120, unit: 'ft'),
      ]),
      rental('demo-r4', 1004, c1, 'Chitlapakkam', 5, 25, const [
        RentalItem(id: 'i1', name: 'Span', qty: 18),
        RentalItem(id: 'i2', name: 'Roof Sheet', qty: 50),
      ]),
      rental(
        'demo-r5',
        1005,
        c2,
        'Pallikaranai',
        40,
        -10,
        const [RentalItem(id: 'i1', name: 'Muttu', qty: 30)],
        [
          ReturnEntry(
            id: 'x1',
            itemId: 'i1',
            qty: 30,
            date: addDays(today, -11),
          ),
        ],
      ),
    ],
  );
}
