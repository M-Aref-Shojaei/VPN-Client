import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/services/profile_store.dart';
import 'src/services/tunnel_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    AdaptiveVpnApp(
      tunnelService: createTunnelService(),
      profileStore: const SecureProfileStore(),
    ),
  );
}
