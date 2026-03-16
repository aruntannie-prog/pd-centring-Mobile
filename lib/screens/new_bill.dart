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
import '../widgets/rate_card_picker.dart';
import '../data/rate_card.dart';
import 'invoice_preview.dart';

const _uuid = Uuid();

class NewBillScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSaved;
  final VoidCallback onAddNewCustomer;
  final Customer? lastCreatedCustomer;
  final Bill? initialBill;
  final String branch;
  const NewBillScreen(
      {super.key,
      required this.onBack,
      required this.onSaved,
      required this.onAddNewCustomer,
      this.lastCreatedCustomer,
      this.initialBill,
      this.branch = ''});
  @override
  State<NewBillScreen> createState() => _NewBillScreenState();
}

class _NewBillScreenState extends State<NewBillScreen>
    with SingleTickerProviderStateMixin {
  BillType _type = BillType.dc;
  String _customerName = '';
  String _customerId = '';
  final _siteCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _billNumCtrl = TextEditingController();
  final _vehicleUpCtrl = TextEditingController();
  final _vehicleDownCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController();
  final _labourUpCtrl = TextEditingController();
  final _labourDownCtrl = TextEditingController();
  bool _gstEnabled = false;
  final List<MatEntry> _mats = [];
  List<ColumnSizeBlock> _columnBoxes = [];
  DateTime _baseDate = DateTime.now();
  String _selectedBranch = '';
  late final TabController _matTabController;

  // Round Box tab state
  String? _selectedRoundBoxSize;
  final List<String> _addedRbSizes = [];
  final Map<String, Set<int>> _addedRbHeights = {};
  final Map<String, bool> _rbShoeAdded = {};
  final Map<String, Map<int, TextEditingController>> _rbQtyControllers = {};
  final Map<String, Map<int, TextEditingController>> _rbRateControllers = {};
  final Map<String, TextEditingController> _rbShoeQtyControllers = {};
  final Map<String, TextEditingController> _rbShoeRateControllers = {};
  final Map<String, TextEditingController> _rbDaysControllers = {};
  final Map<String, Map<int, TextEditingController>> _rbHeightDaysCtrl = {};
  List<ColumnSizeBlock> _roundBoxes = [];

  // Column Box tab state
  String? _selectedColumnBoxSize;
  final List<String> _addedSizes = [];
  final Map<String, Set<int>> _addedHeights = {};
  final Map<String, bool> _shoeAdded = {};
  final Map<String, Map<int, TextEditingController>> _qtyControllers = {};
  final Map<String, Map<int, TextEditingController>> _rateControllers = {};
  final Map<String, TextEditingController> _shoeQtyControllers = {};
  final Map<String, TextEditingController> _shoeRateControllers = {};
  final Map<String, TextEditingController> _cbDaysControllers = {};
  final Map<String, Map<int, TextEditingController>> _cbHeightDaysCtrl = {};

  // Side Sheet tab state
  static const _ssTypes = ['24', '21', '18', '15', '12', '9'];
  static const _ssSizes = [8, 7, 6, 5, 4, 3, 2];
  String? _selectedSsType;
  // Card-ID based state (allows same type multiple times)
  final List<String> _ssCardIds = [];
  final Map<String, String> _ssCardTypes = {}; // cardId -> type ('24','21',...)
  final Map<String, Set<int>> _addedSsSizes = {};
  final Map<String, Map<int, TextEditingController>> _ssQtyCtrl = {};
  final Map<String, Map<int, TextEditingController>> _ssRateCtrl = {};
  final Map<String, Map<int, TextEditingController>> _ssDaysCtrl = {};

  @override
  void initState() {
    super.initState();
    _matTabController = TabController(length: 6, vsync: this)
      ..addListener(() {
        if (!_matTabController.indexIsChanging) setState(() {});
      });
    if (widget.initialBill != null) {
      final b = widget.initialBill!;
      _type = b.type;
      _customerName = b.customerName;
      _customerId = b.customerId;
      _siteCtrl.text = b.site;
      _baseDate = b.billDate;
      for (final m in b.materials) {
        _mats.add(MatEntry(
          name: m.name,
          days: m.days,
          quantity: m.quantity,
          unit: m.unit,
          rate: m.rate,
        ));
      }
      // Load round boxes (deep copy) + populate new UI state
      _roundBoxes = b.roundBoxes.map((cb) => ColumnSizeBlock.fromJson(cb.toJson())).toList();
      for (final cb in b.roundBoxes) {
        _addedRbSizes.add(cb.sizeKey);
        _addedRbHeights[cb.sizeKey] = {};
        _rbShoeAdded[cb.sizeKey] = cb.shoe != null;
        _rbQtyControllers[cb.sizeKey] = {};
        _rbRateControllers[cb.sizeKey] = {};
        _rbDaysControllers[cb.sizeKey] =
            TextEditingController(text: cb.days > 0 ? '${cb.days}' : '');
        _rbHeightDaysCtrl[cb.sizeKey] = {};
        for (final row in cb.heightRows) {
          _addedRbHeights[cb.sizeKey]!.add(row.heightFt);
          _rbQtyControllers[cb.sizeKey]![row.heightFt] =
              TextEditingController(text: row.qty > 0 ? '${row.qty}' : '');
          _rbRateControllers[cb.sizeKey]![row.heightFt] =
              TextEditingController(text: row.rate > 0 ? row.rate.toStringAsFixed(0) : '');
          _rbHeightDaysCtrl[cb.sizeKey]![row.heightFt] =
              TextEditingController(text: row.days > 0 ? '${row.days}' : '');
        }
        if (cb.shoe != null) {
          _rbShoeQtyControllers[cb.sizeKey] =
              TextEditingController(text: cb.shoe!.qty > 0 ? '${cb.shoe!.qty}' : '');
          _rbShoeRateControllers[cb.sizeKey] =
              TextEditingController(text: cb.shoe!.rate > 0 ? cb.shoe!.rate.toStringAsFixed(0) : '');
        }
      }

      // Load column boxes (deep copy) + populate new UI state
      _columnBoxes = b.columnBoxes.map((cb) => ColumnSizeBlock.fromJson(cb.toJson())).toList();
      for (final cb in b.columnBoxes) {
        _addedSizes.add(cb.sizeKey);
        _addedHeights[cb.sizeKey] = {};
        _shoeAdded[cb.sizeKey] = cb.shoe != null;
        _qtyControllers[cb.sizeKey] = {};
        _rateControllers[cb.sizeKey] = {};
        _cbDaysControllers[cb.sizeKey] =
            TextEditingController(text: cb.days > 0 ? '${cb.days}' : '');
        _cbHeightDaysCtrl[cb.sizeKey] = {};
        for (final row in cb.heightRows) {
          _addedHeights[cb.sizeKey]!.add(row.heightFt);
          _qtyControllers[cb.sizeKey]![row.heightFt] =
              TextEditingController(text: row.qty > 0 ? '${row.qty}' : '');
          _rateControllers[cb.sizeKey]![row.heightFt] =
              TextEditingController(text: row.rate > 0 ? row.rate.toStringAsFixed(0) : '');
          _cbHeightDaysCtrl[cb.sizeKey]![row.heightFt] =
              TextEditingController(text: row.days > 0 ? '${row.days}' : '');
        }
        if (cb.shoe != null) {
          _shoeQtyControllers[cb.sizeKey] =
              TextEditingController(text: cb.shoe!.qty > 0 ? '${cb.shoe!.qty}' : '');
          _shoeRateControllers[cb.sizeKey] =
              TextEditingController(text: cb.shoe!.rate > 0 ? cb.shoe!.rate.toStringAsFixed(0) : '');
        }
      }
      _billNumCtrl.text = b.billNumber;
      _vehicleUpCtrl.text =
          b.vehicleChargeUp > 0 ? b.vehicleChargeUp.toString() : '';
      _vehicleDownCtrl.text =
          b.vehicleChargeDown > 0 ? b.vehicleChargeDown.toString() : '';
      _advanceCtrl.text =
          b.advancePaid > 0 ? b.advancePaid.toString() : '';
      _labourUpCtrl.text = b.labourChargeUp > 0 ? b.labourChargeUp.toString() : '';
      _labourDownCtrl.text = b.labourChargeDown > 0 ? b.labourChargeDown.toString() : '';
      _gstEnabled = b.gstEnabled;
      // Load side sheets — group by sheetType, one card per type
      final Map<String, List<SideSheetEntry>> ssGrouped = {};
      for (final e in b.sideSheets) {
        ssGrouped.putIfAbsent(e.sheetType, () => []).add(e);
      }
      for (final type in ssGrouped.keys) {
        final id = _uuid.v4();
        _ssCardIds.add(id);
        _ssCardTypes[id] = type;
        _addedSsSizes[id] = {};
        _ssQtyCtrl[id] = {};
        _ssRateCtrl[id] = {};
        _ssDaysCtrl[id] = {};
        for (final e in ssGrouped[type]!) {
          _addedSsSizes[id]!.add(e.size);
          _ssQtyCtrl[id]![e.size] =
              TextEditingController(text: e.qty > 0 ? '${e.qty}' : '')
                ..addListener(() => setState(() {}));
          _ssRateCtrl[id]![e.size] =
              TextEditingController(text: e.rate > 0 ? e.rate.toStringAsFixed(0) : '')
                ..addListener(() => setState(() {}));
          _ssDaysCtrl[id]![e.size] =
              TextEditingController(text: e.days > 0 ? '${e.days}' : '');
        }
      }
    } else {
      _selectedBranch = widget.branch;
      Future.microtask(() {
        if (mounted) {
          _billNumCtrl.text = context.read<AppStore>().nextBillNumber(_type);
        }
      });
    }
  }

  @override
  void didUpdateWidget(NewBillScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastCreatedCustomer != null &&
        widget.lastCreatedCustomer != oldWidget.lastCreatedCustomer) {
      final c = widget.lastCreatedCustomer!;
      setState(() {
        _customerName = c.name;
        _customerId = c.id;
        _siteCtrl.text = c.site;
        _phoneCtrl.text = c.phone;
        _gstCtrl.text = c.gstNumber;
      });
    }
  }

  @override
  void dispose() {
    _matTabController.dispose();
    _siteCtrl.dispose();
    _phoneCtrl.dispose();
    _gstCtrl.dispose();
    _billNumCtrl.dispose();
    _vehicleUpCtrl.dispose();
    _vehicleDownCtrl.dispose();
    _advanceCtrl.dispose();
    _labourUpCtrl.dispose();
    _labourDownCtrl.dispose();
    for (final m in _qtyControllers.values) {
      for (final c in m.values) { c.dispose(); }
    }
    for (final m in _rateControllers.values) {
      for (final c in m.values) { c.dispose(); }
    }
    for (final c in _shoeQtyControllers.values) { c.dispose(); }
    for (final c in _shoeRateControllers.values) { c.dispose(); }
    for (final m in _rbQtyControllers.values) {
      for (final c in m.values) { c.dispose(); }
    }
    for (final m in _rbRateControllers.values) {
      for (final c in m.values) { c.dispose(); }
    }
    for (final c in _rbShoeQtyControllers.values) { c.dispose(); }
    for (final c in _rbShoeRateControllers.values) { c.dispose(); }
    for (final c in _cbDaysControllers.values) { c.dispose(); }
    for (final c in _rbDaysControllers.values) { c.dispose(); }
    for (final m in _cbHeightDaysCtrl.values) {
      for (final c in m.values) { c.dispose(); }
    }
    for (final m in _rbHeightDaysCtrl.values) {
      for (final c in m.values) { c.dispose(); }
    }
    for (final id in _ssCardIds) {
      _ssQtyCtrl[id]?.values.forEach((c) => c.dispose());
      _ssRateCtrl[id]?.values.forEach((c) => c.dispose());
      _ssDaysCtrl[id]?.values.forEach((c) => c.dispose());
    }
    super.dispose();
  }

  // ignore: unused_element
  String _dueLabel(int? days) {
    if (days == null || days == 0) return 'Enter days...';
    final d = _baseDate.add(Duration(days: days));
    const mo = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${mo[d.month - 1]} ${d.year}';
  }

  bool get _isDirty =>
      _customerName.isNotEmpty ||
      _siteCtrl.text.isNotEmpty ||
      _mats.isNotEmpty ||
      _columnBoxes.isNotEmpty ||
      _roundBoxes.isNotEmpty ||
      _ssCardIds.isNotEmpty;

  Future<void> _handleBack() async {
    if (!_isDirty) {
      widget.onBack();
      return;
    }
    final leave = await showUnsavedChangesDialog(context);
    if (leave && mounted) widget.onBack();
  }

  Future<void> _save(AppColors colors) async {
    if (_customerName.isEmpty || _siteCtrl.text.isEmpty || _billNumCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Please fill customer, site details, and Bill Number'),
            backgroundColor: const Color(0xFFFF5555),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
      );
      return;
    }
    final sideSheets = _buildSideSheets();
    const sideSheetRate = 0.0;
    if (_mats.isEmpty && _columnBoxes.isEmpty && _roundBoxes.isEmpty && sideSheets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Please add at least one material, column box, or round box'),
            backgroundColor: const Color(0xFFFF5555),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
      );
      return;
    }

    for (var i = 0; i < _mats.length; i++) {
      if (_mats[i].name.trim().isEmpty ||
          _mats[i].days == null ||
          _mats[i].days! <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Please fill all details for Material ${String.fromCharCode(65 + i)}'),
              backgroundColor: const Color(0xFFFF5555),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        );
        return;
      }
    }

    final store = context.read<AppStore>();
    final newBill = Bill(
      id: widget.initialBill?.id ?? _uuid.v4(),
      billNumber: _billNumCtrl.text.trim(),
      type: _type,
      customerName: _customerName,
      customerId: _customerId,
      site: _siteCtrl.text,
      billDate: _baseDate,
      branch: _selectedBranch,
      vehicleChargeUp: double.tryParse(_vehicleUpCtrl.text) ?? 0.0,
      vehicleChargeDown: double.tryParse(_vehicleDownCtrl.text) ?? 0.0,
      labourChargeUp: double.tryParse(_labourUpCtrl.text) ?? 0.0,
      labourChargeDown: double.tryParse(_labourDownCtrl.text) ?? 0.0,
      gstEnabled: _gstEnabled,
      advancePaid: double.tryParse(_advanceCtrl.text) ?? 0.0,
      materials: _mats
          .map((m) => RentalMaterial(
                name: m.name,
                days: m.days!,
                dueDate: _baseDate.add(Duration(days: m.days!)),
                quantity: m.quantity,
                unit: m.unit,
                rate: m.rate,
              ))
          .toList(),
      columnBoxes: _columnBoxes,
      roundBoxes: _roundBoxes,
      isBilled: false,
      parentId: null,
      linkedDcIds: [],
      sideSheets: sideSheets,
      sideSheetRate: sideSheetRate,
    );

    if (widget.initialBill != null) {
      await store.updateBill(newBill);
    } else {
      await store.addBill(newBill);
    }
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      bottom: false,
      child: Column(children: [
        // Header
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
                child: Text(
                    widget.initialBill != null
                        ? '✎   EDIT ENTRY'
                        : '⊕   NEW ENTRY',
                    style: jakarta(context,
                            size: 9,
                            weight: FontWeight.w800,
                            color: colors.textSub)
                        .copyWith(letterSpacing: 2))),
            const SizedBox(height: 12),
            Row(
              children: [
                Text.rich(TextSpan(children: [
                  TextSpan(
                      text: widget.initialBill != null ? 'Edit ' : 'New ',
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: colors.textMain)),
                  TextSpan(
                      text: _type == BillType.bill ? 'Bill ' : 'DC ',
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color:
                              _type == BillType.bill ? colors.teal : colors.brand,
                          fontStyle: FontStyle.italic)),
                ])),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(borderSide: BorderSide(color: colors.border), borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: colors.border), borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (store.customers.isEmpty) ...[
              Text('ℹ️ No customers found. Add one first or enter manually.',
                  style: jakarta(context, size: 10, color: colors.brand)),
            ],
          ]),
        ),
        // Body
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
                left: 20, right: 20, top: 20, bottom: 100 + keyboardHeight),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: _TypeOpt(
                    label: '🧾   Standard',
                    desc: 'Quick Billing',
                    on: _type == BillType.bill,
                    isTeal: true,
                    onTap: () => setState(() {
                      _type = BillType.bill;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TypeOpt(
                    label: '🚛   DC Bill',
                    desc: 'Delivery Challan',
                    on: _type == BillType.dc,
                    isTeal: false,
                    onTap: () => setState(() {
                      _type = BillType.dc;
                    }),
                  ),
                ),
              ]),

              // Customer
              _Label('Customer *'),
              Autocomplete<Customer>(
                initialValue: TextEditingValue(text: _customerName),
                displayStringForOption: (c) => c.name,
                optionsBuilder: (TextEditingValue v) {
                  final input = v.text.trim();
                  final existing = store.customers
                      .where((c) =>
                          c.name.toLowerCase().contains(input.toLowerCase()) ||
                          c.phone.contains(input))
                      .toList();

                  if (input.isNotEmpty) {
                    // Add a special item if not found or always for convenience
                    final exactMatch = existing.any(
                        (c) => c.name.toLowerCase() == input.toLowerCase());
                    if (!exactMatch) {
                      existing.insert(
                          0,
                          Customer(
                            id: 'ADD_NEW',
                            name: 'Add New: "$input"',
                            phone: '',
                            address: '',
                            site: '',
                            gstNumber: '',
                            referBy: '',
                          ));
                    }
                  }
                  return existing;
                },
                onSelected: (c) {
                  if (c.id == 'ADD_NEW') {
                    FocusScope.of(context).unfocus();
                    widget.onAddNewCustomer();
                    return;
                  }
                  setState(() {
                    _customerName = c.name;
                    _customerId = c.id;
                    _siteCtrl.text = c.site;
                    _phoneCtrl.text = c.phone;
                    _gstCtrl.text = c.gstNumber;
                  });
                },
                fieldViewBuilder: (ctx, ctrl, focus, onSubmitted) {
                  ctrl.addListener(() {
                    // Ignore if the text matches the special "Add New" prompt or is just the name
                    if (ctrl.text != _customerName &&
                        !ctrl.text.contains('Add New:')) {
                      _customerName = ctrl.text;
                      _customerId = ''; // Clear ID if typing manually
                    }
                  });
                  return _Field(
                      hint: 'Search by name or phone...',
                      colors: colors,
                      controller: ctrl,
                      focusNode: focus);
                },
                optionsViewBuilder: (ctx, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.hardEdge,
                      child: Container(
                        width: MediaQuery.of(ctx).size.width - 40,
                        color: colors.surface,
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (ctx, i) {
                            final c = options.elementAt(i);
                            return ListTile(
                              leading: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                    color: c.id == 'ADD_NEW'
                                        ? colors.indigoBg
                                        : colors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8)),
                                child: Center(
                                    child: Text(c.id == 'ADD_NEW' ? '➕' : '👤',
                                        style: const TextStyle(fontSize: 16))),
                              ),
                              title: Text(c.name,
                                  style: jakarta(context,
                                      size: 14,
                                      weight: c.id == 'ADD_NEW'
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: c.id == 'ADD_NEW'
                                          ? colors.brand
                                          : colors.textMain)),
                              subtitle: Text('${c.phone} · ${c.site}',
                                  style: jakarta(context,
                                      size: 11, color: colors.textMuted)),
                              onTap: () => onSelected(c),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Site + Date
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _Label('Site / Location'),
                      _Field(
                          hint: 'Nanmangalam...',
                          colors: colors,
                          controller: _siteCtrl),
                    ])),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _Label('Bill Date'),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          border: Border.all(color: colors.border, width: 0.5),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: colors.glow,
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Text(_baseDateFormatted(),
                            style: jakarta(context,
                                size: 13, color: colors.textMain)),
                      ),
                    ])),
              ]),
              if (_customerId.isNotEmpty) ...[
                const SizedBox(height: 16),
                _Label('Customer Details (Auto-filled)'),
                Row(children: [
                  Expanded(
                      child: _InfoTile('📞 Phone', _phoneCtrl.text, colors)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _InfoTile(
                          '🆔 GST',
                          _gstCtrl.text.isEmpty ? 'N/A' : _gstCtrl.text,
                          colors)),
                ]),
              ],

              const SizedBox(height: 24),

              // Material type tab bar
              TabBar(
                controller: _matTabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: jakarta(context, size: 12, weight: FontWeight.w700),
                unselectedLabelStyle: jakarta(context, size: 12, weight: FontWeight.w500),
                labelColor: _type == BillType.bill ? colors.teal : colors.indigo,
                unselectedLabelColor: colors.textMuted,
                indicatorColor: _type == BillType.bill ? colors.teal : colors.indigo,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: colors.border,
                tabs: const [
                  Tab(text: 'Column Box'),
                  Tab(text: 'Round Box'),
                  Tab(text: 'Palagai'),
                  Tab(text: 'Runner'),
                  Tab(text: 'Side Sheet'),
                  Tab(text: 'Others'),
                ],
              ),
              const SizedBox(height: 16),

              // Tab body
              if (_matTabController.index == 0)
                _buildColumnBoxTab(colors)
              else if (_matTabController.index == 1)
                _buildRoundBoxTab(colors)
              else if (_matTabController.index == 4)
                _buildSideSheetTab(colors)
              else if (_matTabController.index == 5)
                _buildOthersTab(colors, isDark)
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Coming soon',
                      style: jakarta(context, size: 14, color: colors.textMuted),
                    ),
                  ),
                ),

              const SizedBox(height: 32),
              SectionHeader('FINANCIAL SUMMARY'),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border, width: 0.5),
                ),
                child: Column(
                  children: [
                    // Total Rent
                    _FinRow(
                      label: 'Total Rent',
                      value: '₹${(_mats.fold(0.0, (s, m) => s + m.amount) + _columnBoxes.fold(0.0, (s, b) => s + b.totalAmount) + _roundBoxes.fold(0.0, (s, b) => s + b.totalAmount) + _ssTotalAmount).toStringAsFixed(0)}',
                      colors: colors,
                      context: context,
                    ),
                    const SizedBox(height: 12),
                    // Transport Up
                    _FinInputRow(label: 'Transport (UP)', ctrl: _vehicleUpCtrl, colors: colors, context: context, onChanged: () => setState(() {})),
                    const SizedBox(height: 10),
                    // Transport Down
                    _FinInputRow(label: 'Transport (DOWN)', ctrl: _vehicleDownCtrl, colors: colors, context: context, onChanged: () => setState(() {})),
                    const SizedBox(height: 10),
                    // Labour Up
                    _FinInputRow(label: 'Labour (UP)', ctrl: _labourUpCtrl, colors: colors, context: context, onChanged: () => setState(() {})),
                    const SizedBox(height: 10),
                    // Labour Down
                    _FinInputRow(label: 'Labour (DOWN)', ctrl: _labourDownCtrl, colors: colors, context: context, onChanged: () => setState(() {})),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1, thickness: 0.5, color: colors.border),
                    ),
                    // Total Amount + GST + Balance
                    Builder(builder: (_) {
                      final rentTotal = _mats.fold(0.0, (s, m) => s + m.amount)
                          + _columnBoxes.fold(0.0, (s, b) => s + b.totalAmount)
                          + _roundBoxes.fold(0.0, (s, b) => s + b.totalAmount)
                          + _ssTotalAmount;
                      final transport = (double.tryParse(_vehicleUpCtrl.text) ?? 0.0) + (double.tryParse(_vehicleDownCtrl.text) ?? 0.0);
                      final labour = (double.tryParse(_labourUpCtrl.text) ?? 0.0) + (double.tryParse(_labourDownCtrl.text) ?? 0.0);
                      final total = rentTotal + transport + labour;
                      final sgst = _gstEnabled ? total * 0.09 : 0.0;
                      final cgst = _gstEnabled ? total * 0.09 : 0.0;
                      final totalWithGst = total + sgst + cgst;
                      final received = double.tryParse(_advanceCtrl.text) ?? 0.0;
                      final balance = totalWithGst - received;
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Amount',
                                  style: jakarta(context, size: 14, weight: FontWeight.w800, color: colors.textMain)),
                              Text('₹${total.toStringAsFixed(0)}',
                                  style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w900,
                                      color: _type == BillType.bill ? colors.teal : colors.brand)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // GST Toggle
                          Row(
                            children: [
                              Expanded(child: Text('GST Billing (18%)',
                                  style: jakarta(context, size: 13, weight: FontWeight.w600, color: colors.textSub))),
                              Switch(
                                value: _gstEnabled,
                                onChanged: (v) => setState(() => _gstEnabled = v),
                                activeColor: colors.indigo,
                              ),
                            ],
                          ),
                          if (_gstEnabled) ...[
                            const SizedBox(height: 6),
                            _FinRow(label: 'SGST (9%)', value: '₹${sgst.toStringAsFixed(0)}', colors: colors, context: context, isMuted: true),
                            const SizedBox(height: 4),
                            _FinRow(label: 'CGST (9%)', value: '₹${cgst.toStringAsFixed(0)}', colors: colors, context: context, isMuted: true),
                            const SizedBox(height: 8),
                            _FinRow(label: 'Total incl. GST', value: '₹${totalWithGst.toStringAsFixed(0)}', colors: colors, context: context),
                          ],
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Divider(height: 1, thickness: 0.5, color: colors.border),
                          ),
                          _FinInputRow(label: 'Received Amount', ctrl: _advanceCtrl, colors: colors, context: context, onChanged: () => setState(() {})),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Divider(height: 1, thickness: 0.5, color: colors.border),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _type == BillType.bill ? colors.tealBg : colors.indigoBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('BALANCE AMOUNT',
                                    style: jakarta(context, size: 12, weight: FontWeight.w800,
                                        color: _type == BillType.bill ? colors.teal : colors.indigo)),
                                Text('₹${balance.toStringAsFixed(0)}',
                                    style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w900,
                                        color: _type == BillType.bill ? colors.teal : colors.indigo)),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => _showPreview(colors),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _type == BillType.bill
                          ? (isDark
                              ? [
                                  const Color(0xFF097A6B),
                                  const Color(0xFF075A4E)
                                ]
                              : [
                                  const Color(0xFF0CAF98),
                                  const Color(0xFF097A6B)
                                ])
                          : (isDark
                              ? [
                                  const Color(0xFF1E3A8A),
                                  const Color(0xFF162B66)
                                ]
                              : [
                                  const Color(0xFF2563EB),
                                  const Color(0xFF1D4ED8)
                                ]),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: (_type == BillType.bill
                                  ? const Color(0xFF097A6B)
                                  : const Color(0xFF2563EB))
                              .withOpacity(.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  child: Center(
                      child: Text(
                          'PREVIEW & SAVE  →',
                          style: jakarta(context,
                                  size: 14,
                                  weight: FontWeight.w800,
                                  color: Colors.white)
                              .copyWith(letterSpacing: .5))),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Side Sheet helpers ────────────────────────────────────────────────────

  List<SideSheetEntry> _buildSideSheets() {
    final entries = <SideSheetEntry>[];
    for (final id in _ssCardIds) {
      final type = _ssCardTypes[id]!;
      for (final size in _addedSsSizes[id] ?? <int>{}) {
        final qty = int.tryParse(_ssQtyCtrl[id]?[size]?.text ?? '') ?? 0;
        final rate = double.tryParse(_ssRateCtrl[id]?[size]?.text ?? '') ?? 0.0;
        final days = int.tryParse(_ssDaysCtrl[id]?[size]?.text ?? '') ?? 0;
        if (qty > 0) {
          entries.add(SideSheetEntry(sheetType: type, size: size, qty: qty, rate: rate, days: days));
        }
      }
    }
    return entries;
  }

  double get _ssTotalAmount {
    double total = 0;
    for (final id in _ssCardIds) {
      final type = _ssCardTypes[id]!;
      for (final size in _addedSsSizes[id] ?? <int>{}) {
        final qty = int.tryParse(_ssQtyCtrl[id]?[size]?.text ?? '') ?? 0;
        final rate = double.tryParse(_ssRateCtrl[id]?[size]?.text ?? '') ?? 0.0;
        final cf = SideSheetEntry.conversionFactors[type] ?? 1.0;
        total += size * qty * cf * rate;
      }
    }
    return total;
  }

  void _ssAddType(String type) {
    final id = _uuid.v4();
    setState(() {
      _ssCardIds.add(id);
      _ssCardTypes[id] = type;
      _addedSsSizes[id] = {};
      _ssQtyCtrl[id] = {};
      _ssRateCtrl[id] = {};
      _ssDaysCtrl[id] = {};
      _selectedSsType = null;
    });
  }

  void _ssRemoveType(String cardId) {
    _ssQtyCtrl[cardId]?.values.forEach((c) => c.dispose());
    _ssRateCtrl[cardId]?.values.forEach((c) => c.dispose());
    _ssDaysCtrl[cardId]?.values.forEach((c) => c.dispose());
    setState(() {
      _ssCardIds.remove(cardId);
      _ssCardTypes.remove(cardId);
      _addedSsSizes.remove(cardId);
      _ssQtyCtrl.remove(cardId);
      _ssRateCtrl.remove(cardId);
      _ssDaysCtrl.remove(cardId);
    });
  }

  void _ssAddSize(String cardId, int size) {
    if (_addedSsSizes[cardId]?.contains(size) ?? false) return;
    setState(() {
      _addedSsSizes[cardId]!.add(size);
      _ssQtyCtrl[cardId]![size] = TextEditingController()..addListener(() => setState(() {}));
      _ssRateCtrl[cardId]![size] = TextEditingController()..addListener(() => setState(() {}));
      _ssDaysCtrl[cardId]![size] = TextEditingController();
    });
  }

  void _ssRemoveSize(String cardId, int size) {
    _ssQtyCtrl[cardId]?[size]?.dispose();
    _ssRateCtrl[cardId]?[size]?.dispose();
    _ssDaysCtrl[cardId]?[size]?.dispose();
    setState(() {
      _addedSsSizes[cardId]?.remove(size);
      _ssQtyCtrl[cardId]?.remove(size);
      _ssRateCtrl[cardId]?.remove(size);
      _ssDaysCtrl[cardId]?.remove(size);
    });
  }

  void _showPreview(AppColors colors) {
    final sideSheets = _buildSideSheets();
    const sideSheetRate = 0.0;

    if (_customerName.isEmpty || _siteCtrl.text.isEmpty || _billNumCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Please fill customer, site, and bill number'),
          backgroundColor: const Color(0xFFFF5555),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      return;
    }
    if (_mats.isEmpty && _columnBoxes.isEmpty && _roundBoxes.isEmpty && sideSheets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Please add at least one material'),
          backgroundColor: const Color(0xFFFF5555),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      return;
    }

    // Build a preview bill (without saving)
    final previewBill = Bill(
      id: widget.initialBill?.id ?? 'preview',
      billNumber: _billNumCtrl.text.trim(),
      type: _type,
      customerName: _customerName,
      customerId: _customerId,
      site: _siteCtrl.text,
      billDate: _baseDate,
      branch: _selectedBranch,
      vehicleChargeUp: double.tryParse(_vehicleUpCtrl.text) ?? 0.0,
      vehicleChargeDown: double.tryParse(_vehicleDownCtrl.text) ?? 0.0,
      labourChargeUp: double.tryParse(_labourUpCtrl.text) ?? 0.0,
      labourChargeDown: double.tryParse(_labourDownCtrl.text) ?? 0.0,
      gstEnabled: _gstEnabled,
      advancePaid: double.tryParse(_advanceCtrl.text) ?? 0.0,
      materials: _mats.map((m) => RentalMaterial(
            name: m.name,
            days: m.days ?? 1,
            dueDate: _baseDate.add(Duration(days: m.days ?? 1)),
            quantity: m.quantity,
            unit: m.unit,
            rate: m.rate,
          )).toList(),
      columnBoxes: _columnBoxes,
      roundBoxes: _roundBoxes,
      sideSheets: sideSheets,
      sideSheetRate: sideSheetRate,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InvoicePreviewSheet(
        bill: previewBill,
        onConfirm: () {
          Navigator.of(context).pop();
          _save(colors);
        },
      ),
    );
  }

  // ── Column Box helpers ────────────────────────────────────────────────────

  void _syncColumnBoxes() {
    _columnBoxes = _addedSizes.map((sizeKey) {
      final sortedH = (_addedHeights[sizeKey] ?? <int>{}).toList()
        ..sort((a, b) => b.compareTo(a));
      final heightRows = sortedH.map((h) {
        final qty = int.tryParse(_qtyControllers[sizeKey]?[h]?.text ?? '') ?? 0;
        final rate = double.tryParse(_rateControllers[sizeKey]?[h]?.text ?? '') ?? 0.0;
        final days = int.tryParse(_cbHeightDaysCtrl[sizeKey]?[h]?.text ?? '') ?? 0;
        return ColumnHeightRow(heightFt: h, qty: qty, rate: rate, days: days);
      }).toList();
      ColumnShoeRow? shoe;
      if (_shoeAdded[sizeKey] == true) {
        final qty = int.tryParse(_shoeQtyControllers[sizeKey]?.text ?? '') ?? 0;
        final rate = double.tryParse(_shoeRateControllers[sizeKey]?.text ?? '') ?? 0.0;
        final shoeDays = int.tryParse(_cbDaysControllers[sizeKey]?.text ?? '') ?? 0;
        shoe = ColumnShoeRow(qty: qty, rate: rate, days: shoeDays);
      }
      return ColumnSizeBlock(sizeKey: sizeKey, heightRows: heightRows, shoe: shoe, days: 0);
    }).toList();
  }

  void _cbAddSize() {
    final size = _selectedColumnBoxSize;
    if (size == null) return;
    if (_addedSizes.contains(size)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${RateCard.label(size)} is already added'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    setState(() {
      _selectedColumnBoxSize = null;
      _addedSizes.add(size);
      _addedHeights[size] = {};
      _shoeAdded[size] = false;
      _qtyControllers[size] = {};
      _rateControllers[size] = {};
      _cbDaysControllers[size] = TextEditingController();
      _cbHeightDaysCtrl[size] = {};
      _syncColumnBoxes();
    });
  }

  void _cbAddHeight(String sizeKey, int h) {
    setState(() {
      _addedHeights[sizeKey]!.add(h);
      _qtyControllers[sizeKey]![h] = TextEditingController();
      _rateControllers[sizeKey]![h] = TextEditingController();
      _cbHeightDaysCtrl[sizeKey] ??= {};
      _cbHeightDaysCtrl[sizeKey]![h] = TextEditingController();
      _syncColumnBoxes();
    });
  }

  void _cbRemoveHeight(String sizeKey, int h) {
    _qtyControllers[sizeKey]?[h]?.dispose();
    _qtyControllers[sizeKey]?.remove(h);
    _rateControllers[sizeKey]?[h]?.dispose();
    _rateControllers[sizeKey]?.remove(h);
    _cbHeightDaysCtrl[sizeKey]?[h]?.dispose();
    _cbHeightDaysCtrl[sizeKey]?.remove(h);
    setState(() {
      _addedHeights[sizeKey]?.remove(h);
      _syncColumnBoxes();
    });
  }

  void _cbAddShoe(String sizeKey) {
    setState(() {
      _shoeAdded[sizeKey] = true;
      _shoeQtyControllers[sizeKey] = TextEditingController();
      _shoeRateControllers[sizeKey] = TextEditingController();
      _syncColumnBoxes();
    });
  }

  void _cbRemoveShoe(String sizeKey) {
    _shoeQtyControllers[sizeKey]?.dispose();
    _shoeQtyControllers.remove(sizeKey);
    _shoeRateControllers[sizeKey]?.dispose();
    _shoeRateControllers.remove(sizeKey);
    setState(() {
      _shoeAdded[sizeKey] = false;
      _syncColumnBoxes();
    });
  }

  void _cbRemoveSize(String sizeKey) {
    for (final h in (_addedHeights[sizeKey] ?? <int>{})) {
      _qtyControllers[sizeKey]?[h]?.dispose();
      _rateControllers[sizeKey]?[h]?.dispose();
      _cbHeightDaysCtrl[sizeKey]?[h]?.dispose();
    }
    _qtyControllers.remove(sizeKey);
    _rateControllers.remove(sizeKey);
    _cbHeightDaysCtrl.remove(sizeKey);
    _shoeQtyControllers[sizeKey]?.dispose();
    _shoeQtyControllers.remove(sizeKey);
    _shoeRateControllers[sizeKey]?.dispose();
    _shoeRateControllers.remove(sizeKey);
    _cbDaysControllers[sizeKey]?.dispose();
    _cbDaysControllers.remove(sizeKey);
    setState(() {
      _addedSizes.remove(sizeKey);
      _addedHeights.remove(sizeKey);
      _shoeAdded.remove(sizeKey);
      _syncColumnBoxes();
    });
  }

  // ── Column Box tab UI ─────────────────────────────────────────────────────

  // ── Side Sheet tab UI ─────────────────────────────────────────────────────

  Widget _buildSideSheetTab(AppColors colors) {
    final totalAmount = _ssTotalAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (totalAmount > 0) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: colors.amberBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.amberBd, width: 0.5),
              ),
              child: Text('Total ₹${totalAmount.toStringAsFixed(0)}',
                  style: jakarta(context,
                      size: 14,
                      weight: FontWeight.w800,
                      color: colors.amber)),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Sheet type picker
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedSsType,
              isExpanded: true,
              hint: Text('Select sheet type…',
                  style:
                      jakarta(context, size: 13, color: colors.textMuted)),
              items: _ssTypes
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                            '$t Sheet',
                            style: jakarta(context,
                                size: 13, color: colors.textMain)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedSsType = v),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: colors.border, width: 0.5)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: colors.border, width: 0.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: colors.amber, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _selectedSsType != null
                ? () => _ssAddType(_selectedSsType!)
                : null,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: _selectedSsType != null
                    ? colors.amber
                    : colors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('+ Add',
                  style: jakarta(context,
                      size: 13,
                      weight: FontWeight.w700,
                      color: _selectedSsType != null
                          ? Colors.white
                          : colors.textMuted)),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // One card per added sheet entry (allows same type multiple times)
        ..._ssCardIds.map((id) => _buildSsBlock(id, colors)),
      ],
    );
  }

  Widget _buildSsBlock(String cardId, AppColors colors) {
    final type = _ssCardTypes[cardId] ?? '';
    final activeSizes = _addedSsSizes[cardId] ?? <int>{};
    final cf = SideSheetEntry.conversionFactors[type] ?? 1.0;
    final sortedSizes = activeSizes.toList()..sort((a, b) => b.compareTo(a));

    double typeSqft = 0;
    double typeAmount = 0;
    for (final size in activeSizes) {
      final qty = int.tryParse(_ssQtyCtrl[cardId]?[size]?.text ?? '') ?? 0;
      final rate = double.tryParse(_ssRateCtrl[cardId]?[size]?.text ?? '') ?? 0.0;
      final sqft = size * qty * cf;
      typeSqft += sqft;
      typeAmount += sqft * rate;
    }

    // TextField decoration helper
    InputDecoration _ssFieldDec(String hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border, width: 0.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border, width: 0.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.amber, width: 1.5)),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
            child: Row(children: [
              Text('$type Sheet',
                  style: jakarta(context,
                      size: 14,
                      weight: FontWeight.w800,
                      color: colors.textMain)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.amberBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.amberBd, width: 0.5),
                ),
                child: Text('×${cf.toStringAsFixed(2)}',
                    style: jakarta(context,
                        size: 11,
                        weight: FontWeight.w700,
                        color: colors.amber)),
              ),
              const Spacer(),
              if (typeSqft > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${typeSqft.toStringAsFixed(1)} sqft',
                          style: jakarta(context, size: 11, weight: FontWeight.w700, color: colors.amber)),
                      if (typeAmount > 0)
                        Text('₹${typeAmount.toStringAsFixed(0)}',
                            style: jakarta(context, size: 10, color: colors.textMuted)),
                    ],
                  ),
                ),
              TextButton(
                onPressed: () => _ssRemoveType(cardId),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Remove',
                    style: jakarta(context, size: 12, weight: FontWeight.w600, color: Colors.redAccent)),
              ),
            ]),
          ),

          // Size chips
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _ssSizes.map((s) {
                final isOn = activeSizes.contains(s);
                return GestureDetector(
                  onTap: isOn ? null : () => _ssAddSize(cardId, s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isOn ? colors.amber : colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isOn ? colors.amber : colors.border,
                        width: 0.5,
                      ),
                    ),
                    child: Text('$s',
                        style: jakarta(context,
                            size: 11,
                            weight: FontWeight.w700,
                            color: isOn ? Colors.white : colors.textSub)),
                  ),
                );
              }).toList(),
            ),
          ),

          // Active size rows
          if (sortedSizes.isNotEmpty) ...[
            // Column headers
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 36, 4),
              child: Row(children: [
                SizedBox(width: 30, child: Text('Size', style: jakarta(context, size: 10, weight: FontWeight.w700, color: colors.textMuted))),
                const SizedBox(width: 4),
                SizedBox(width: 52, child: Text('Qty', style: jakarta(context, size: 10, weight: FontWeight.w700, color: colors.textMuted))),
                const SizedBox(width: 4),
                SizedBox(width: 38, child: Text('×cf', style: jakarta(context, size: 10, weight: FontWeight.w700, color: colors.textMuted))),
                const SizedBox(width: 4),
                SizedBox(width: 44, child: Text('Sqft', style: jakarta(context, size: 10, weight: FontWeight.w700, color: colors.textMuted))),
                const SizedBox(width: 4),
                SizedBox(width: 56, child: Text('Rate', style: jakarta(context, size: 10, weight: FontWeight.w700, color: colors.textMuted))),
                const SizedBox(width: 4),
                SizedBox(width: 48, child: Text('Days', style: jakarta(context, size: 10, weight: FontWeight.w700, color: colors.textMuted))),
                const SizedBox(width: 4),
                Expanded(child: Text('Amt', style: jakarta(context, size: 10, weight: FontWeight.w700, color: colors.textMuted))),
              ]),
            ),
            ...sortedSizes.map((size) {
              final qtyCtrl = _ssQtyCtrl[cardId]![size]!;
              final rateCtrl = _ssRateCtrl[cardId]![size]!;
              final daysCtrl = _ssDaysCtrl[cardId]![size]!;
              final qty = int.tryParse(qtyCtrl.text) ?? 0;
              final rate = double.tryParse(rateCtrl.text) ?? 0.0;
              final sqft = size * qty * cf;
              final amount = sqft * rate;
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
                child: Row(children: [
                  // Size
                  SizedBox(
                    width: 30,
                    child: Text('$size',
                        style: jakarta(context, size: 14, weight: FontWeight.w800, color: colors.textMain)),
                  ),
                  const SizedBox(width: 4),
                  // Qty
                  SizedBox(
                    width: 52,
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: jakarta(context, size: 13, weight: FontWeight.w700, color: colors.textMain),
                      decoration: _ssFieldDec('0'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // ×cf (auto-populated read-only display)
                  SizedBox(
                    width: 38,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                      decoration: BoxDecoration(
                        color: colors.amberBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.amberBd, width: 0.5),
                      ),
                      child: Text('×${cf % 1 == 0 ? cf.toStringAsFixed(0) : cf.toStringAsFixed(2)}',
                          style: jakarta(context, size: 11, weight: FontWeight.w700, color: colors.amber),
                          textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Sqft (auto-computed)
                  SizedBox(
                    width: 44,
                    child: Text(
                      sqft > 0 ? sqft.toStringAsFixed(1) : '—',
                      style: jakarta(context, size: 12, weight: FontWeight.w700,
                          color: sqft > 0 ? colors.amber : colors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Rate
                  SizedBox(
                    width: 56,
                    child: TextField(
                      controller: rateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      style: jakarta(context, size: 13, weight: FontWeight.w700, color: colors.textMain),
                      decoration: _ssFieldDec('₹'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Days
                  SizedBox(
                    width: 48,
                    child: TextField(
                      controller: daysCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: jakarta(context, size: 13, color: colors.textMain),
                      decoration: _ssFieldDec('Days'),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Amount
                  Expanded(
                    child: amount > 0
                        ? Text('₹${amount.toStringAsFixed(0)}',
                            style: jakarta(context, size: 12, weight: FontWeight.w700, color: colors.textSub),
                            textAlign: TextAlign.right)
                        : Text('—',
                            style: jakarta(context, size: 12, color: colors.textMuted),
                            textAlign: TextAlign.right),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _ssRemoveSize(cardId, size),
                    child: Icon(Icons.close_rounded, size: 18, color: colors.textMuted),
                  ),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ── Column Box tab UI ─────────────────────────────────────────────────────

  Widget _buildColumnBoxTab(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedColumnBoxSize,
                isExpanded: true,
                hint: Text('Select size…',
                    style: jakarta(context, size: 13, color: colors.textMuted)),
                items: RateCard.columnBoxSizes
                    .map((k) => DropdownMenuItem(
                          value: k,
                          child: Text(RateCard.label(k),
                              style: jakarta(context,
                                  size: 13, color: colors.textMain)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedColumnBoxSize = v),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border, width: 0.5)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border, width: 0.5)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.indigo, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _selectedColumnBoxSize != null ? _cbAddSize : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: _selectedColumnBoxSize != null
                      ? colors.indigo
                      : colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('+ Add',
                    style: jakarta(context,
                        size: 13,
                        weight: FontWeight.w700,
                        color: _selectedColumnBoxSize != null
                            ? Colors.white
                            : colors.textMuted)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._addedSizes.map((s) => _buildCbBlock(s, colors)),
      ],
    );
  }

  Widget _buildCbBlock(String sizeKey, AppColors colors) {
    final heights = _addedHeights[sizeKey] ?? <int>{};
    final shoeOn = _shoeAdded[sizeKey] ?? false;
    final hasRows = heights.isNotEmpty || shoeOn;
    final sortedH = heights.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: label + days + remove
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(RateCard.label(sizeKey),
                      style: jakarta(context,
                          size: 14,
                          weight: FontWeight.w800,
                          color: colors.textMain)),
                ),
                TextButton(
                  onPressed: () => _cbRemoveSize(sizeKey),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Remove',
                      style: jakarta(context,
                          size: 12,
                          weight: FontWeight.w600,
                          color: Colors.redAccent)),
                ),
              ],
            ),
          ),
          // Height chips + vertical divider + Shoe chip
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: RateCard.heights.map((h) {
                      final isOn = heights.contains(h);
                      return GestureDetector(
                        onTap: isOn ? null : () => _cbAddHeight(sizeKey, h),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isOn ? colors.indigo : colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isOn ? colors.indigo : colors.border,
                              width: 0.5,
                            ),
                          ),
                          child: Text('${h}ft',
                              style: jakarta(context,
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color:
                                      isOn ? Colors.white : colors.textSub)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: colors.border,
                ),
                GestureDetector(
                  onTap: shoeOn ? null : () => _cbAddShoe(sizeKey),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: shoeOn ? colors.teal : colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: shoeOn ? colors.teal : colors.border,
                        width: 0.5,
                      ),
                    ),
                    child: Text('Shoe',
                        style: jakarta(context,
                            size: 11,
                            weight: FontWeight.w700,
                            color: shoeOn ? Colors.white : colors.textSub)),
                  ),
                ),
              ],
            ),
          ),
          // Column headers — only when ≥1 row
          if (hasRows) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text('Height',
                        style: jakarta(context,
                                size: 9,
                                weight: FontWeight.w800,
                                color: colors.textMuted)
                            .copyWith(letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Qty',
                        style: jakarta(context,
                                size: 9,
                                weight: FontWeight.w800,
                                color: colors.textMuted)
                            .copyWith(letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Rate (₹)',
                        style: jakarta(context,
                                size: 9,
                                weight: FontWeight.w800,
                                color: colors.textMuted)
                            .copyWith(letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    child: Text('Days *',
                        style: jakarta(context,
                                size: 9,
                                weight: FontWeight.w800,
                                color: colors.indigo)
                            .copyWith(letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: Text('Amount (₹)',
                        style: jakarta(context,
                                size: 9,
                                weight: FontWeight.w800,
                                color: colors.textMuted)
                            .copyWith(letterSpacing: 0.5),
                        textAlign: TextAlign.right),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: colors.border),
          ],
          // Height rows (descending)
          ...sortedH.map((h) => _buildCbHeightRow(sizeKey, h, colors)),
          // Shoe row
          if (shoeOn) _buildCbShoeRow(sizeKey, colors),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildCbHeightRow(String sizeKey, int h, AppColors colors) {
    final qtyCtr = _qtyControllers[sizeKey]![h]!;
    final rateCtr = _rateControllers[sizeKey]![h]!;
    final daysCtr = _cbHeightDaysCtrl[sizeKey]?[h];
    final qty = int.tryParse(qtyCtr.text) ?? 0;
    final rate = double.tryParse(rateCtr.text) ?? 0.0;
    final days = int.tryParse(daysCtr?.text ?? '') ?? 0;
    final amount = (qty > 0 && rate > 0) ? qty * rate : null;
    final daysEmpty = days == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 2),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text('${h}ft',
                style: jakarta(context,
                    size: 13,
                    weight: FontWeight.w700,
                    color: colors.textMain)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: qtyCtr,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: jakarta(context, size: 13, color: colors.textMain),
              decoration: _cbFieldDeco(colors),
              onChanged: (_) => setState(() => _syncColumnBoxes()),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: rateCtr,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
              ],
              style: jakarta(context, size: 13, color: colors.textMain),
              decoration: _cbFieldDeco(colors),
              onChanged: (_) => setState(() => _syncColumnBoxes()),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: TextField(
              controller: daysCtr,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: jakarta(context, size: 13, color: colors.textMain),
              decoration: _cbFieldDeco(colors).copyWith(
                hintText: '0',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: daysEmpty ? colors.indigo.withOpacity(0.5) : colors.border,
                    width: daysEmpty ? 1.5 : 0.5,
                  ),
                ),
              ),
              onChanged: (_) => setState(() => _syncColumnBoxes()),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              amount != null ? '₹${amount.toStringAsFixed(0)}' : '—',
              style: jakarta(context,
                  size: 13,
                  weight: FontWeight.w700,
                  color: amount != null ? colors.teal : colors.textMuted),
              textAlign: TextAlign.right,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 16, color: colors.textMuted),
            onPressed: () => _cbRemoveHeight(sizeKey, h),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildCbShoeRow(String sizeKey, AppColors colors) {
    final qtyCtr  = _shoeQtyControllers[sizeKey]!;
    final rateCtr = _shoeRateControllers[sizeKey]!;
    final daysCtr = _cbDaysControllers[sizeKey];
    final qty  = int.tryParse(qtyCtr.text) ?? 0;
    final rate = double.tryParse(rateCtr.text) ?? 0.0;
    final days = int.tryParse(daysCtr?.text ?? '') ?? 0;
    final amount = (qty > 0 && rate > 0) ? qty * rate : null;
    final daysEmpty = days == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 2),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text('Shoe',
                style: jakarta(context,
                    size: 13,
                    weight: FontWeight.w700,
                    color: colors.teal)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: qtyCtr,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: jakarta(context, size: 13, color: colors.textMain),
              decoration: _cbFieldDeco(colors),
              onChanged: (_) => setState(() => _syncColumnBoxes()),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: rateCtr,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
              ],
              style: jakarta(context, size: 13, color: colors.textMain),
              decoration: _cbFieldDeco(colors),
              onChanged: (_) => setState(() => _syncColumnBoxes()),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: TextField(
              controller: daysCtr,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: jakarta(context, size: 13, color: colors.textMain),
              decoration: _cbFieldDeco(colors).copyWith(
                hintText: '0',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: daysEmpty
                        ? colors.indigo.withOpacity(0.5)
                        : colors.border,
                    width: daysEmpty ? 1.5 : 0.5,
                  ),
                ),
              ),
              onChanged: (_) => setState(() => _syncColumnBoxes()),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              amount != null ? '₹${amount.toStringAsFixed(0)}' : '—',
              style: jakarta(context,
                  size: 13,
                  weight: FontWeight.w700,
                  color: amount != null ? colors.teal : colors.textMuted),
              textAlign: TextAlign.right,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 16, color: colors.textMuted),
            onPressed: () => _cbRemoveShoe(sizeKey),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  InputDecoration _cbFieldDeco(AppColors colors) => InputDecoration(
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
            borderSide: BorderSide(color: colors.indigo, width: 1.5)),
      );

  // ── Round Box helpers ──────────────────────────────────────────────────────

  void _syncRoundBoxes() {
    _roundBoxes = _addedRbSizes.map((sizeKey) {
      final sortedH = (_addedRbHeights[sizeKey] ?? <int>{}).toList()
        ..sort((a, b) => b.compareTo(a));
      final heightRows = sortedH.map((h) {
        final qty = int.tryParse(_rbQtyControllers[sizeKey]?[h]?.text ?? '') ?? 0;
        final rate = double.tryParse(_rbRateControllers[sizeKey]?[h]?.text ?? '') ?? 0.0;
        final days = int.tryParse(_rbHeightDaysCtrl[sizeKey]?[h]?.text ?? '') ?? 0;
        return ColumnHeightRow(heightFt: h, qty: qty, rate: rate, days: days);
      }).toList();
      ColumnShoeRow? shoe;
      if (_rbShoeAdded[sizeKey] == true) {
        final qty = int.tryParse(_rbShoeQtyControllers[sizeKey]?.text ?? '') ?? 0;
        final rate = double.tryParse(_rbShoeRateControllers[sizeKey]?.text ?? '') ?? 0.0;
        final shoeDays = int.tryParse(_rbDaysControllers[sizeKey]?.text ?? '') ?? 0;
        shoe = ColumnShoeRow(qty: qty, rate: rate, days: shoeDays);
      }
      return ColumnSizeBlock(sizeKey: sizeKey, heightRows: heightRows, shoe: shoe, days: 0);
    }).toList();
  }

  void _rbAddSize() {
    final size = _selectedRoundBoxSize;
    if (size == null) return;
    if (_addedRbSizes.contains(size)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$size is already added'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    setState(() {
      _selectedRoundBoxSize = null;
      _addedRbSizes.add(size);
      _addedRbHeights[size] = {};
      _rbShoeAdded[size] = false;
      _rbQtyControllers[size] = {};
      _rbRateControllers[size] = {};
      _rbDaysControllers[size] = TextEditingController();
      _rbHeightDaysCtrl[size] = {};
      _syncRoundBoxes();
    });
  }

  void _rbAddHeight(String sizeKey, int h) {
    setState(() {
      _addedRbHeights[sizeKey]!.add(h);
      _rbQtyControllers[sizeKey]![h] = TextEditingController();
      _rbRateControllers[sizeKey]![h] = TextEditingController();
      _rbHeightDaysCtrl[sizeKey] ??= {};
      _rbHeightDaysCtrl[sizeKey]![h] = TextEditingController();
      _syncRoundBoxes();
    });
  }

  void _rbRemoveHeight(String sizeKey, int h) {
    _rbQtyControllers[sizeKey]?[h]?.dispose();
    _rbQtyControllers[sizeKey]?.remove(h);
    _rbRateControllers[sizeKey]?[h]?.dispose();
    _rbRateControllers[sizeKey]?.remove(h);
    _rbHeightDaysCtrl[sizeKey]?[h]?.dispose();
    _rbHeightDaysCtrl[sizeKey]?.remove(h);
    setState(() {
      _addedRbHeights[sizeKey]?.remove(h);
      _syncRoundBoxes();
    });
  }

  void _rbAddShoe(String sizeKey) {
    setState(() {
      _rbShoeAdded[sizeKey] = true;
      _rbShoeQtyControllers[sizeKey] = TextEditingController();
      _rbShoeRateControllers[sizeKey] = TextEditingController();
      _syncRoundBoxes();
    });
  }

  void _rbRemoveShoe(String sizeKey) {
    _rbShoeQtyControllers[sizeKey]?.dispose();
    _rbShoeQtyControllers.remove(sizeKey);
    _rbShoeRateControllers[sizeKey]?.dispose();
    _rbShoeRateControllers.remove(sizeKey);
    setState(() {
      _rbShoeAdded[sizeKey] = false;
      _syncRoundBoxes();
    });
  }

  void _rbRemoveSize(String sizeKey) {
    for (final h in (_addedRbHeights[sizeKey] ?? <int>{})) {
      _rbQtyControllers[sizeKey]?[h]?.dispose();
      _rbRateControllers[sizeKey]?[h]?.dispose();
      _rbHeightDaysCtrl[sizeKey]?[h]?.dispose();
    }
    _rbQtyControllers.remove(sizeKey);
    _rbRateControllers.remove(sizeKey);
    _rbHeightDaysCtrl.remove(sizeKey);
    _rbShoeQtyControllers[sizeKey]?.dispose();
    _rbShoeQtyControllers.remove(sizeKey);
    _rbShoeRateControllers[sizeKey]?.dispose();
    _rbShoeRateControllers.remove(sizeKey);
    _rbDaysControllers[sizeKey]?.dispose();
    _rbDaysControllers.remove(sizeKey);
    setState(() {
      _addedRbSizes.remove(sizeKey);
      _addedRbHeights.remove(sizeKey);
      _rbShoeAdded.remove(sizeKey);
      _syncRoundBoxes();
    });
  }

  // ── Round Box tab UI ───────────────────────────────────────────────────────

  Widget _buildRoundBoxTab(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedRoundBoxSize,
                isExpanded: true,
                hint: Text('Select size…',
                    style: jakarta(context, size: 13, color: colors.textMuted)),
                items: RateCard.roundBoxSizes
                    .map((k) => DropdownMenuItem(
                          value: k,
                          child: Text(k,
                              style: jakarta(context,
                                  size: 13, color: colors.textMain)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRoundBoxSize = v),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border, width: 0.5)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.border, width: 0.5)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.indigo, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _selectedRoundBoxSize != null ? _rbAddSize : null,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: _selectedRoundBoxSize != null
                      ? colors.indigo
                      : colors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('+ Add',
                    style: jakarta(context,
                        size: 13,
                        weight: FontWeight.w700,
                        color: _selectedRoundBoxSize != null
                            ? Colors.white
                            : colors.textMuted)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._addedRbSizes.map((s) => _buildRbBlock(s, colors)),
      ],
    );
  }

  Widget _buildRbBlock(String sizeKey, AppColors colors) {
    final heights = _addedRbHeights[sizeKey] ?? <int>{};
    final shoeOn = _rbShoeAdded[sizeKey] ?? false;
    final hasRows = heights.isNotEmpty || shoeOn;
    final sortedH = heights.toList()..sort((a, b) => b.compareTo(a));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: label + days + remove
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(sizeKey,
                      style: jakarta(context,
                          size: 14,
                          weight: FontWeight.w800,
                          color: colors.textMain)),
                ),
                TextButton(
                  onPressed: () => _rbRemoveSize(sizeKey),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Remove',
                      style: jakarta(context,
                          size: 12,
                          weight: FontWeight.w600,
                          color: Colors.redAccent)),
                ),
              ],
            ),
          ),
          // Height chips + vertical divider + Shoe chip
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: RateCard.heights.map((h) {
                      final isOn = heights.contains(h);
                      return GestureDetector(
                        onTap: isOn ? null : () => _rbAddHeight(sizeKey, h),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isOn ? colors.indigo : colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isOn ? colors.indigo : colors.border,
                              width: 0.5,
                            ),
                          ),
                          child: Text('${h}ft',
                              style: jakarta(context,
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color:
                                      isOn ? Colors.white : colors.textSub)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: colors.border,
                ),
                GestureDetector(
                  onTap: shoeOn ? null : () => _rbAddShoe(sizeKey),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: shoeOn ? colors.teal : colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: shoeOn ? colors.teal : colors.border,
                        width: 0.5,
                      ),
                    ),
                    child: Text('Shoe',
                        style: jakarta(context,
                            size: 11,
                            weight: FontWeight.w700,
                            color: shoeOn ? Colors.white : colors.textSub)),
                  ),
                ),
              ],
            ),
          ),
          // Column headers — only when ≥1 row
          if (hasRows) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text('Height',
                        style: jakarta(context,
                                size: 9,
                                weight: FontWeight.w800,
                                color: colors.textMuted)
                            .copyWith(letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Qty',
                        style: jakarta(context,
                                size: 9,
                                weight: FontWeight.w800,
                                color: colors.textMuted)
                            .copyWith(letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Rate (₹)',
                        style: jakarta(context,
                                size: 9,
                                weight: FontWeight.w800,
                                color: colors.textMuted)
                            .copyWith(letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    child: Text('Days *',
                        style: jakarta(context,
                                size: 9,
                                weight: FontWeight.w800,
                                color: colors.indigo)
                            .copyWith(letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: Text('Amount (₹)',
                        style: jakarta(context,
                                size: 9,
                                weight: FontWeight.w800,
                                color: colors.textMuted)
                            .copyWith(letterSpacing: 0.5),
                        textAlign: TextAlign.right),
                  ),
                  const SizedBox(width: 28),
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: colors.border),
          ],
          // Height rows (descending)
          ...sortedH.map((h) => _buildRbHeightRow(sizeKey, h, colors)),
          // Shoe row
          if (shoeOn) _buildRbShoeRow(sizeKey, colors),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildRbHeightRow(String sizeKey, int h, AppColors colors) {
    final qtyCtr = _rbQtyControllers[sizeKey]![h]!;
    final rateCtr = _rbRateControllers[sizeKey]![h]!;
    final daysCtr = _rbHeightDaysCtrl[sizeKey]?[h];
    final qty = int.tryParse(qtyCtr.text) ?? 0;
    final rate = double.tryParse(rateCtr.text) ?? 0.0;
    final days = int.tryParse(daysCtr?.text ?? '') ?? 0;
    final amount = (qty > 0 && rate > 0) ? qty * rate : null;
    final daysEmpty = days == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 2),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text('${h}ft',
                style: jakarta(context,
                    size: 13,
                    weight: FontWeight.w700,
                    color: colors.textMain)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: qtyCtr,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: jakarta(context, size: 13, color: colors.textMain),
              decoration: _cbFieldDeco(colors),
              onChanged: (_) => setState(() => _syncRoundBoxes()),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: rateCtr,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
              ],
              style: jakarta(context, size: 13, color: colors.textMain),
              decoration: _cbFieldDeco(colors),
              onChanged: (_) => setState(() => _syncRoundBoxes()),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: TextField(
              controller: daysCtr,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: jakarta(context, size: 13, color: colors.textMain),
              decoration: _cbFieldDeco(colors).copyWith(
                hintText: '0',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: daysEmpty ? colors.indigo.withOpacity(0.5) : colors.border,
                    width: daysEmpty ? 1.5 : 0.5,
                  ),
                ),
              ),
              onChanged: (_) => setState(() => _syncRoundBoxes()),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              amount != null ? '₹${amount.toStringAsFixed(0)}' : '—',
              style: jakarta(context,
                  size: 13,
                  weight: FontWeight.w700,
                  color: amount != null ? colors.teal : colors.textMuted),
              textAlign: TextAlign.right,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 16, color: colors.textMuted),
            onPressed: () => _rbRemoveHeight(sizeKey, h),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildRbShoeRow(String sizeKey, AppColors colors) {
    final qtyCtr  = _rbShoeQtyControllers[sizeKey]!;
    final rateCtr = _rbShoeRateControllers[sizeKey]!;
    final daysCtr = _rbDaysControllers[sizeKey];
    final qty  = int.tryParse(qtyCtr.text) ?? 0;
    final rate = double.tryParse(rateCtr.text) ?? 0.0;
    final days = int.tryParse(daysCtr?.text ?? '') ?? 0;
    final amount = (qty > 0 && rate > 0) ? qty * rate : null;
    final daysEmpty = days == 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 2),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text('Shoe',
                style: jakarta(context,
                    size: 13,
                    weight: FontWeight.w700,
                    color: colors.teal)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: qtyCtr,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: jakarta(context, size: 13, color: colors.textMain),
              decoration: _cbFieldDeco(colors),
              onChanged: (_) => setState(() => _syncRoundBoxes()),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: rateCtr,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
              ],
              style: jakarta(context, size: 13, color: colors.textMain),
              decoration: _cbFieldDeco(colors),
              onChanged: (_) => setState(() => _syncRoundBoxes()),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: TextField(
              controller: daysCtr,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: jakarta(context, size: 13, color: colors.textMain),
              decoration: _cbFieldDeco(colors).copyWith(
                hintText: '0',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: daysEmpty
                        ? colors.indigo.withOpacity(0.5)
                        : colors.border,
                    width: daysEmpty ? 1.5 : 0.5,
                  ),
                ),
              ),
              onChanged: (_) => setState(() => _syncRoundBoxes()),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              amount != null ? '₹${amount.toStringAsFixed(0)}' : '—',
              style: jakarta(context,
                  size: 13,
                  weight: FontWeight.w700,
                  color: amount != null ? colors.teal : colors.textMuted),
              textAlign: TextAlign.right,
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 16, color: colors.textMuted),
            onPressed: () => _rbRemoveShoe(sizeKey),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── Others (free-form materials) tab ─────────────────────────────────────

  void _addMat() => setState(() => _mats.add(MatEntry()));
  void _removeMat(int i) => setState(() => _mats.removeAt(i));

  Widget _buildOthersTab(AppColors colors, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_mats.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Add materials with name, size, days, qty and rate.\nDue date is calculated automatically from the bill date.',
              style: jakarta(context, size: 12, color: colors.textMuted),
            ),
          ),
        ..._mats.asMap().entries.map((e) => RateCardPickerRow(
              key: ValueKey(e.key),
              entry: e.value,
              index: e.key,
              isDark: isDark,
              onChanged: () => setState(() {}),
              onRemove: () => _removeMat(e.key),
            )),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _addMat,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: colors.teal.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: colors.teal.withOpacity(0.25), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline_rounded,
                    size: 18, color: colors.teal),
                const SizedBox(width: 8),
                Text('Add Material',
                    style: jakarta(context,
                        size: 13,
                        weight: FontWeight.w700,
                        color: colors.teal)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _baseDateFormatted() {
    const mo = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${_baseDate.day} ${mo[_baseDate.month - 1]} ${_baseDate.year}';
  }
}

class _FinRow extends StatelessWidget {
  final String label;
  final String value;
  final AppColors colors;
  final BuildContext context;
  final bool isMuted;
  const _FinRow({required this.label, required this.value, required this.colors, required this.context, this.isMuted = false});
  @override
  Widget build(BuildContext ctx) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: jakarta(context, size: 13, weight: FontWeight.w600, color: isMuted ? colors.textMuted : colors.textSub)),
        Text(value, style: jakarta(context, size: 13, weight: FontWeight.w700, color: isMuted ? colors.textMuted : colors.textMain)),
      ],
    );
  }
}

class _FinInputRow extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final AppColors colors;
  final BuildContext context;
  final VoidCallback onChanged;
  const _FinInputRow({required this.label, required this.ctrl, required this.colors, required this.context, required this.onChanged});
  @override
  Widget build(BuildContext ctx) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: jakarta(context, size: 13, weight: FontWeight.w600, color: colors.textSub)),
        ),
        Expanded(
          flex: 1,
          child: TextFormField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            textAlign: TextAlign.right,
            style: jakarta(context, size: 13, color: colors.textMain),
            decoration: InputDecoration(
              hintText: '0',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border, width: 0.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.border, width: 0.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.indigo, width: 1.5)),
            ),
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  final AppColors colors;
  const _InfoTile(this.label, this.value, this.colors);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border, width: 0.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: jakarta(context,
                  size: 9, weight: FontWeight.w800, color: colors.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              style: jakarta(context,
                  size: 12, weight: FontWeight.w700, color: colors.textMain),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _TypeOpt extends StatelessWidget {
  final String label, desc;
  final bool on, isTeal;
  final VoidCallback onTap;
  const _TypeOpt(
      {required this.label,
      required this.desc,
      required this.on,
      required this.isTeal,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color getBgColor() {
      if (!on) return colors.surface;
      if (isTeal) return colors.tealBg;
      return isDark
          ? const Color(0xFF14224A).withOpacity(0.5)
          : const Color(0xFFF0F4FF);
    }

    Color getBdColor() {
      if (!on) return colors.border;
      if (isTeal) return colors.teal;
      return isDark ? const Color(0xFF2548B5) : const Color(0xFF3454B4);
    }

    Color getTextColor() {
      if (!on) return colors.textMain;
      if (isTeal) return colors.teal;
      return isDark ? const Color(0xFF8BA5F5) : const Color(0xFF1D3A8F);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: getBgColor(),
          border: Border.all(color: getBdColor(), width: on ? 1.5 : 0.5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: colors.glow, blurRadius: 16, offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: jakarta(context,
                  size: 13, weight: FontWeight.w800, color: getTextColor())),
          const SizedBox(height: 4),
          Text(desc,
              style: jakarta(context, size: 11, color: colors.textMuted)),
        ]),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(),
          style: jakarta(context,
                  size: 9, weight: FontWeight.w800, color: colors.textMuted)
              .copyWith(letterSpacing: 2)),
    );
  }
}

class _Field extends StatelessWidget {
  final String hint;
  final AppColors colors;
  final TextEditingController controller;
  final FocusNode? focusNode;
  const _Field(
      {required this.hint,
      required this.colors,
      required this.controller,
      this.focusNode});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 0),
        child: TextFormField(
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
                borderSide: BorderSide(color: colors.indigo, width: 1.5)),
            filled: true,
            fillColor: colors.surface,
          ),
        ),
      );
}

