import 'package:flutter/material.dart';

import 'controller/app_controller.dart';
import 'screens/home_shell.dart';
import 'services/profile_store.dart';
import 'services/rule_set_service.dart';
import 'services/subscription_service.dart';
import 'services/tunnel_service.dart';

class AdaptiveVpnApp extends StatefulWidget {
  const AdaptiveVpnApp({
    super.key,
    required this.tunnelService,
    this.profileStore,
    this.subscriptionService,
    this.ruleSetService,
  });

  final TunnelService tunnelService;
  final ProfileStore? profileStore;
  final SubscriptionService? subscriptionService;
  final RuleSetService? ruleSetService;

  @override
  State<AdaptiveVpnApp> createState() => _AdaptiveVpnAppState();
}

class _AdaptiveVpnAppState extends State<AdaptiveVpnApp> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    controller = AppController(
      tunnelService: widget.tunnelService,
      profileStore: widget.profileStore ?? MemoryProfileStore(),
      subscriptionService: widget.subscriptionService ?? SubscriptionService(),
      ruleSetService: widget.ruleSetService ?? RuleSetService(),
    );
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF15B8A6);
    return MaterialApp(
      title: 'Adaptive VPN',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1318),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        useMaterial3: true,
      ),
      home: HomeShell(controller: controller),
    );
  }
}
