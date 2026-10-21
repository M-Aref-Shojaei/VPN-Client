import 'package:flutter/material.dart';

import '../controller/app_controller.dart';
import '../models/routing.dart';

class RoutingPage extends StatefulWidget {
  const RoutingPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<RoutingPage> createState() => _RoutingPageState();
}

class _RoutingPageState extends State<RoutingPage> {
  final domainController = TextEditingController();
  RouteDecision decision = const RouteDecision(
    RouteTarget.direct,
    RouteReason.defaultDirect,
  );

  @override
  void dispose() {
    domainController.dispose();
    super.dispose();
  }

  void inspect(String value) {
    setState(() => decision = widget.controller.policy.decide(value));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Smart routing',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Inspect a domain, then pin it to direct or proxy. Subdomains inherit the rule.',
            ),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: ListTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: const Text('Signed blocked-domain rules'),
                subtitle: Text(
                  widget.controller.ruleSet == null
                      ? 'No trusted rule source configured.'
                      : 'Version ${widget.controller.ruleSet!.version} · '
                            '${widget.controller.policy.knownBlocked.length} domains',
                ),
                trailing: Wrap(
                  children: [
                    if (widget.controller.ruleSet != null)
                      IconButton(
                        tooltip: 'Update verified rules',
                        onPressed: () async {
                          final source = widget.controller.ruleSet!;
                          final error = await widget.controller.updateRuleSet(
                            manifestURL: source.manifestURL.toString(),
                            publicKey: source.publicKey,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  error ?? 'Signed rules updated and verified.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh),
                      ),
                    IconButton(
                      tooltip: 'Configure signed rules',
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            _RuleSetDialog(controller: widget.controller),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: domainController,
                      onChanged: inspect,
                      decoration: const InputDecoration(
                        labelText: 'Domain or URL',
                        hintText: 'example.com',
                        prefixIcon: Icon(Icons.travel_explore),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          avatar: Icon(
                            decision.target == RouteTarget.direct
                                ? Icons.public
                                : Icons.lock_outline,
                            size: 18,
                          ),
                          label: Text(
                            decision.target == RouteTarget.direct
                                ? 'Direct'
                                : 'Proxy',
                          ),
                        ),
                        Text(_reasonLabel(decision.reason)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _addRule(RouteTarget.direct),
                          icon: const Icon(Icons.add),
                          label: const Text('Always direct'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _addRule(RouteTarget.proxy),
                          icon: const Icon(Icons.add),
                          label: const Text('Always proxy'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final message = await widget.controller.probeDomain(
                              domainController.text,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));
                              inspect(domainController.text);
                            }
                          },
                          icon: const Icon(Icons.network_check),
                          label: const Text('Test direct/proxy'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _RuleSection(
              title: 'Always direct',
              icon: Icons.public,
              emptyMessage: 'No direct overrides.',
              rules: widget.controller.policy.manualDirect,
              onDelete: (rule) async {
                await widget.controller.removeRule(RouteTarget.direct, rule);
                inspect(domainController.text);
              },
            ),
            const SizedBox(height: 16),
            _RuleSection(
              title: 'Always proxy',
              icon: Icons.lock_outline,
              emptyMessage: 'No proxy overrides.',
              rules: widget.controller.policy.manualProxy,
              onDelete: (rule) async {
                await widget.controller.removeRule(RouteTarget.proxy, rule);
                inspect(domainController.text);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _addRule(RouteTarget target) async {
    final added = await widget.controller.addRule(
      target,
      domainController.text,
    );
    if (!added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a new valid domain first.')),
      );
    }
    inspect(domainController.text);
  }
}

class _RuleSetDialog extends StatefulWidget {
  const _RuleSetDialog({required this.controller});

  final AppController controller;

  @override
  State<_RuleSetDialog> createState() => _RuleSetDialogState();
}

class _RuleSetDialogState extends State<_RuleSetDialog> {
  late final TextEditingController manifestController;
  late final TextEditingController keyController;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    manifestController = TextEditingController(
      text: widget.controller.ruleSet?.manifestURL.toString(),
    );
    keyController = TextEditingController(
      text: widget.controller.ruleSet?.publicKey,
    );
  }

  @override
  void dispose() {
    manifestController.dispose();
    keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Trusted rule source'),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: manifestController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'HTTPS manifest URL',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyController,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Ed25519 public key (base64)',
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
                  final result = await widget.controller.updateRuleSet(
                    manifestURL: manifestController.text,
                    publicKey: keyController.text,
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
          child: Text(saving ? 'Verifying…' : 'Verify and save'),
        ),
      ],
    );
  }
}

String _reasonLabel(RouteReason reason) {
  return switch (reason) {
    RouteReason.manualDirect => 'Manual direct override',
    RouteReason.manualProxy => 'Manual proxy override',
    RouteReason.privateDestination => 'Private or local destination',
    RouteReason.knownBlocked => 'Known blocked-domain rule',
    RouteReason.learnedBlocked => 'Learned on this network',
    RouteReason.defaultDirect => 'Unknown domains default to direct',
  };
}

class _RuleSection extends StatelessWidget {
  const _RuleSection({
    required this.title,
    required this.icon,
    required this.emptyMessage,
    required this.rules,
    required this.onDelete,
  });

  final String title;
  final IconData icon;
  final String emptyMessage;
  final List<String> rules;
  final Future<void> Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (rules.isEmpty)
              Text(emptyMessage)
            else
              ...rules.map(
                (rule) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(rule),
                  trailing: IconButton(
                    tooltip: 'Remove rule',
                    onPressed: () async => onDelete(rule),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
