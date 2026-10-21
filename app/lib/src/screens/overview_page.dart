import 'package:flutter/material.dart';

import '../controller/app_controller.dart';
import '../services/tunnel_service.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final status = controller.status;
        final connected = status == TunnelStatus.connected;
        final busy =
            status == TunnelStatus.connecting ||
            status == TunnelStatus.disconnecting;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Connection',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Only blocked destinations use the encrypted tunnel.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                      ),
                      child: busy
                          ? const Padding(
                              padding: EdgeInsets.all(38),
                              child: CircularProgressIndicator(),
                            )
                          : Icon(
                              connected ? Icons.shield : Icons.shield_outlined,
                              size: 52,
                            ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _statusLabel(status),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.activeProfile?.name ?? 'No profile selected',
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: busy
                          ? null
                          : connected
                          ? controller.disconnect
                          : controller.canConnect
                          ? controller.connect
                          : null,
                      icon: Icon(
                        connected ? Icons.stop : Icons.power_settings_new,
                      ),
                      label: Text(connected ? 'Disconnect' : 'Connect'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _InformationCard(
              icon: controller.capability.available
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              title: controller.capability.available
                  ? 'Tunnel adapter ready'
                  : 'Configuration build',
              message: controller.capability.message,
            ),
            if (controller.lastError != null) ...[
              const SizedBox(height: 12),
              _InformationCard(
                icon: Icons.error_outline,
                title: 'Connection error',
                message: controller.lastError!,
                error: true,
              ),
            ],
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Default path',
                    value: 'Direct',
                    icon: Icons.public,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _Metric(
                    label: 'Learning',
                    value: 'Network-aware',
                    icon: Icons.psychology_outlined,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

String _statusLabel(TunnelStatus status) {
  return switch (status) {
    TunnelStatus.disconnected => 'Disconnected',
    TunnelStatus.connecting => 'Connecting…',
    TunnelStatus.connected => 'Protected',
    TunnelStatus.disconnecting => 'Disconnecting…',
  };
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.title,
    required this.message,
    this.error = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: error
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surfaceContainer,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(message),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 18),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
