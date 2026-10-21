import 'package:flutter/material.dart';

import '../controller/app_controller.dart';
import 'overview_page.dart';
import 'profiles_page.dart';
import 'routing_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      OverviewPage(controller: widget.controller),
      RoutingPage(controller: widget.controller),
      ProfilesPage(controller: widget.controller),
    ];
    final destinations = const [
      NavigationDestination(
        icon: Icon(Icons.shield_outlined),
        selectedIcon: Icon(Icons.shield),
        label: 'Connection',
      ),
      NavigationDestination(
        icon: Icon(Icons.alt_route_outlined),
        selectedIcon: Icon(Icons.alt_route),
        label: 'Routing',
      ),
      NavigationDestination(
        icon: Icon(Icons.dns_outlined),
        selectedIcon: Icon(Icons.dns),
        label: 'Profiles',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 780) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: NavigationRail(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (value) {
                        setState(() => selectedIndex = value);
                      },
                      extended: constraints.maxWidth >= 1050,
                      leading: const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: _Brand(),
                      ),
                      destinations: destinations
                          .map(
                            (item) => NavigationRailDestination(
                              icon: item.icon,
                              selectedIcon: item.selectedIcon,
                              label: Text(item.label),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: pages[selectedIndex]),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const _Brand()),
          body: SafeArea(child: pages[selectedIndex]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (value) {
              setState(() => selectedIndex = value);
            },
            destinations: destinations,
          ),
        );
      },
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.hub_outlined),
        SizedBox(width: 10),
        Text('Adaptive VPN', style: TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
