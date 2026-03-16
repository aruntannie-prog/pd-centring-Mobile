import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../models/store.dart';
import '../models/customer.dart';
import '../widgets/cors_image.dart';

class CustomersScreen extends StatefulWidget {
  final VoidCallback onAddCustomer;
  final Function(Customer) onCustomerTap;
  const CustomersScreen(
      {super.key, required this.onAddCustomer, required this.onCustomerTap});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  static const _avatarColors = [
    [Color(0xFF2563EB), Color(0xFF1E3A8A)],
    [Color(0xFFD97706), Color(0xFF78350F)],
    [Color(0xFF059669), Color(0xFF064E3B)],
    [Color(0xFFDC2626), Color(0xFF7C2D12)],
    [Color(0xFF7C3AED), Color(0xFF312E81)],
    [Color(0xFF0891B2), Color(0xFF164E63)],
    [Color(0xFF16A34A), Color(0xFF14532D)],
    [Color(0xFFEA580C), Color(0xFF7C2D12)],
  ];

  String _filter = 'All';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var customers = store.customers;
    if (_search.isNotEmpty) {
      customers = customers
          .where((c) =>
              c.name.toLowerCase().contains(_search.toLowerCase()) ||
              c.phone.contains(_search))
          .toList();
    }

    final total = store.totalCustomers;

    return Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant,
                  border: Border.all(color: colors.border, width: 0.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text('◎   DIRECTORY',
                    style: jakarta(context,
                            size: 9,
                            weight: FontWeight.w800,
                            color: colors.textSub)
                        .copyWith(letterSpacing: 2))),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Customers',
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: colors.brand,
                        fontStyle: FontStyle.italic)),
                GestureDetector(
                  onTap: widget.onAddCustomer,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.brand,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: colors.brand.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Text('+ ADD',
                        style: jakarta(context,
                            size: 12,
                            weight: FontWeight.w800,
                            color: colors.surface)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('$total registered profiles',
                style: jakarta(context, size: 13, color: colors.textMuted)),
          ]),
        ),
        // Body
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(children: [
              SearchBar2(
                  hint: 'Search name or phone...',
                  count: '${customers.length}',
                  onChanged: (v) => setState(() => _search = v)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: ['All', 'Pending Bills', 'Top Clients'].map((l) {
                    final on = l == _filter;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = l),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: on ? colors.brand : colors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: on ? colors.brand : colors.border,
                              width: 0.5),
                          boxShadow: on
                              ? [
                                  BoxShadow(
                                      color: colors.brand.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2))
                                ]
                              : [
                                  BoxShadow(
                                      color: colors.glow,
                                      blurRadius: 4,
                                      offset: const Offset(0, 2))
                                ],
                        ),
                        child: Text(l,
                            style: jakarta(context,
                                size: 11,
                                weight: FontWeight.w700,
                                color: on ? colors.surface : colors.textSub)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: !store.loaded
                    ? Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 3, color: colors.brand))
                    : customers.isEmpty
                        ? Center(
                            child: Text('No customers found',
                                style: jakarta(context,
                                    size: 13, color: colors.textMuted)))
                        : ListView.builder(
                        padding: EdgeInsets.only(
                            bottom:
                                95 + MediaQuery.of(context).padding.bottom),
                        itemCount: customers.length,
                        itemBuilder: (_, i) {
                          final c = customers[i];
                          final avColors =
                              _avatarColors[i % _avatarColors.length];
                          final liveBillCount = store.bills
                              .where((b) => b.customerId == c.id)
                              .length;
                          return GestureDetector(
                            onTap: () => widget.onCustomerTap(c),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                border: Border.all(
                                    color: colors.border, width: 0.5),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                      color: colors.glow,
                                      blurRadius: 16,
                                      offset: const Offset(0, 4))
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    clipBehavior: Clip.hardEdge,
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: c.profilePhotoUrl.isEmpty
                                            ? LinearGradient(
                                                colors: avColors,
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : null,
                                        boxShadow: [
                                          BoxShadow(
                                              color:
                                                  avColors[0].withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4))
                                        ]),
                                    child: c.profilePhotoUrl.isNotEmpty
                                        ? CORSResilientImage(
                                            imageUrl: c.profilePhotoUrl,
                                            fit: BoxFit.cover,
                                            placeholder: Center(
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: colors.brand)),
                                            errorWidget: Center(
                                              child: Text(
                                                  c.name
                                                      .substring(0, 1)
                                                      .toUpperCase(),
                                                  style: GoogleFonts
                                                      .playfairDisplay(
                                                          fontSize: 22,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          color: colors.textMain)),
                                            ),
                                          )
                                        : Center(
                                            child: Text(
                                                c.name
                                                    .substring(0, 1)
                                                    .toUpperCase(),
                                                style:
                                                    GoogleFonts.playfairDisplay(
                                                        fontSize: 22,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: Colors.white)),
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(c.name,
                                              style: jakarta(context,
                                                  size: 15,
                                                  weight: FontWeight.w800,
                                                  color: colors.textMain)),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.location_on_rounded,
                                                  size: 12,
                                                  color: colors.textMuted),
                                              const SizedBox(width: 4),
                                              Text(
                                                  c.address.isEmpty
                                                      ? 'No address'
                                                      : (c.address.length > 20
                                                          ? '${c.address.substring(0, 20)}...'
                                                          : c.address),
                                                  style: jakarta(context,
                                                      size: 11,
                                                      color: colors.textMuted)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: isDark
                                                    ? const Color(0xFF2A1F0D)
                                                    : const Color(0xFFFFF9EE),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF70521F)
                                                        : const Color(
                                                            0xFFFFDCA8),
                                                    width: 0.5)),
                                            child: Text(
                                                'Ref: ${c.referBy.isEmpty ? 'Direct' : c.referBy}',
                                                style: jakarta(context,
                                                    size: 9,
                                                    weight: FontWeight.w700,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFFFC043)
                                                        : const Color(
                                                            0xFFB18000))),
                                          ),
                                        ]),
                                  ),
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                              color: colors.surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: colors.border,
                                                  width: 0.5)),
                                          child: Text('$liveBillCount bill${liveBillCount == 1 ? '' : 's'}',
                                              style: jakarta(context,
                                                  size: 10,
                                                  weight: FontWeight.w800,
                                                  color: colors.textSub)),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            if (!c.isActive)
                                              const Icon(Icons.warning_rounded,
                                                  size: 12,
                                                  color: Color(0xFFFF5555)),
                                            if (!c.isActive)
                                              const SizedBox(width: 4),
                                            Text(
                                                !c.isActive
                                                    ? 'Pending'
                                                    : liveBillCount == 0
                                                        ? 'New'
                                                        : 'Active',
                                                style: jakarta(context,
                                                    size: 10,
                                                    weight: FontWeight.w800,
                                                    color: !c.isActive
                                                        ? const Color(0xFFFF5555)
                                                        : liveBillCount == 0
                                                            ? colors.textSub
                                                            : colors.teal)),
                                          ],
                                        ),
                                      ]), // Column
                                ]), // Row
                              ), // Padding
                            ), // Container
                          ); // GestureDetector
                        },
                      ),
              ),
            ]),
          ),
        ),
      ]);
  }
}
