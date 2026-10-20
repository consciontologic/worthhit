import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/preferences_controller.dart';
import '../l10n/app_strings.dart';
import '../platform/document_preferences.dart';
import 'app_footer.dart';
import 'worthhit_theme.dart';
import 'selectable_surface.dart';
import 'worthhit_icons.dart';
import 'update_notice.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.controller,
    required this.preferences,
    this.opener = openPage,
  });
  final AppController controller;
  final PreferencesController preferences;
  final PageOpener opener;

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
            20,
            16,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
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
                  SelectableIconButton(
                    tooltip: AppStrings.of(context).text('Close settings'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(WorthhitIcons.close),
                  ),
                ],
              ),
              UpdateNotice(controller: controller, dismissible: false),
              const SizedBox(height: 16),
              DropdownButtonFormField<ThemeMode>(
                key: const ValueKey('theme-selector'),
                initialValue: widget.preferences.themeMode,
                isExpanded: true,
                icon: const Icon(WorthhitIcons.expand_more, size: 18),
                decoration: InputDecoration(
                  labelText: AppStrings.of(context).text('Appearance'),
                  prefixIcon: const Icon(
                    WorthhitIcons.dark_mode_outlined,
                    size: 18,
                  ),
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
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const ValueKey('language-selector'),
                initialValue:
                    widget.preferences.locale?.languageCode ?? 'system',
                isExpanded: true,
                icon: const Icon(WorthhitIcons.expand_more, size: 18),
                decoration: InputDecoration(
                  labelText: AppStrings.of(context).text('Language'),
                  prefixIcon: const Icon(WorthhitIcons.language, size: 18),
                  suffixIcon: const ContextHelp(
                    title: 'Language',
                    child: AppText(
                      'Language follows your browser unless you choose one. No location lookup is needed.',
                    ),
                  ),
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

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(WorthhitIcons.hub_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppText(
                      'Your connection',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const ContextHelp(
                    title: 'Connection help',
                    child: AppText(
                      'Worthhit talks directly to OpenRouter from your browser. '
                      'Add your own key and choose a free model.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                  suffixIcon: SelectableIconButton(
                    tooltip: AppStrings.of(context)
                        .text(_visible ? 'Hide API key' : 'Show API key'),
                    onPressed: () => setState(() => _visible = !_visible),
                    icon: Icon(
                      _visible
                          ? WorthhitIcons.visibility_off_outlined
                          : WorthhitIcons.visibility_outlined,
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
                icon: const Icon(WorthhitIcons.delete_outline, size: 18),
                label: const AppText('Clear key'),
              ),
              const SizedBox(height: 16),
              AppText(
                'Choose a model',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('model-${controller.selectedModel?.id}'),
                initialValue: controller.selectedModel?.id,
                isExpanded: true,
                icon: const Icon(WorthhitIcons.expand_more, size: 18),
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
                    icon: const Icon(WorthhitIcons.refresh, size: 20),
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
                    icon: const Icon(WorthhitIcons.hub_outlined, size: 20),
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
                onPressed: () => openInformationLink(
                  context,
                  'about/',
                  opener: widget.opener,
                ),
                icon: const Icon(WorthhitIcons.info_outline),
                label: const AppText('About Worthhit'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(WorthhitIcons.check, size: 18),
                  label: const AppText('Done'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
