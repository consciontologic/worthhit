import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../app/preferences_controller.dart';
import '../domain/appraisal.dart';
import '../l10n/app_strings.dart';
import '../platform/document_preferences.dart';
import 'draft_editor.dart';
import 'result_panel.dart';
import 'settings_panel.dart';
import 'worthhit_theme.dart';

class WorthhitApp extends StatefulWidget {
  const WorthhitApp({super.key, required this.controller, this.preferences});
  final AppController controller;
  final PreferencesController? preferences;
  @override
  State<WorthhitApp> createState() => _WorthhitAppState();
}

class _WorthhitAppState extends State<WorthhitApp> {
  late PreferencesController _preferences;
  bool _ownsPreferences = false;
  @override
  void initState() {
    super.initState();
    _usePreferences();
  }

  void _usePreferences() {
    _ownsPreferences = widget.preferences == null;
    _preferences =
        widget.preferences ??
        PreferencesController(store: widget.controller.store);
  }

  @override
  void didUpdateWidget(covariant WorthhitApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preferences != widget.preferences ||
        (widget.preferences == null &&
            oldWidget.controller != widget.controller)) {
      if (_ownsPreferences) _preferences.dispose();
      _usePreferences();
    }
  }

  @override
  void dispose() {
    if (_ownsPreferences) _preferences.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _preferences,
    builder: (context, _) => MaterialApp(
      title: 'Worthhit — Second-hand prices, grounded in evidence',
      debugShowCheckedModeBanner: false,
      theme: worthhitTheme(),
      darkTheme: worthhitTheme(brightness: Brightness.dark),
      themeMode: _preferences.themeMode,
      locale: _preferences.locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: AppStrings.localizationsDelegates,
      localeListResolutionCallback: AppStrings.resolveLocales,
      builder: (context, child) => _DocumentPreferences(child: child!),
      home: _Workspace(
        controller: widget.controller,
        preferences: _preferences,
      ),
    ),
  );
}

/// Applies effective browser language/theme after Flutter resolves system choices.
class _DocumentPreferences extends StatefulWidget {
  const _DocumentPreferences({required this.child});
  final Widget child;
  @override
  State<_DocumentPreferences> createState() => _DocumentPreferencesState();
}

class _DocumentPreferencesState extends State<_DocumentPreferences> {
  String? _applied;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final identity = '$language:$dark';
    if (_applied != identity) {
      _applied = identity;
      updateDocumentPreferences(languageCode: language, dark: dark);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Workspace extends StatefulWidget {
  const _Workspace({required this.controller, required this.preferences});
  final AppController controller;
  final PreferencesController preferences;

  @override
  State<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<_Workspace> {
  final _editor = GlobalKey<DraftEditorState>();
  int _step = 0;
  int _tabletTab = 0;
  AppraisalResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _lastResult = widget.controller.result;
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant _Workspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _lastResult = widget.controller.result;
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(() {
      if (widget.controller.result != null &&
          !identical(_lastResult, widget.controller.result)) {
        _step = 2;
        _tabletTab = 1;
      }
      _lastResult = widget.controller.result;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _submit() {
    if (widget.controller.busy) return;
    if (_editor.currentState?.validateForSubmit() == false) {
      _edit();
      return;
    }
    setState(() {
      _step = 2;
      _tabletTab = 1;
    });
    widget.controller.appraise(
      responseLanguage: AppStrings.of(context).locale.languageCode,
    );
  }

  void _edit() => setState(() {
    _step = 0;
    _tabletTab = 0;
  });

  void _settings() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => SettingsPanel(
      controller: widget.controller,
      preferences: widget.preferences,
    ),
  );

  Future<void> _clear() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Start a fresh check?'),
        content: const AppText(
          'This clears the current draft and report from this device. '
          'Export a report first if you want to keep it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Keep this check'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Start fresh'),
          ),
        ],
      ),
    );
    if (clear == true && mounted) {
      widget.controller.clearDraft();
      _edit();
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.enter, control: true): _submit,
      const SingleActivator(LogicalKeyboardKey.enter, meta: true): _submit,
    },
    child: Focus(
      autofocus: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeType = MediaQuery.textScalerOf(context).scale(1) >= 1.8;
          final phone = constraints.maxWidth < 700 || largeType;
          final desktop = constraints.maxWidth >= 1100 && !largeType;
          final editor = DraftEditor(
            key: _editor,
            controller: widget.controller,
            compact: phone,
            step: _step,
            onSubmit: _submit,
          );
          final result = ResultPanel(
            controller: widget.controller,
            onEdit: _edit,
          );
          return Scaffold(
            key: ValueKey(
              phone
                  ? 'phone-layout'
                  : desktop
                  ? 'desktop-layout'
                  : 'tablet-layout',
            ),
            bottomNavigationBar: phone ? _phoneNavigation() : null,
            body: SafeArea(
              child: Row(
                children: [
                  if (!phone) _rail(desktop),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(phone, desktop),
                        if (widget.controller.error != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              20,
                              0,
                              20,
                              12,
                            ),
                            child: Semantics(
                              key: const ValueKey('error-banner'),
                              liveRegion: true,
                              child: StatusNotice(
                                message: widget.controller.error!,
                                warning: true,
                              ),
                            ),
                          ),
                        if (widget.controller.persistenceError != null ||
                            widget.preferences.persistenceError != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              20,
                              0,
                              20,
                              12,
                            ),
                            child: Semantics(
                              liveRegion: true,
                              child: StatusNotice(
                                message:
                                    widget.controller.persistenceError ??
                                    widget.preferences.persistenceError!,
                                warning: true,
                              ),
                            ),
                          ),
                        if (widget.controller.updateAvailable)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              20,
                              0,
                              20,
                              12,
                            ),
                            child: StatusNotice(
                              message:
                                  'A new version is ready. Your draft '
                                  'will stay; you’ll need to re-enter your key.',
                              action: TextButton(
                                onPressed: widget.controller.busy
                                    ? null
                                    : widget.controller.applyUpdate,
                                child: const AppText('Update app'),
                              ),
                            ),
                          ),
                        if (!phone && !desktop) _tabletTabs(),
                        Expanded(
                          child: desktop
                              ? Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                    28,
                                    0,
                                    28,
                                    24,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(flex: 11, child: _panel(editor)),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        flex: 10,
                                        child: _panel(
                                          result,
                                          color: WorthhitPalette.of(context)
                                              .soft,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : IndexedStack(
                                  index: phone
                                      ? (_step == 2 ? 1 : 0)
                                      : _tabletTab,
                                  children: [editor, result],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _panel(Widget child, {Color? color}) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: color ?? WorthhitPalette.of(context).surface,
      border: Border.all(color: WorthhitPalette.of(context).ink, width: 2),
      borderRadius: BorderRadius.zero,
    ),
    child: child,
  );

  Widget _header(bool phone, bool desktop) => Padding(
    padding: EdgeInsetsDirectional.fromSTEB(
      phone ? 20 : 28,
      phone ? 16 : 28,
      phone ? 14 : 28,
      phone ? 14 : 24,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (phone)
              const Expanded(child: WorthhitBrand())
            else
              Expanded(
                child: AppText(
                  'Know what it’s worth.',
                  style: desktop
                      ? Theme.of(context).textTheme.headlineMedium
                      : Theme.of(context).textTheme.titleLarge,
                ),
              ),
            const SizedBox(width: 10),
            IconButton(
              key: const ValueKey('settings-button'),
              tooltip: AppStrings.of(context).text('Settings'),
              onPressed: _settings,
              style: IconButton.styleFrom(
                side: BorderSide(
                  color: WorthhitPalette.of(context).ink,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              icon: const Icon(Icons.tune),
            ),
            if (phone)
              PopupMenuButton<String>(
                key: const ValueKey('phone-more-menu'),
                tooltip: AppStrings.of(context).text('More actions'),
                onSelected: (action) {
                  if (action == 'clear') _clear();
                  if (action == 'example') widget.controller.loadExample();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'clear',
                    enabled: !widget.controller.busy,
                    child: const AppText('Start fresh'),
                  ),
                  PopupMenuItem(
                    value: 'example',
                    enabled: !widget.controller.busy,
                    child: const AppText('Try a synthetic example'),
                  ),
                ],
              ),
          ],
        ),
        if (!phone) ...[
          const SizedBox(height: 8),
          AppText(
            widget.controller.selectedModel == null
                ? 'Second-hand prices, grounded in evidence. Connect a model '
                      'to check your item.'
                : 'Second-hand prices, grounded in evidence.',
            style: TextStyle(color: WorthhitPalette.of(context).muted),
          ),
        ],
      ],
    ),
  );

  Widget _rail(bool expanded) => Container(
    key: expanded ? const ValueKey('desktop-rail') : null,
    width: expanded ? 208 : 80,
    padding: EdgeInsets.symmetric(horizontal: expanded ? 20 : 12, vertical: 28),
    decoration: BoxDecoration(
      color: WorthhitPalette.of(context).paper,
      border: BorderDirectional(
        end: BorderSide(color: WorthhitPalette.of(context).ink, width: 2),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: WorthhitBrand(compact: !expanded)),
        const SizedBox(height: 38),
        if (expanded)
          FilledButton.icon(
            onPressed: _edit,
            style: FilledButton.styleFrom(
              backgroundColor: WorthhitPalette.of(context).ink,
              foregroundColor: WorthhitPalette.of(context).paper,
            ),
            icon: const Icon(Icons.sell_outlined, size: 20),
            label: const AppText('Price check'),
          )
        else
          IconButton.filled(
            tooltip: AppStrings.of(context).text('Edit price check'),
            onPressed: _edit,
            icon: const Icon(Icons.sell_outlined),
          ),
        const SizedBox(height: 12),
        if (expanded)
          TextButton.icon(
            onPressed: widget.controller.busy ? null : _clear,
            icon: const Icon(Icons.add, size: 20),
            label: const AppText('Start fresh'),
          )
        else
          IconButton(
            tooltip: AppStrings.of(context).text('Start a fresh check'),
            onPressed: widget.controller.busy ? null : _clear,
            icon: const Icon(Icons.add),
          ),
        const SizedBox(height: 8),
        if (expanded)
          TextButton.icon(
            onPressed: widget.controller.busy
                ? null
                : widget.controller.loadExample,
            icon: const Icon(Icons.play_arrow_outlined, size: 20),
            label: const AppText('Try an example'),
          )
        else
          IconButton(
            tooltip: AppStrings.of(context).text('Try a synthetic example'),
            onPressed: widget.controller.busy
                ? null
                : widget.controller.loadExample,
            icon: const Icon(Icons.play_arrow_outlined),
          ),
        const Spacer(),
        if (expanded) ...[
          const Icon(Icons.devices_outlined, size: 26),
          const SizedBox(height: 12),
          const AppText(
            'Your draft stays\non this device.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, height: 1.5),
          ),
          const SizedBox(height: 8),
          AppText(
            'Your API key stays in memory for this session only.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: WorthhitPalette.of(context).muted,
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton(
            onPressed: _settings,
            child: AppText(
              widget.controller.apiKey.isEmpty
                  ? 'Connect OpenRouter'
                  : 'Connection settings',
            ),
          ),
        ] else
          Tooltip(
            message: AppStrings.of(context)
                .text('Drafts are stored on this device'),
            child: const Icon(Icons.devices_outlined),
          ),
      ],
    ),
  );

  Widget _tabletTabs() => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(28, 0, 28, 8),
    child: Row(
      children: [
        Expanded(
          child: _tab(
            'tablet-editor-tab',
            'Edit item',
            Icons.edit_outlined,
            _tabletTab == 0,
            () => setState(() => _tabletTab = 0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _tab(
            'tablet-estimate-tab',
            'Price picture',
            Icons.receipt_long_outlined,
            _tabletTab == 1,
            () => setState(() => _tabletTab = 1),
          ),
        ),
      ],
    ),
  );

  Widget _tab(
    String key,
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) => Semantics(
    selected: selected,
    child: OutlinedButton.icon(
      key: ValueKey(key),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? WorthhitPalette.of(context).lime
            : Colors.transparent,
        foregroundColor: selected
            ? WorthhitPalette.of(context).onLime
            : WorthhitPalette.of(context).ink,
      ),
      icon: Icon(icon, size: 20),
      label: AppText(label),
    ),
  );

  Widget _phoneNavigation() => Container(
    decoration: BoxDecoration(
      color: WorthhitPalette.of(context).paper,
      border: Border(
        top: BorderSide(color: WorthhitPalette.of(context).ink, width: 2),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: ValueKey(_step == 0 ? 'next-step' : 'submit-check'),
                onPressed: widget.controller.busy
                    ? widget.controller.cancel
                    : _step == 0
                    ? () => setState(() => _step = 1)
                    : _submit,
                icon: Icon(
                  widget.controller.busy ? Icons.close : Icons.arrow_forward,
                  size: 20,
                ),
                label: AppText(
                  widget.controller.busy
                      ? 'Cancel price check'
                      : _step == 0
                      ? 'Continue to evidence'
                      : widget.controller.result == null
                      ? 'Find a fair price'
                      : 'Check again',
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _phoneTab(0, 'Details', Icons.edit_outlined),
                _phoneTab(1, 'Evidence', Icons.search),
                _phoneTab(2, 'Estimate', Icons.receipt_long_outlined),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _phoneTab(int index, String title, IconData icon) => Expanded(
    child: Semantics(
      selected: index == _step,
      child: TextButton(
        key: ValueKey('phone-${title.toLowerCase()}-tab'),
        onPressed: () => setState(() => _step = index),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          backgroundColor: index == _step
              ? WorthhitPalette.of(context).soft
              : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            AppText(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: index == _step ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
