import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/expiry.dart';
import '../../state/app_state.dart';
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
    (Icons.notifications_active_outlined, Icons.notifications_active, 'Alerts'),
    (Icons.local_shipping_outlined, Icons.local_shipping, 'Deliveries'),
    (Icons.people_alt_outlined, Icons.people_alt, 'Customers'),
    (Icons.tune_outlined, Icons.tune, 'Settings'),
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

    final showFab = _index == 0 || _index == 1;
    final fab = showFab
        ? FloatingActionButton.extended(
            heroTag: 'new-delivery',
            onPressed: () => DeliveryFormScreen.open(context),
            icon: const Icon(Icons.add),
            label: const Text('New delivery'),
          )
        : null;

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
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          floatingActionButton: fab,
          bottomNavigationBar: NavigationBar(
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
        );
      },
    );
  }
}
