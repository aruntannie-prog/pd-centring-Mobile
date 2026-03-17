import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/bill.dart';
import '../models/customer.dart';
import '../models/store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

const _uuid = Uuid();

class ConsolidateBillScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSaved;
  final VoidCallback onAddNewCustomer;
  final Customer? lastCreatedCustomer;
  final String branch;

  const ConsolidateBillScreen({
    super.key,
    required this.onBack,
    required this.onSaved,
    required this.onAddNewCustomer,
    this.lastCreatedCustomer,
    this.branch = '',
  });

  @override
  State<ConsolidateBillScreen> createState() => _ConsolidateBillScreenState();
}

class _ConsolidateBillScreenState extends State<ConsolidateBillScreen> {
  String _customerName = '';
  String _customerId = '';
  final _siteCtrl = TextEditingController();
  final _billNumCtrl = TextEditingController();
  final _vehicleUpCtrl = TextEditingController();
  final _vehicleDownCtrl = TextEditingController();
  final _labourUpCtrl = TextEditingController();
  final _labourDownCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController();
  bool _gstEnabled = false;
  DateTime _billDate = DateTime.now();
  List<Bill> _availableDCs = [];
  List<String> _selectedDcIds = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        _billNumCtrl.text =
            context.read<AppStore>().nextBillNumber(BillType.bill);
      }
    });
  }

  @override
  void didUpdateWidget(ConsolidateBillScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastCreatedCustomer != null &&
        widget.lastCreatedCustomer != oldWidget.lastCreatedCustomer) {
      final c = widget.lastCreatedCustomer!;
      setState(() {
        _customerName = c.name;
        _customerId = c.id;
        if (_siteCtrl.text.isEmpty) _siteCtrl.text = c.site;
      });
      _loadDCs();
    }
  }

  bool get _isDirty =>
      _customerName.isNotEmpty || _selectedDcIds.isNotEmpty;

  Future<void> _handleBack() async {
    if (!_isDirty) {
      widget.onBack();
      return;
    }
    final leave = await showUnsavedChangesDialog(context);
    if (leave && mounted) widget.onBack();
  }

  @override
  void dispose() {
    _siteCtrl.dispose();
    _billNumCtrl.dispose();
    _vehicleUpCtrl.dispose();
    _vehicleDownCtrl.dispose();
    _labourUpCtrl.dispose();
    _labourDownCtrl.dispose();
    _advanceCtrl.dispose();
    super.dispose();
  }

  void _loadDCs() {
    if (_customerId.isEmpty) return;
    setState(() {
      _availableDCs = context.read<AppStore>().getUnbilledDCs(_customerId);
      _selectedDcIds
          .removeWhere((id) => !_availableDCs.any((dc) => dc.id == id));
    });
  }

  List<Bill> get _selectedDCs =>
      _availableDCs.where((dc) => _selectedDcIds.contains(dc.id)).toList();

  double get _dcRentTotal =>
      _selectedDCs.fold(0.0, (s, dc) => s + dc.rentTotal);
  double get _vehicleUp => double.tryParse(_vehicleUpCtrl.text) ?? 0.0;
  double get _vehicleDown => double.tryParse(_vehicleDownCtrl.text) ?? 0.0;
  double get _labourUp => double.tryParse(_labourUpCtrl.text) ?? 0.0;
  double get _labourDown => double.tryParse(_labourDownCtrl.text) ?? 0.0;
  double get _advance => double.tryParse(_advanceCtrl.text) ?? 0.0;
  double get _grandTotal => _dcRentTotal + _vehicleUp + _vehicleDown + _labourUp + _labourDown;
  double get _sgst => _gstEnabled ? _grandTotal * 0.09 : 0.0;
  double get _cgst => _gstEnabled ? _grandTotal * 0.09 : 0.0;
  double get _totalWithGst => _grandTotal + _sgst + _cgst;
  double get _balanceDue => (_gstEnabled ? _totalWithGst : _grandTotal) - _advance;

  String _fmt(DateTime d) {
    const mo = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${mo[d.month - 1]} ${d.year}';
  }

  Future<void> _generate() async {
    if (_customerName.isEmpty) {
      _snack('Please select a customer');
      return;
    }
    if (_selectedDcIds.isEmpty) {
      _snack('Please select at least one DC');
      return;
    }
    if (_billNumCtrl.text.trim().isEmpty) {
      _snack('Please enter a bill number');
      return;
    }

    final allMaterials =
        _selectedDCs.expand((dc) => dc.materials).toList();
    final allColumnBoxes =
        _selectedDCs.expand((dc) => dc.columnBoxes).toList();
    final allRoundBoxes =
        _selectedDCs.expand((dc) => dc.roundBoxes).toList();
    final allSideSheets =
        _selectedDCs.expand((dc) => dc.sideSheets).toList();
    final allPalagai =
        _selectedDCs.expand((dc) => dc.palagai).toList();
    final allMuttu =
        _selectedDCs.expand((dc) => dc.muttu).toList();
    final allRoofItems =
        _selectedDCs.expand((dc) => dc.roofItems).toList();

    final site = _siteCtrl.text.trim().isNotEmpty
        ? _siteCtrl.text.trim()
        : _selectedDCs.first.site;

    final bill = Bill(
      id: _uuid.v4(),
      billNumber: _billNumCtrl.text.trim(),
      type: BillType.bill,
      customerName: _customerName,
      customerId: _customerId,
      site: site,
      billDate: _billDate,
      branch: widget.branch,
      materials: allMaterials,
      columnBoxes: allColumnBoxes,
      roundBoxes: allRoundBoxes,
      sideSheets: allSideSheets,
      palagai: allPalagai,
      muttu: allMuttu,
      roofItems: allRoofItems,
      vehicleChargeUp: _vehicleUp,
      vehicleChargeDown: _vehicleDown,
      labourChargeUp: _labourUp,
      labourChargeDown: _labourDown,
      gstEnabled: _gstEnabled,
      advancePaid: _advance,
      linkedDcIds: _selectedDcIds,
    );

    await context.read<AppStore>().consolidateDCsToBill(bill, _selectedDcIds);
    widget.onSaved();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFFF5555),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      bottom: false,
      child: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: _handleBack,
              behavior: HitTestBehavior.opaque,
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    border: Border.all(color: colors.border, width: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: colors.textMain),
                ),
                const SizedBox(width: 12),
                Text('Cancel',
                    style: jakarta(context,
                        size: 14,
                        weight: FontWeight.w700,
                        color: colors.textSub)),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                border: Border.all(color: colors.border, width: 0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text('📋   CONSOLIDATE DCs → BILL',
                  style: jakarta(context,
                          size: 9,
                          weight: FontWeight.w800,
                          color: colors.textSub)
                      .copyWith(letterSpacing: 2)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Text.rich(TextSpan(children: [
                TextSpan(
                    text: 'New ',
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: colors.textMain)),
                TextSpan(
                    text: 'Bill',
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: colors.teal,
                        fontStyle: FontStyle.italic)),
              ])),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _billNumCtrl,
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colors.textMuted),
                  decoration: InputDecoration(
                    hintText: '# Number',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: colors.border),
                        borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: colors.border),
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
          ]),
        ),

        // ── Body ────────────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: 100 + keyboardHeight),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Step 1 — Customers with unbilled DCs
              _StepHeader(step: '1', label: 'SELECT CUSTOMER'),
              const SizedBox(height: 8),
              Builder(builder: (ctx) {
                final unbilledCustomerIds = store.bills
                    .where((b) => b.type == BillType.dc && !b.isBilled)
                    .map((b) => b.customerId)
                    .toSet();
                final eligible = store.customers
                    .where((c) => unbilledCustomerIds.contains(c.id))
                    .toList();
                if (eligible.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border, width: 0.5),
                    ),
                    child: Center(
                      child: Text(
                        'No customers with unbilled DC bills',
                        style: jakarta(context, size: 13, color: colors.textMuted),
                      ),
                    ),
                  );
                }
                return Column(
                  children: eligible.map((c) {
                    final isSelected = _customerId == c.id;
                    final dcCount = store.bills
                        .where((b) => b.type == BillType.dc && !b.isBilled && b.customerId == c.id)
                        .length;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _customerName = c.name;
                          _customerId = c.id;
                          if (_siteCtrl.text.isEmpty) _siteCtrl.text = c.site;
                        });
                        _loadDCs();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.brand.withOpacity(0.1) : colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? colors.brand : colors.border,
                            width: isSelected ? 1.5 : 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: isSelected ? colors.brand.withOpacity(0.15) : colors.surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                    style: jakarta(context, size: 16, weight: FontWeight.w900,
                                        color: isSelected ? colors.brand : colors.textSub)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.name,
                                      style: jakarta(context, size: 14, weight: FontWeight.w700,
                                          color: isSelected ? colors.brand : colors.textMain)),
                                  Text('$dcCount unbilled DC${dcCount != 1 ? 's' : ''} · ${c.phone}',
                                      style: jakarta(context, size: 11, color: colors.textMuted)),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded, color: colors.brand, size: 20),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 24),

              // Step 2 — Select DCs
              _StepHeader(step: '2', label: 'SELECT DCs TO CONSOLIDATE'),
              const SizedBox(height: 8),
              if (_customerId.isEmpty)
                _InfoHint(
                    icon: Icons.info_outline_rounded,
                    text: 'Select a customer to see their unbilled DCs',
                    colors: colors)
              else if (_availableDCs.isEmpty)
                _InfoHint(
                    icon: Icons.check_circle_outline_rounded,
                    text: 'No unbilled DCs found for this customer',
                    colors: colors,
                    iconColor: colors.teal)
              else
                ..._availableDCs.map((dc) {
                  final isOn = _selectedDcIds.contains(dc.id);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isOn) {
                        _selectedDcIds.remove(dc.id);
                      } else {
                        _selectedDcIds.add(dc.id);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isOn
                            ? colors.brand.withValues(alpha: 0.06)
                            : colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color:
                                isOn ? colors.brand : colors.border,
                            width: isOn ? 1.5 : 0.5),
                        boxShadow: [
                          BoxShadow(
                              color: colors.glow,
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isOn
                                ? colors.brand
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color:
                                    isOn ? colors.brand : colors.border,
                                width: 1.5),
                          ),
                          child: isOn
                              ? const Icon(Icons.check_rounded,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(dc.billNumber,
                                    style: jakarta(context,
                                        size: 14,
                                        weight: FontWeight.w800,
                                        color: isOn
                                            ? colors.brand
                                            : colors.textMain)),
                                const SizedBox(height: 2),
                                Text(
                                    '${dc.billDateFormatted}  ·  ${dc.site}',
                                    style: jakarta(context,
                                        size: 11,
                                        color: colors.textMuted)),
                                if (dc.materials.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: dc.materials
                                        .take(4)
                                        .map((m) => Container(
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                  color: colors
                                                      .surfaceVariant,
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(6)),
                                              child: Text(m.name,
                                                  style: jakarta(
                                                      context,
                                                      size: 10,
                                                      color: colors
                                                          .textSub)),
                                            ))
                                        .toList(),
                                  ),
                                ],
                                if (dc.columnBoxes.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                      '${dc.columnBoxes.length} column box size(s)',
                                      style: jakarta(context,
                                          size: 10,
                                          color: colors.textMuted)),
                                ],
                                if (dc.roundBoxes.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                      '${dc.roundBoxes.length} round box size(s)',
                                      style: jakarta(context,
                                          size: 10,
                                          color: colors.textMuted)),
                                ],
                              ]),
                        ),
                        const SizedBox(width: 8),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  '₹${dc.rentTotal.toStringAsFixed(0)}',
                                  style: jakarta(context,
                                      size: 15,
                                      weight: FontWeight.w800,
                                      color: isOn
                                          ? colors.brand
                                          : colors.textMain)),
                              Text('rent',
                                  style: jakarta(context,
                                      size: 10,
                                      color: colors.textMuted)),
                            ]),
                      ]),
                    ),
                  );
                }),

              // Steps 3–5 appear once at least one DC is selected
              if (_selectedDcIds.isNotEmpty) ...[
                const SizedBox(height: 24),

                // Step 3 — Preview
                _StepHeader(
                    step: '3',
                    label: 'BILL PREVIEW — MATERIALS BY DC'),
                const SizedBox(height: 8),
                ..._selectedDCs
                    .map((dc) => _buildDcCard(dc, colors, isDark)),

                const SizedBox(height: 24),

                // Step 4 — Bill details
                _StepHeader(step: '4', label: 'BILL DETAILS'),
                const SizedBox(height: 8),
                Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('SITE / LOCATION',
                                  style: jakarta(context,
                                          size: 10,
                                          weight: FontWeight.w700,
                                          color: colors.textMuted)
                                      .copyWith(letterSpacing: 1)),
                              const SizedBox(height: 6),
                              _ConField(
                                  hint: 'Auto-filled from DC...',
                                  colors: colors,
                                  controller: _siteCtrl),
                            ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text('BILL DATE',
                                  style: jakarta(context,
                                          size: 10,
                                          weight: FontWeight.w700,
                                          color: colors.textMuted)
                                      .copyWith(letterSpacing: 1)),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () async {
                                  final picked =
                                      await showDatePicker(
                                    context: context,
                                    initialDate: _billDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now().add(
                                        const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setState(
                                        () => _billDate = picked);
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14),
                                  decoration: BoxDecoration(
                                    color: colors.surface,
                                    border: Border.all(
                                        color: colors.border,
                                        width: 0.5),
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                          color: colors.glow,
                                          blurRadius: 12,
                                          offset:
                                              const Offset(0, 4))
                                    ],
                                  ),
                                  child: Text(_fmt(_billDate),
                                      style: jakarta(context,
                                          size: 13,
                                          color: colors.textMain)),
                                ),
                              ),
                            ]),
                      ),
                    ]),

                const SizedBox(height: 24),

                // Step 5 — Financial summary
                _StepHeader(
                    step: '5', label: 'FINANCIAL SUMMARY'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color:
                        colors.surfaceVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: colors.border, width: 0.5),
                  ),
                  child: Column(children: [
                    // Per-DC breakdown
                    ..._selectedDCs.map((dc) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(dc.billNumber,
                                    style: jakarta(context,
                                        size: 12,
                                        weight: FontWeight.w600,
                                        color: colors.textSub)),
                                Text(
                                    '₹${dc.rentTotal.toStringAsFixed(2)}',
                                    style: jakarta(context,
                                        size: 12,
                                        weight: FontWeight.w700,
                                        color: colors.textMain)),
                              ]),
                        )),
                    Divider(
                        height: 16,
                        thickness: 0.5,
                        color: colors.border),
                    Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Rent',
                              style: jakarta(context,
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: colors.textSub)),
                          Text(
                              '₹${_dcRentTotal.toStringAsFixed(2)}',
                              style: jakarta(context,
                                  size: 14,
                                  weight: FontWeight.w800,
                                  color: colors.textMain)),
                        ]),
                    const SizedBox(height: 12),
                    _ConChargeRow(
                        label: 'Vehicle Charge (UP)',
                        ctrl: _vehicleUpCtrl,
                        colors: colors,
                        onChanged: () => setState(() {})),
                    const SizedBox(height: 8),
                    _ConChargeRow(
                        label: 'Vehicle Charge (DOWN)',
                        ctrl: _vehicleDownCtrl,
                        colors: colors,
                        onChanged: () => setState(() {})),
                    const SizedBox(height: 8),
                    _ConChargeRow(
                        label: 'Labour Charge (UP)',
                        ctrl: _labourUpCtrl,
                        colors: colors,
                        onChanged: () => setState(() {})),
                    const SizedBox(height: 8),
                    _ConChargeRow(
                        label: 'Labour Charge (DOWN)',
                        ctrl: _labourDownCtrl,
                        colors: colors,
                        onChanged: () => setState(() {})),
                    Divider(
                        height: 24,
                        thickness: 0.5,
                        color: colors.border),
                    Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text('GRAND TOTAL',
                              style: jakarta(context,
                                  size: 14,
                                  weight: FontWeight.w800,
                                  color: colors.textMain)),
                          Text(
                              '₹${_grandTotal.toStringAsFixed(2)}',
                              style:
                                  GoogleFonts.playfairDisplay(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: colors.teal)),
                        ]),
                    const SizedBox(height: 16),
                    // GST Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _gstEnabled ? colors.tealBg : colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _gstEnabled ? colors.tealBd : colors.border, width: 0.5),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('GST Billing (18%)',
                                style: jakarta(context, size: 13, weight: FontWeight.w700, color: colors.textMain)),
                            Text('SGST 9% + CGST 9%',
                                style: jakarta(context, size: 11, color: colors.textMuted)),
                          ]),
                        ),
                        Switch(
                          value: _gstEnabled,
                          activeColor: colors.teal,
                          onChanged: (v) => setState(() => _gstEnabled = v),
                        ),
                      ]),
                    ),
                    if (_gstEnabled) ...[
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('SGST (9%)', style: jakarta(context, size: 13, weight: FontWeight.w600, color: colors.textMuted)),
                        Text('₹${_sgst.toStringAsFixed(0)}', style: jakarta(context, size: 13, weight: FontWeight.w700, color: colors.textMuted)),
                      ]),
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('CGST (9%)', style: jakarta(context, size: 13, weight: FontWeight.w600, color: colors.textMuted)),
                        Text('₹${_cgst.toStringAsFixed(0)}', style: jakarta(context, size: 13, weight: FontWeight.w700, color: colors.textMuted)),
                      ]),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Total incl. GST', style: jakarta(context, size: 14, weight: FontWeight.w800, color: colors.textMain)),
                        Text('₹${_totalWithGst.toStringAsFixed(0)}',
                            style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w900, color: colors.teal)),
                      ]),
                    ],
                    Divider(
                        height: 24,
                        thickness: 0.5,
                        color: colors.border),
                    _ConChargeRow(
                        label: 'Advance Paid',
                        ctrl: _advanceCtrl,
                        colors: colors,
                        onChanged: () => setState(() {})),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: colors.tealBg,
                          borderRadius:
                              BorderRadius.circular(12)),
                      child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('BALANCE DUE',
                                style: jakarta(context,
                                    size: 12,
                                    weight: FontWeight.w800,
                                    color: colors.teal)),
                            Text(
                                '₹${_balanceDue.toStringAsFixed(2)}',
                                style:
                                    GoogleFonts.playfairDisplay(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: colors.teal)),
                          ]),
                    ),
                  ]),
                ),

                const SizedBox(height: 32),

                // Generate button
                GestureDetector(
                  onTap: _generate,
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                const Color(0xFF097A6B),
                                const Color(0xFF075A4E)
                              ]
                            : [
                                const Color(0xFF0CAF98),
                                const Color(0xFF097A6B)
                              ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF0CAF98)
                                .withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          const Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.white,
                              size: 22),
                          const SizedBox(width: 10),
                          Text('GENERATE BILL',
                              style: jakarta(context,
                                      size: 15,
                                      weight: FontWeight.w800,
                                      color: Colors.white)
                                  .copyWith(letterSpacing: 1)),
                        ]),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildDcCard(Bill dc, AppColors colors, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // DC header bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            color: colors.brand.withValues(alpha: 0.06),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            border:
                Border(bottom: BorderSide(color: colors.border, width: 0.5)),
          ),
          child: Row(children: [
            Icon(Icons.local_shipping_rounded,
                size: 15, color: colors.brand),
            const SizedBox(width: 8),
            Text(dc.billNumber,
                style: jakarta(context,
                    size: 13,
                    weight: FontWeight.w800,
                    color: colors.brand)),
            const SizedBox(width: 8),
            Text('·  ${dc.billDateFormatted}',
                style: jakarta(context, size: 11, color: colors.textMuted)),
            const Spacer(),
            Text('₹${dc.rentTotal.toStringAsFixed(0)}',
                style: jakarta(context,
                    size: 13,
                    weight: FontWeight.w800,
                    color: colors.brand)),
          ]),
        ),
        // Materials list
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dc.materials.isEmpty &&
                    dc.columnBoxes.isEmpty &&
                    dc.roundBoxes.isEmpty &&
                    dc.sideSheets.isEmpty &&
                    dc.palagai.isEmpty &&
                    dc.muttu.isEmpty &&
                    dc.roofItems.isEmpty)
                  Text('No materials',
                      style:
                          jakarta(context, size: 12, color: colors.textMuted)),
                ...dc.materials.map((m) => _MatLine(
                    dot: colors.brand,
                    label: m.name,
                    detail: m.quantity > 0
                        ? '${m.quantity.toStringAsFixed(0)} ${m.unit}'
                        : null,
                    amount: m.amount > 0
                        ? '₹${m.amount.toStringAsFixed(0)}'
                        : null,
                    colors: colors,
                    context: context)),
                ...dc.columnBoxes.map((b) => _MatLine(
                    dot: colors.indigo,
                    label: 'Column Box ${b.sizeKey}',
                    detail:
                        b.totalQty > 0 ? '${b.totalQty} pcs' : null,
                    amount: b.totalAmount > 0
                        ? '₹${b.totalAmount.toStringAsFixed(0)}'
                        : null,
                    colors: colors,
                    context: context)),
                ...dc.roundBoxes.map((b) => _MatLine(
                    dot: colors.teal,
                    label: 'Round Box ${b.sizeKey}',
                    detail:
                        b.totalQty > 0 ? '${b.totalQty} pcs' : null,
                    amount: b.totalAmount > 0
                        ? '₹${b.totalAmount.toStringAsFixed(0)}'
                        : null,
                    colors: colors,
                    context: context)),
                ...dc.sideSheets.map((e) => _MatLine(
                    dot: colors.amber,
                    label: '${e.sheetType} Sheet · Size ${e.size}',
                    detail: '${e.qty} pcs · ${e.sqft.toStringAsFixed(1)} sqft',
                    amount: e.amount > 0
                        ? '₹${e.amount.toStringAsFixed(0)}'
                        : null,
                    colors: colors,
                    context: context)),
                ...dc.palagai.map((e) => _MatLine(
                    dot: colors.amber,
                    label: 'Palagai ${e.length} · ${e.size}',
                    detail: '${e.qty} pcs',
                    amount: e.amount > 0
                        ? '₹${e.amount.toStringAsFixed(0)}'
                        : null,
                    colors: colors,
                    context: context)),
                ...dc.muttu.map((e) => _MatLine(
                    dot: colors.amber,
                    label: 'Muttu ${e.length} · ${e.size}',
                    detail: '${e.qty} pcs',
                    amount: e.amount > 0
                        ? '₹${e.amount.toStringAsFixed(0)}'
                        : null,
                    colors: colors,
                    context: context)),
                ...dc.roofItems.map((e) => _MatLine(
                    dot: colors.indigo,
                    label: e.itemName,
                    detail: '${e.qty} pcs',
                    amount: e.amount > 0
                        ? '₹${e.amount.toStringAsFixed(0)}'
                        : null,
                    colors: colors,
                    context: context)),
              ]),
        ),
      ]),
    );
  }
}

// ── Local helper widgets ──────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final String step, label;
  const _StepHeader({required this.step, required this.label});
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(children: [
      Container(
        width: 24,
        height: 24,
        decoration:
            BoxDecoration(color: colors.brand, shape: BoxShape.circle),
        child: Center(
            child: Text(step,
                style: jakarta(context,
                    size: 11,
                    weight: FontWeight.w800,
                    color: Colors.white))),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: jakarta(context,
                  size: 11,
                  weight: FontWeight.w800,
                  color: context.appColors.textMuted)
              .copyWith(letterSpacing: 1)),
    ]);
  }
}

class _InfoHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final AppColors colors;
  final Color? iconColor;
  const _InfoHint(
      {required this.icon,
      required this.text,
      required this.colors,
      this.iconColor});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border, width: 0.5),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: iconColor ?? colors.textMuted),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style:
                      jakarta(context, size: 13, color: colors.textMuted))),
        ]),
      );
}

class _ConField extends StatelessWidget {
  final String hint;
  final AppColors colors;
  final TextEditingController controller;
  final FocusNode? focusNode;
  const _ConField(
      {required this.hint,
      required this.colors,
      required this.controller,
      this.focusNode});
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        focusNode: focusNode,
        style: jakarta(context, size: 13, color: colors.textMain),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: jakarta(context, size: 13, color: colors.textMuted),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.border, width: 0.5)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.border, width: 0.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: colors.brand, width: 1.5)),
          filled: true,
          fillColor: colors.surface,
        ),
      );
}

class _ConChargeRow extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final AppColors colors;
  final VoidCallback onChanged;
  const _ConChargeRow(
      {required this.label,
      required this.ctrl,
      required this.colors,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            flex: 2,
            child: Text(label,
                style: jakarta(context,
                    size: 13,
                    weight: FontWeight.w600,
                    color: colors.textSub))),
        Expanded(
          flex: 1,
          child: TextFormField(
            controller: ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
            ],
            textAlign: TextAlign.right,
            style: jakarta(context, size: 13, color: colors.textMain),
            decoration: InputDecoration(
              hintText: '0.00',
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.border, width: 0.5)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.border, width: 0.5)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colors.brand, width: 1.5)),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
      ]);
}

class _MatLine extends StatelessWidget {
  final Color dot;
  final String label;
  final String? detail;
  final String? amount;
  final AppColors colors;
  final BuildContext context;
  const _MatLine(
      {required this.dot,
      required this.label,
      this.detail,
      this.amount,
      required this.colors,
      required this.context});
  @override
  Widget build(BuildContext ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  color: dot.withValues(alpha: 0.6),
                  shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label,
              style: jakarta(context,
                  size: 12,
                  weight: FontWeight.w600,
                  color: colors.textMain)),
          if (detail != null) ...[
            const SizedBox(width: 4),
            Text('– $detail',
                style:
                    jakarta(context, size: 11, color: colors.textMuted)),
          ],
          const Spacer(),
          if (amount != null)
            Text(amount!,
                style: jakarta(context,
                    size: 11,
                    weight: FontWeight.w700,
                    color: colors.textMain)),
        ]),
      );
}
