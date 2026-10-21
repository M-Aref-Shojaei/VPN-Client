import 'package:flutter/material.dart';

import '../controller/app_controller.dart';

class ProfilesPage extends StatelessWidget {
  const ProfilesPage({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profiles',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Import a share link or sing-box outbound. Credentials stay in secure storage.',
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showSubscriptionDialog(context),
                      icon: const Icon(Icons.sync),
                      label: const Text('Subscription'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showImportDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Import'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (controller.subscriptions.isNotEmpty) ...[
              Text(
                'Subscriptions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ...controller.subscriptions.map(
                (subscription) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: ListTile(
                      leading: const Icon(Icons.cloud_sync_outlined),
                      title: Text(subscription.name),
                      subtitle: Text(
                        '${subscription.profileIDs.length} profiles · '
                        '${subscription.updatedAt.toLocal()}',
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Refresh subscription',
                            onPressed: () async {
                              final error = await controller.updateSubscription(
                                name: subscription.name,
                                url: subscription.url.toString(),
                              );
                              if (error != null && context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(error)));
                              }
                            },
                            icon: const Icon(Icons.refresh),
                          ),
                          IconButton(
                            tooltip: 'Delete subscription',
                            onPressed: () async {
                              await controller.removeSubscription(
                                subscription.id,
                              );
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (controller.profiles.isEmpty)
              Card(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: const Padding(
                  padding: EdgeInsets.all(30),
                  child: Column(
                    children: [
                      Icon(Icons.dns_outlined, size: 48),
                      SizedBox(height: 12),
                      Text(
                        'No profiles yet',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Import a profile JSON object to enable configuration generation.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...controller.profiles.map(
                (profile) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: RadioGroup<String>(
                      groupValue: controller.activeProfileID,
                      onChanged: (value) async {
                        if (value != null) {
                          await controller.selectProfile(value);
                        }
                      },
                      child: RadioListTile<String>(
                        value: profile.id,
                        title: Text(profile.name),
                        subtitle: Text(profile.outboundType.toUpperCase()),
                        secondary: IconButton(
                          tooltip: 'Delete profile',
                          onPressed: () async {
                            await controller.removeProfile(profile.id);
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ImportProfileDialog(controller: controller),
    );
  }

  Future<void> _showSubscriptionDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SubscriptionDialog(controller: controller),
    );
  }
}

class _ImportProfileDialog extends StatefulWidget {
  const _ImportProfileDialog({required this.controller});

  final AppController controller;

  @override
  State<_ImportProfileDialog> createState() => _ImportProfileDialogState();
}

class _SubscriptionDialog extends StatefulWidget {
  const _SubscriptionDialog({required this.controller});

  final AppController controller;

  @override
  State<_SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<_SubscriptionDialog> {
  final nameController = TextEditingController();
  final urlController = TextEditingController();
  String? error;
  bool saving = false;

  @override
  void dispose() {
    nameController.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add subscription'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'HTTPS URL',
                errorText: error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  setState(() {
                    saving = true;
                    error = null;
                  });
                  final result = await widget.controller.updateSubscription(
                    name: nameController.text,
                    url: urlController.text,
                  );
                  if (!context.mounted) {
                    return;
                  }
                  if (result != null) {
                    setState(() {
                      saving = false;
                      error = result;
                    });
                    return;
                  }
                  Navigator.pop(context);
                },
          child: Text(saving ? 'Updating…' : 'Add'),
        ),
      ],
    );
  }
}

class _ImportProfileDialogState extends State<_ImportProfileDialog> {
  final textController = TextEditingController();
  String? error;
  bool saving = false;

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import profile'),
      content: SizedBox(
        width: 560,
        child: TextField(
          controller: textController,
          minLines: 10,
          maxLines: 18,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: 'vless://… or {"id":"home","outbound":{…}}',
            errorText: error,
            alignLabelWithHint: true,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  setState(() => saving = true);
                  final result = await widget.controller.importProfile(
                    textController.text,
                  );
                  if (!context.mounted) {
                    return;
                  }
                  setState(() => saving = false);
                  if (result != null) {
                    setState(() => error = result);
                    return;
                  }
                  Navigator.pop(context);
                },
          child: Text(saving ? 'Saving…' : 'Import'),
        ),
      ],
    );
  }
}
