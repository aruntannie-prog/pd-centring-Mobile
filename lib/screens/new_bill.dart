import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/bill.dart';
import '../models/customer.dart';
import '../models/store.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

const _uuid = Uuid();

class _MatEntry {
  String name;
  int? days;
  _MatEntry({this.name = '', this.days});
}

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

class _NewBillScreenState extends State<NewBillScreen> {
  BillType _type = BillType.bill;
  String _customerName = '';
  String _customerId = '';
  final _siteCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _billNumCtrl = TextEditingController();
  final List<_MatEntry> _mats = [];
  DateTime _baseDate = DateTime.now();
  String _selectedBranch = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialBill != null) {
      final b = widget.initialBill!;
      _type = b.type;
      _customerName = b.customerName;
      _customerId = b.customerId;
      _siteCtrl.text = b.site;
      _baseDate = b.billDate;
      for (final m in b.materials) {
        _mats.add(_MatEntry(name: m.name, days: m.days));
      }
      _billNumCtrl.text = b.billNumber;
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
    _siteCtrl.dispose();
    _phoneCtrl.dispose();
    _gstCtrl.dispose();
    _billNumCtrl.dispose();
    super.dispose();
  }

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

  void _save(AppColors colors) {
    if (_selectedBranch.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Please select a Branch (Kovilambakkam / Rathinamangalam)'),
            backgroundColor: const Color(0xFFFF5555),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
      );
      return;
    }
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
    if (_mats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Please add at least one material'),
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
      materials: _mats
          .map((m) => RentalMaterial(
                name: m.name,
                days: m.days!,
                dueDate: _baseDate.add(Duration(days: m.days!)),
              ))
          .toList(),
    );

    if (widget.initialBill != null) {
      store.updateBill(newBill);
    } else {
      store.addBill(newBill);
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
              onTap: widget.onBack,
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
              // Branch selector
              _Label('Branch / Location *'),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedBranch = 'Kovilambakkam'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedBranch == 'Kovilambakkam'
                            ? (isDark ? const Color(0xFF1A2A4E) : const Color(0xFFE8F0FE))
                            : colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedBranch == 'Kovilambakkam'
                              ? (isDark ? const Color(0xFF2A3D70) : const Color(0xFFD0DFFF))
                              : colors.border,
                          width: _selectedBranch == 'Kovilambakkam' ? 1.5 : 0.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Kovilambakkam',
                        style: jakarta(context,
                            size: 13,
                            weight: _selectedBranch == 'Kovilambakkam' ? FontWeight.w800 : FontWeight.w600,
                            color: _selectedBranch == 'Kovilambakkam' ? colors.brand : colors.textMuted),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedBranch = 'Rathinamangalam'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _selectedBranch == 'Rathinamangalam'
                            ? (isDark ? const Color(0xFF0A2E28) : const Color(0xFFE6F7F5))
                            : colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedBranch == 'Rathinamangalam'
                              ? (isDark ? const Color(0xFF145E50) : const Color(0xFFBBEAE5))
                              : colors.border,
                          width: _selectedBranch == 'Rathinamangalam' ? 1.5 : 0.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Rathinamangalam',
                        style: jakarta(context,
                            size: 13,
                            weight: _selectedBranch == 'Rathinamangalam' ? FontWeight.w800 : FontWeight.w600,
                            color: _selectedBranch == 'Rathinamangalam' ? colors.teal : colors.textMuted),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              // Type selector
              Row(children: [
                Expanded(
                    child: _TypeOpt(
                        label: '📋   Regular Bill',
                        desc: 'Rental invoice',
                        on: _type == BillType.bill,
                        isTeal: true,
                        onTap: () => setState(() => _type = BillType.bill))),
                const SizedBox(width: 12),
                Expanded(
                    child: _TypeOpt(
                        label: '🚛   DC Bill',
                        desc: 'Delivery Challan',
                        on: _type == BillType.dc,
                        isTeal: false,
                        onTap: () => setState(() => _type = BillType.dc))),
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
                                        ? colors.brand.withOpacity(0.1)
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
              SectionHeader('MATERIALS',
                  action: '+ Add',
                  onAction: () => setState(() => _mats.add(_MatEntry()))),
              ..._mats.asMap().entries.map((e) {
                final i = e.key;
                final m = e.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.border, width: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: colors.glow,
                            blurRadius: 16,
                            offset: const Offset(0, 4))
                      ]),
                  child: Stack(children: [
                    // accent bar
                    Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                            width: 4,
                            decoration: BoxDecoration(
                                borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(20)),
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      _type == BillType.bill
                                          ? colors.teal
                                          : colors.brand,
                                      _type == BillType.bill
                                          ? const Color(0xFF075A4E)
                                          : const Color(0xFF03265D)
                                    ])))),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      'Material ${String.fromCharCode(65 + i)}',
                                      style: jakarta(context,
                                              size: 10,
                                              weight: FontWeight.w800,
                                              color: colors.textMain)
                                          .copyWith(letterSpacing: 2)),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _mats.removeAt(i)),
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFFFF4D5E)
                                                    .withOpacity(.15)
                                                : const Color(0xFFFFF0F1),
                                            border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFFFF4D5E)
                                                        .withOpacity(.3)
                                                    : const Color(0xFFFFD1D6),
                                                width: 0.5),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Text('✕ Remove',
                                            style: jakarta(context,
                                                size: 10,
                                                weight: FontWeight.w700,
                                                color:
                                                    const Color(0xFFFF5555)))),
                                  ),
                                ]),
                            const SizedBox(height: 16),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      flex: 3,
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _Label('Material'),
                                            Autocomplete<String>(
                                              initialValue: TextEditingValue(
                                                  text: m.name),
                                              displayStringForOption: (option) {
                                                if (option
                                                    .startsWith('Add New: "')) {
                                                  return option.split('"')[1];
                                                }
                                                return option;
                                              },
                                              optionsBuilder:
                                                  (TextEditingValue v) {
                                                final input = v.text.trim();
                                                if (input.isEmpty)
                                                  return const Iterable<
                                                      String>.empty();

                                                final existing = store
                                                    .suggestions
                                                    .where((s) => s
                                                        .toLowerCase()
                                                        .contains(input
                                                            .toLowerCase()))
                                                    .toList();

                                                if (input.isNotEmpty) {
                                                  final exactMatch =
                                                      existing.any((s) =>
                                                          s.toLowerCase() ==
                                                          input.toLowerCase());
                                                  if (!exactMatch) {
                                                    existing.insert(
                                                        0, 'Add New: "$input"');
                                                  }
                                                }
                                                return existing;
                                              },
                                              onSelected: (v) {
                                                if (v
                                                    .startsWith('Add New: "')) {
                                                  final name = v.split('"')[1];
                                                  setState(() => m.name = name);
                                                  // Persist new material to Suggestions sheet
                                                  context
                                                      .read<AppStore>()
                                                      .addSuggestion(name);
                                                } else {
                                                  setState(() => m.name = v);
                                                }
                                              },
                                              fieldViewBuilder: (ctx, ctrl,
                                                  focus, onFieldSubmitted) {
                                                ctrl.addListener(() {
                                                  if (!ctrl.text
                                                      .startsWith('Add New:')) {
                                                    m.name = ctrl.text;
                                                  }
                                                });
                                                return TextFormField(
                                                  controller: ctrl,
                                                  focusNode: focus,
                                                  style: jakarta(context,
                                                      size: 13,
                                                      color: colors.textMain),
                                                  decoration: InputDecoration(
                                                    contentPadding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 12,
                                                            vertical: 12),
                                                    border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        borderSide: BorderSide(
                                                            color:
                                                                colors.border,
                                                            width: 0.5)),
                                                    enabledBorder:
                                                        OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            borderSide:
                                                                BorderSide(
                                                                    color: colors
                                                                        .border,
                                                                    width:
                                                                        0.5)),
                                                    focusedBorder:
                                                        OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            borderSide:
                                                                BorderSide(
                                                                    color: colors
                                                                        .brand,
                                                                    width:
                                                                        1.5)),
                                                    filled: true,
                                                    fillColor: colors.surface,
                                                  ),
                                                );
                                              },
                                              optionsViewBuilder:
                                                  (ctx, onSelected, options) {
                                                return Align(
                                                  alignment: Alignment.topLeft,
                                                  child: Material(
                                                    elevation: 8,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    clipBehavior: Clip.hardEdge,
                                                    child: Container(
                                                      width:
                                                          200, // compact width for material
                                                      color: colors.surface,
                                                      constraints:
                                                          const BoxConstraints(
                                                              maxHeight: 250),
                                                      child: ListView.builder(
                                                        padding:
                                                            EdgeInsets.zero,
                                                        shrinkWrap: true,
                                                        itemCount:
                                                            options.length,
                                                        itemBuilder: (ctx, i) {
                                                          final s = options
                                                              .elementAt(i);
                                                          final isNew =
                                                              s.startsWith(
                                                                  'Add New:');
                                                          return ListTile(
                                                            dense: true,
                                                            title: Text(s,
                                                                style: jakarta(
                                                                    context,
                                                                    size: 12,
                                                                    weight: isNew
                                                                        ? FontWeight
                                                                            .w800
                                                                        : FontWeight
                                                                            .w600,
                                                                    color: isNew
                                                                        ? colors
                                                                            .brand
                                                                        : colors
                                                                            .textMain)),
                                                            onTap: () =>
                                                                onSelected(s),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ])),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      flex: 1,
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _Label('Days'),
                                            TextFormField(
                                              initialValue: m.days == null
                                                  ? ''
                                                  : '${m.days}',
                                              keyboardType:
                                                  TextInputType.number,
                                              style: jakarta(context,
                                                  size: 13,
                                                  color: colors.textMain),
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 12),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    borderSide: BorderSide(
                                                        color: colors.border,
                                                        width: 0.5)),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        borderSide: BorderSide(
                                                            color:
                                                                colors.border,
                                                            width: 0.5)),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        borderSide: BorderSide(
                                                            color: colors.brand,
                                                            width: 1.5)),
                                                filled: true,
                                                fillColor: colors.surface,
                                              ),
                                              onChanged: (v) => setState(() =>
                                                  m.days = int.tryParse(v)),
                                            ),
                                          ])),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      flex: 2,
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _Label('Due'),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8),
                                              decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: isDark
                                                        ? [
                                                            const Color(
                                                                0xFF2A1F0D),
                                                            const Color(
                                                                0xFF1E1505)
                                                          ]
                                                        : [
                                                            const Color(
                                                                0xFFFFF9EE),
                                                            const Color(
                                                                0xFFFFF4D9)
                                                          ],
                                                  ),
                                                  border: Border.all(
                                                      color: isDark
                                                          ? const Color(
                                                              0xFF70521F)
                                                          : const Color(
                                                              0xFFFFDCA8),
                                                      width: 0.5),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: (isDark
                                                                ? const Color(
                                                                    0xFF70521F)
                                                                : const Color(
                                                                    0xFFFFDCA8))
                                                            .withOpacity(0.2),
                                                        blurRadius: 8,
                                                        offset:
                                                            const Offset(0, 2))
                                                  ]),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text('📅 DUE',
                                                        style: jakarta(context,
                                                                size: 8,
                                                                weight:
                                                                    FontWeight
                                                                        .w800,
                                                                color: const Color(
                                                                    0xFFD49900))
                                                            .copyWith(
                                                                letterSpacing:
                                                                    1.0)),
                                                    const SizedBox(height: 2),
                                                    Text(_dueLabel(m.days),
                                                        style: (m.days ==
                                                                    null ||
                                                                m.days == 0)
                                                            ? jakarta(context,
                                                                size: 10,
                                                                weight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: const Color(
                                                                    0xFFFF5555))
                                                            : GoogleFonts.playfairDisplay(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: isDark
                                                                    ? const Color(
                                                                        0xFFFFC043)
                                                                    : const Color(
                                                                        0xFFB18000)),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis),
                                                  ]),
                                            )
                                          ])),
                                ]),
                          ]),
                    ),
                  ]),
                );
              }),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _mats.add(_MatEntry())),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: colors.border,
                          width: 1.5,
                          style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            color: colors.brand, size: 20),
                        const SizedBox(width: 8),
                        Text('Add Another Material',
                            style: jakarta(context,
                                size: 13,
                                weight: FontWeight.w700,
                                color: colors.textMain)),
                      ]),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => _save(colors),
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
                          'SAVE ${_type == BillType.bill ? "BILL" : "DC"} ${_billNumCtrl.text}',
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
                borderSide: BorderSide(color: colors.brand, width: 1.5)),
            filled: true,
            fillColor: colors.surface,
          ),
        ),
      );
}
