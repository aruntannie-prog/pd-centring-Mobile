import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'models/bill.dart';
import 'models/customer.dart';
import 'models/store.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart' show showUnsavedChangesDialog;
import 'screens/splash.dart';
import 'screens/dashboard.dart';
import 'screens/bills.dart';
import 'screens/bill_detail.dart';
import 'screens/new_bill.dart';
import 'screens/customers.dart';
import 'screens/customer_detail.dart';
import 'screens/add_customer.dart';
import 'screens/filter.dart';
import 'screens/reports.dart';
import 'screens/branch_select.dart';
import 'screens/consolidate_bill.dart';
import 'screens/customer_ledger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/login.dart';
import 'services/sheets_db.dart';
import 'services/drive_api.dart';
import 'services/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    print('Error loading .env file: $e');
  }
  await LocalStorage.init();

  // Boot the UI instantly. AppStore will initialize APIs asynchronously.
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppStore()..initialize(),
      child: const PDCentringApp(),
    ),
  );
}

class PDCentringApp extends StatelessWidget {
  const PDCentringApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PD Centring',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: StreamBuilder(
          stream: AuthService.userStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (snapshot.hasData) {
              return const AppShell();
            }
            return const LoginScreen();
          },
        ),
        // Constrain to phone width on web/desktop
        builder: (context, child) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Material(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: child ?? const SizedBox(),
              ),
            ),
          );
        },
      );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _showSplash = true;
  bool _showBranchSelect = false;
  int _tab = 0;

  // Stack-based navigation within each tab
  Bill? _selectedBill;
  Bill? _editingBill;
  bool _showNewBill = false;
  bool _showConsolidate = false;
  bool _showAddCustomer = false;
  Customer? _selectedCustomer;
  Customer? _editingCustomer;
  Customer? _lastCreatedCustomer;
  Customer? _ledgerCustomer;

  void _onSplashDone() {
    final branch = context.read<AppStore>().selectedBranch;
    setState(() {
      _showSplash = false;
      _showBranchSelect = branch.isEmpty;
    });
  }

  void _onBranchSelected(String _) => setState(() => _showBranchSelect = false);
  void _switchBranch() => setState(() => _showBranchSelect = true);

  void _openBill(Bill b) => setState(() {
        _selectedBill = b;
      });
  void _closeBill() => setState(() => _selectedBill = null);

  void _openNewBill() {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Text('New Entry',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: colors.textMain)),
          const SizedBox(height: 6),
          Text('What would you like to create?',
              style: jakarta(ctx,
                  size: 13, color: colors.textMuted)),
          const SizedBox(height: 24),
          // Option 1: Create DC / Bill
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _showNewBill = true;
                _lastCreatedCustomer = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF14224A).withValues(alpha: 0.5)
                    : const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF2548B5)
                        : const Color(0xFFD0DFFF),
                    width: 1),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: colors.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.local_shipping_rounded,
                      size: 24, color: colors.brand),
                ),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Create DC / Bill',
                          style: jakarta(ctx,
                              size: 15,
                              weight: FontWeight.w800,
                              color: colors.brand)),
                      const SizedBox(height: 2),
                      Text('New delivery challan or direct invoice',
                          style: jakarta(ctx,
                              size: 12, color: colors.textMuted)),
                    ])),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: colors.brand),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Option 2: Consolidate DCs → Bill
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _showConsolidate = true;
                _lastCreatedCustomer = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0A2E28).withValues(alpha: 0.6)
                    : const Color(0xFFE6F7F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF145E50)
                        : const Color(0xFFBBEAE5),
                    width: 1),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: colors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.receipt_long_rounded,
                      size: 24, color: colors.teal),
                ),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Consolidate DCs → Bill',
                          style: jakarta(ctx,
                              size: 15,
                              weight: FontWeight.w800,
                              color: colors.teal)),
                      const SizedBox(height: 2),
                      Text('Combine multiple DCs into one invoice',
                          style: jakarta(ctx,
                              size: 12, color: colors.textMuted)),
                    ])),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: colors.teal),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  void _closeNewBill() => setState(() {
        _showNewBill = false;
        _showConsolidate = false;
        _editingBill = null;
        _lastCreatedCustomer = null;
      });

  void _onEditBill(Bill b) => setState(() {
        _editingBill = b;
        _selectedBill = null;
        _showNewBill = true;
      });

  void _openCustomer(Customer c) => setState(() {
        _selectedCustomer = c;
      });
  void _closeCustomer() => setState(() => _selectedCustomer = null);

  void _openLedger(Customer c) => setState(() {
        _ledgerCustomer = c;
        // _selectedCustomer stays set so back returns to customer detail
      });
  void _closeLedger() => setState(() => _ledgerCustomer = null);

  void _openAddCustomer() {
    print('AppShell: Opening Add Customer Overlay');
    setState(() => _showAddCustomer = true);
  }

  void _closeAddCustomer() => setState(() {
        _showAddCustomer = false;
        _editingCustomer = null;
      });

  void _onEditCustomer(Customer c) => setState(() {
        _editingCustomer = c;
        _selectedCustomer = null;
        _showAddCustomer = true;
      });

  void _navTo(int tab) => setState(() {
    _tab = tab;
    _selectedBill = null;
    _editingBill = null;
    _showNewBill = false;
    _showAddCustomer = false;
    _selectedCustomer = null;
    _editingCustomer = null;
  });

  bool _canPop() {
    return _selectedBill == null &&
        !_showAddCustomer &&
        _ledgerCustomer == null &&
        _selectedCustomer == null &&
        !_showNewBill &&
        !_showConsolidate &&
        _tab == 0;
  }

  void _handleSystemBack() {
    if (_selectedBill != null) {
      _closeBill();
    } else if (_showAddCustomer) {
      _closeAddCustomer();
    } else if (_ledgerCustomer != null) {
      _closeLedger();
    } else if (_selectedCustomer != null) {
      _closeCustomer();
    } else if (_showNewBill || _showConsolidate) {
      _closeNewBill();
    } else if (_tab != 0) {
      _navTo(0);
    }
  }

  ThemeData _branchTheme(BuildContext context) {
    final branch = context.watch<AppStore>().selectedBranch;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (branch == 'Rathinamangalam') {
      return isDark ? AppTheme.darkThemeBranch2 : AppTheme.lightThemeBranch2;
    }
    return Theme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    final branchTheme = _branchTheme(context);

    if (_showSplash) return SplashScreen(onDone: _onSplashDone);

    if (_showBranchSelect) {
      return Theme(
        data: branchTheme,
        child: BranchSelectScreen(
          onSelected: _onBranchSelected,
          isSwitching: context.read<AppStore>().selectedBranch.isNotEmpty,
        ),
      );
    }

    Widget content;
    if (_selectedBill != null) {
      content = BillDetailScreen(
        bill: _selectedBill!,
        onBack: _closeBill,
        onEdit: _onEditBill,
      );
    } else if (_showAddCustomer) {
      content = AddCustomerScreen(
        onBack: _closeAddCustomer,
        onSave: (c) => setState(() {
          _lastCreatedCustomer = c;
          _showAddCustomer = false;
        }),
        initialCustomer: _editingCustomer,
      );
    } else if (_ledgerCustomer != null) {
      content = CustomerLedgerScreen(
        customer: _ledgerCustomer!,
        onBack: _closeLedger,
        onBillTap: _openBill,
      );
    } else if (_selectedCustomer != null) {
      content = CustomerDetailScreen(
        customer: _selectedCustomer!,
        onBack: _closeCustomer,
        onEdit: _onEditCustomer,
        onLedger: () => _openLedger(_selectedCustomer!),
      );
    } else if (_showNewBill) {
      content = NewBillScreen(
        onBack: _closeNewBill,
        onSaved: () {
          _closeNewBill();
          _navTo(1);
        },
        onAddNewCustomer: _openAddCustomer,
        lastCreatedCustomer: _lastCreatedCustomer,
        initialBill: _editingBill,
        branch: context.read<AppStore>().selectedBranch,
      );
    } else if (_showConsolidate) {
      content = ConsolidateBillScreen(
        onBack: _closeNewBill,
        onSaved: () {
          _closeNewBill();
          _navTo(1);
        },
        onAddNewCustomer: _openAddCustomer,
        lastCreatedCustomer: _lastCreatedCustomer,
        branch: context.read<AppStore>().selectedBranch,
      );
    } else {
      content = Scaffold(
        extendBody: true, // For floating bottom bar effect
        body: _buildTab(),
        bottomNavigationBar: _BottomNav(current: _tab, onTap: _navTo),
      );
    }

    return Theme(
      data: branchTheme,
      child: PopScope(
      canPop: _canPop(),
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Show confirmation before discarding unsaved form data
        if (_showNewBill || _showConsolidate || _showAddCustomer) {
          final leave = await showUnsavedChangesDialog(context);
          if (!leave || !mounted) return;
        }
        _handleSystemBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        ),
        child: SafeArea(
          maintainBottomViewPadding: true,
          top: true,
          bottom: true, // Always apply bottom safety — covers all tabs and overlay screens
          child: content,
        ),
      ),
    ));
  }

  Widget _buildTab() {
    switch (_tab) {
      case 0:
        return DashboardScreen(
          onNav: _navTo,
          onBillTap: _openBill,
          onAddCustomer: _openAddCustomer,
          onNewBill: _openNewBill,
          onSwitchBranch: _switchBranch,
        );
      case 1:
        return BillsScreen(
          onBillTap: _openBill,
          onNewBill: _openNewBill,
        );
      case 2:
        return CustomersScreen(
          onAddCustomer: _openAddCustomer,
          onCustomerTap: _openCustomer,
        );
      case 3:
        return FilterScreen(onBillTap: _openBill);
      case 4:
        return const ReportsScreen();
      default:
        return DashboardScreen(
            onNav: _navTo,
            onBillTap: _openBill,
            onAddCustomer: _openAddCustomer,
            onNewBill: _openNewBill,
            onSwitchBranch: _switchBranch);
    }
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final Function(int) onTap;
  const _BottomNav({required this.current, required this.onTap});

  static const _items = [
    ('⌂', 'Home'),
    ('◉', 'Bills'),
    ('◎', 'Clients'),
    ('≡', 'Filter'),
    ('▣', 'Reports'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final navBottom = bottomInset > 0 ? bottomInset + 8 : 24;

    return Container(
      margin: EdgeInsets.only(left: 14, right: 14, bottom: navBottom.toDouble()),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colors.border.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: colors.glow, blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                ...List.generate(_items.length, (i) {
                  final on = i == current;
                  final item = _items[i];
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: on ? colors.brand : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getIcon(item.$1),
                              size: 22,
                              color: on ? colors.surface : colors.textMuted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.$2.toUpperCase(),
                              style: jakarta(context,
                                      size: 7.5,
                                      weight: FontWeight.w800,
                                      color: on
                                          ? colors.surface.withOpacity(0.9)
                                          : colors.textMuted)
                                  .copyWith(letterSpacing: .8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () async {
                    // Show confirmation dialog before logging out
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext ctx) => AlertDialog(
                        backgroundColor: colors.surface,
                        title: Text('Confirm Logout', 
                            style: jakarta(context, size: 18, weight: FontWeight.w800, color: colors.textMain)),
                        content: Text('Are you sure you want to log out of PD Centring?',
                            style: jakarta(context, size: 14, color: colors.textSub)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text('Cancel', style: jakarta(context, size: 14, weight: FontWeight.w700, color: colors.textMuted)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5555),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: Text('Logout', style: jakarta(context, size: 14, weight: FontWeight.w800, color: Colors.white)),
                          ),
                        ],
                      ),
                    );

                    if (shouldLogout == true) {
                      await context.read<AppStore>().sync();
                      await AuthService.logout();
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5555).withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFF5555).withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFFFF5555)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String sym) => switch (sym) {
        '⌂' => Icons.home_rounded,
        '◉' => Icons.receipt_long_rounded,
        '◎' => Icons.people_alt_rounded,
        '≡' => Icons.filter_list_rounded,
        '▣' => Icons.pie_chart_rounded,
        _ => Icons.circle,
      };
}
