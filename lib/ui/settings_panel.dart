import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import 'worthit_theme.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, required this.controller});
  final AppController controller;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late final _key = TextEditingController(text: widget.controller.apiKey);
  bool _visible = false;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Your connection',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close connection settings',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Worthit talks directly to OpenRouter from your browser. '
                'Add your own key and choose a free model.',
              ),
              const SizedBox(height: 24),
              Text(
                'OpenRouter API key',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('api-key-field'),
                controller: _key,
                obscureText: !_visible,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: controller.setApiKey,
                decoration: InputDecoration(
                  hintText: 'Paste your key',
                  suffixIcon: IconButton(
                    tooltip: _visible ? 'Hide API key' : 'Show API key',
                    onPressed: () => setState(() => _visible = !_visible),
                    icon: Icon(
                      _visible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Kept only in memory for this session. Reloading clears it. '
                'Your item and evidence are sent to OpenRouter and its selected '
                'provider when you request a check.',
                style: TextStyle(fontSize: 12, color: WorthitColors.muted),
              ),
              TextButton.icon(
                onPressed: controller.apiKey.isEmpty
                    ? null
                    : () {
                        _key.clear();
                        controller.setApiKey('');
                      },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Clear key'),
              ),
              const SizedBox(height: 20),
              Text(
                'Choose a model',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('model-${controller.selectedModel?.id}'),
                initialValue: controller.selectedModel?.id,
                isExpanded: true,
                hint: const Text('Select a free model'),
                items: [
                  for (final model in controller.models)
                    DropdownMenuItem(
                      value: model.id,
                      child: Text(model.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: controller.busy
                    ? null
                    : (id) {
                        for (final model in controller.models) {
                          if (model.id == id) {
                            controller.selectModel(model);
                            break;
                          }
                        }
                      },
              ),
              const SizedBox(height: 10),
              const Text(
                'Only models with confirmed zero model-token prices appear. '
                'Availability can change; paid web search is a separate opt-in.',
                style: TextStyle(fontSize: 12, color: WorthitColors.muted),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.catalogLoading || controller.busy
                        ? null
                        : controller.refreshModels,
                    icon: const Icon(Icons.refresh, size: 20),
                    label: Text(
                      controller.catalogLoading
                          ? 'Refreshing…'
                          : 'Refresh models',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        controller.selectedModel == null ||
                            controller.catalogLoading ||
                            controller.busy
                        ? null
                        : controller.inspectSelected,
                    icon: const Icon(Icons.hub_outlined, size: 20),
                    label: const Text('Check endpoints'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Semantics(
                liveRegion: true,
                child: StatusNotice(
                  message: controller.error ?? controller.statusText,
                  warning: controller.error != null,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to the price check'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
