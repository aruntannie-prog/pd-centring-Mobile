import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/expiry.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import 'alerts_screen.dart';
import 'customers_screen.dart';
import 'deliveries_screen.dart';
import 'delivery_form_screen.dart';
import 'settings_screen.dart';

/// Four sections: Alerts (home), Deliveries, Customers, Settings.
/// Bottom navigation bar on phones, navigation rail on tablets and web.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0});

  /// Tab shown first: 0 Alerts, 1 Deliveries, 2 Customers, 3 Settings.
  final int initialIndex;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;
  final _deliveryFilter = ValueNotifier<DeliveryFilter>(DeliveryFilter.open);

  static const _destinations = [
    (Icons.notifications_none_rounded, Icons.notifications_rounded, 'Alerts'),
    (Icons.local_shipping_outlined, Icons.local_shipping_rounded, 'Deliveries'),
    (Icons.people_outline_rounded, Icons.people_rounded, 'Customers'),
    (Icons.tune_rounded, Icons.tune_rounded, 'Settings'),
  ];

  @override
  void dispose() {
    _deliveryFilter.dispose();
    super.dispose();
  }

  void _showDeliveries(DeliveryFilter filter) {
    _deliveryFilter.value = filter;
    setState(() => _index = 1);
  }

  @override
  Widget build(BuildContext context) {
    final expiredCount = context.select<AppState, int>(
      (a) => a.withStatus(ExpiryStatus.expired).length,
    );

    final pages = [
      AlertsScreen(onShowDeliveries: _showDeliveries),
      DeliveriesScreen(filter: _deliveryFilter),
      const CustomersScreen(),
      const SettingsScreen(),
    ];

    Widget icon(int i, {required bool selected}) {
      final d = _destinations[i];
      final ic = Icon(selected ? d.$2 : d.$1);
      if (i == 0 && expiredCount > 0) {
        return Badge(label: Text('$expiredCount'), child: ic);
      }
      return ic;
    }

    // Kept on this Scaffold (not the tab's own) so snack bars push it up.
    final fab = switch (_index) {
      0 || 1 => FloatingActionButton.extended(
        heroTag: 'new-delivery',
        onPressed: () => DeliveryFormScreen.open(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New delivery'),
      ),
      2 => FloatingActionButton.extended(
        heroTag: 'new-customer',
        onPressed: () => addCustomer(context),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add customer'),
      ),
      _ => null,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final body = IndexedStack(index: _index, children: pages);

        if (wide) {
          return Scaffold(
            floatingActionButton: fab,
            body: Row(
              children: [
                NavigationRail(
                  leading: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: SdColors.ember,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.construction_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (var i = 0; i < _destinations.length; i++)
                      NavigationRailDestination(
                        icon: icon(i, selected: false),
                        selectedIcon: icon(i, selected: true),
                        label: Text(_destinations[i].$3),
                      ),
                  ],
                ),
                VerticalDivider(width: 1, color: context.sd.line),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          floatingActionButton: fab,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.sd.line)),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (var i = 0; i < _destinations.length; i++)
                  NavigationDestination(
                    icon: icon(i, selected: false),
                    selectedIcon: icon(i, selected: true),
                    label: _destinations[i].$3,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
