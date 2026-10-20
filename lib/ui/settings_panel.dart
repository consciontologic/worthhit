import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/preferences_controller.dart';
import '../l10n/app_strings.dart';
import '../platform/document_preferences.dart';
import 'worthhit_theme.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.controller,
    required this.preferences,
  });
  final AppController controller;
  final PreferencesController preferences;

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
    listenable: Listenable.merge([widget.controller, widget.preferences]),
    builder: (context, _) {
      final controller = widget.controller;
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
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
                    child: AppText(
                      'Settings',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.of(context).text('Close settings'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<ThemeMode>(
                key: const ValueKey('theme-selector'),
                initialValue: widget.preferences.themeMode,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: AppStrings.of(context).text('Appearance'),
                ),
                items: [
                  for (final value in ThemeMode.values)
                    DropdownMenuItem(
                      value: value,
                      child: AppText(switch (value) {
                        ThemeMode.system => 'System',
                        ThemeMode.light => 'Light',
                        ThemeMode.dark => 'Dark',
                      }),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) widget.preferences.setThemeMode(value);
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                key: const ValueKey('language-selector'),
                initialValue:
                    widget.preferences.locale?.languageCode ?? 'system',
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: AppStrings.of(context).text('Language'),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'system',
                    child: AppText('Use browser language'),
                  ),
                  for (final locale in AppStrings.supportedLocales)
                    DropdownMenuItem(
                      value: locale.languageCode,
                      child: Text(
                        AppStrings.languageNames[locale.languageCode] ??
                            locale.languageCode,
                      ),
                    ),
                ],
                onChanged: (value) => widget.preferences.setLocale(
                  value == null || value == 'system' ? null : Locale(value),
                ),
              ),
              const SizedBox(height: 12),
              AppText(
                'Language follows your browser unless you choose one. No location lookup is needed.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),
              AppText(
                'Your connection',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const AppText(
                'Worthhit talks directly to OpenRouter from your browser. '
                'Add your own key and choose a free model.',
              ),
              const SizedBox(height: 24),
              AppText(
                'OpenRouter API key',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('api-key-field'),
                controller: _key,
                obscureText: !_visible,
                textDirection: TextDirection.ltr,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: controller.setApiKey,
                decoration: InputDecoration(
                  hintText: AppStrings.of(context).text('Paste your key'),
                  suffixIcon: IconButton(
                    tooltip: AppStrings.of(context)
                        .text(_visible ? 'Hide API key' : 'Show API key'),
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
              AppText(
                'Kept only in memory for this session. Reloading clears it. '
                'Your item and evidence are sent to OpenRouter and its selected '
                'provider when you request a check.',
                style: TextStyle(
                  fontSize: 12,
                  color: WorthhitPalette.of(context).muted,
                ),
              ),
              TextButton.icon(
                onPressed: controller.apiKey.isEmpty
                    ? null
                    : () {
                        _key.clear();
                        controller.setApiKey('');
                      },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const AppText('Clear key'),
              ),
              const SizedBox(height: 20),
              AppText(
                'Choose a model',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('model-${controller.selectedModel?.id}'),
                initialValue: controller.selectedModel?.id,
                isExpanded: true,
                hint: const AppText('Select a free model'),
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
              AppText(
                'Only models with confirmed zero model-token prices appear. '
                'Availability can change; paid web search is a separate opt-in.',
                style: TextStyle(
                  fontSize: 12,
                  color: WorthhitPalette.of(context).muted,
                ),
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
                    label: AppText(
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
                    label: const AppText('Check endpoints'),
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
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: openAboutPage,
                icon: const Icon(Icons.info_outline),
                label: const AppText('About Worthhit'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const AppText('Back to the price check'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
