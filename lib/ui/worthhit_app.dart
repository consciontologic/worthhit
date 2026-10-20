import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../app/preferences_controller.dart';
import '../domain/appraisal.dart';
import '../l10n/app_strings.dart';
import '../platform/document_preferences.dart';
import '../platform/browser_history.dart';
import 'app_footer.dart';
import 'app_navigation.dart';
import 'information_page.dart';
import 'draft_editor.dart';
import 'result_panel.dart';
import 'settings_panel.dart';
import 'selectable_surface.dart';
import 'update_notice.dart';
import 'worthhit_icons.dart';
import 'worthhit_theme.dart';

class WorthhitApp extends StatefulWidget {
  const WorthhitApp({
    super.key,
    required this.controller,
    this.preferences,
    this.opener = openPage,
    this.routeInformationProvider,
    this.browserBack = goBackInBrowser,
  });
  final AppController controller;
  final PreferencesController? preferences;
  final PageOpener opener;
  final RouteInformationProvider? routeInformationProvider;
  final bool Function() browserBack;
  @override
  State<WorthhitApp> createState() => _WorthhitAppState();
}

class _WorthhitAppState extends State<WorthhitApp> {
  late PreferencesController _preferences;
  bool _ownsPreferences = false;
  late final WorthhitRouter _router;
  @override
  void initState() {
    super.initState();
    _usePreferences();
    _router = WorthhitRouter(
      browserBack: widget.browserBack,
      workspaceBuilder: (_) => SelectionArea(
        child: _Workspace(
          controller: widget.controller,
          preferences: _preferences,
          opener: widget.opener,
        ),
      ),
      settingsBuilder: (context) => SelectionArea(
        child: Scaffold(
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: BottomSheet(
                  enableDrag: false,
                  backgroundColor: Theme.of(context)
                      .bottomSheetTheme
                      .backgroundColor,
                  onClosing: AppNavigation.maybeOf(context)!.back,
                  builder: (_) => SettingsPanel(
                    controller: widget.controller,
                    preferences: _preferences,
                    opener: widget.opener,
                    onClose: AppNavigation.maybeOf(context)!.back,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      informationBuilder: (_, location) =>
          InformationPage(location: location, opener: widget.opener),
    );
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
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _preferences,
    builder: (context, _) => MaterialApp.router(
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
      routeInformationProvider: widget.routeInformationProvider,
      routerDelegate: _router,
      routeInformationParser: const AppRouteParser(),
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
  const _Workspace({
    required this.controller,
    required this.preferences,
    required this.opener,
  });
  final AppController controller;
  final PreferencesController preferences;
  final PageOpener opener;

  @override
  State<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<_Workspace> {
  final _editor = GlobalKey<DraftEditorState>();
  final _scaffold = GlobalKey<ScaffoldState>();
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

  void _settings() =>
      AppNavigation.maybeOf(context)!.open(const AppLocation('settings'));

  Future<void> _clear() async {
    final clear = await showSelectableDialog<bool>(
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
          final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
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
          return KeyedSubtree(
            key: ValueKey(
              phone
                  ? 'phone-layout'
                  : desktop
                  ? 'desktop-layout'
                  : 'tablet-layout',
            ),
            child: Scaffold(
              key: _scaffold,
              drawer: desktop ? null : _drawer(),
              bottomNavigationBar: phone
                  ? _phoneNavigation()
                  : desktop && !keyboardVisible
                  ? SafeArea(
                      top: false,
                      child: AppFooter(
                        key: const ValueKey('app-footer'),
                        opener: widget.opener,
                      ),
                    )
                  : null,
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
                          UpdateNotice(controller: widget.controller),
                          if (!phone && !desktop) _tabletTabs(),
                          Expanded(
                            child: desktop
                                ? Padding(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                          28,
                                          0,
                                          28,
                                          24,
                                        ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          flex: 11,
                                          child: _panel(editor),
                                        ),
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
      phone ? 12 : 24,
      phone ? 6 : 16,
      phone ? 12 : 24,
      phone ? 6 : 12,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!desktop) ...[
              SelectableIconButton(
                key: const ValueKey('navigation-menu'),
                tooltip: AppStrings.of(context).text('Open navigation'),
                onPressed: () => _scaffold.currentState?.openDrawer(),
                icon: const Icon(WorthhitIcons.menu),
              ),
              const SizedBox(width: 6),
            ],
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
            SelectableIconButton(
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
              icon: const Icon(WorthhitIcons.tune),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _drawer() => Drawer(
    width: (MediaQuery.sizeOf(context).width - 24).clamp(240.0, 360.0),
    backgroundColor: WorthhitPalette.of(context).paper,
    shape: const RoundedRectangleBorder(),
    child: SelectionArea(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            key: const ValueKey('navigation-scroll'),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Expanded(child: WorthhitBrand()),
                            SelectableIconButton(
                              tooltip: AppStrings.of(context)
                                  .text('Close navigation'),
                              onPressed: () =>
                                  _scaffold.currentState?.closeDrawer(),
                              icon: const Icon(WorthhitIcons.close),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      for (final action in [
                        (
                          'Price check',
                          WorthhitIcons.sell_outlined,
                          _edit,
                          true,
                        ),
                        (
                          'Start fresh',
                          WorthhitIcons.add,
                          _clear,
                          !widget.controller.busy,
                        ),
                        (
                          'Try an example',
                          WorthhitIcons.play_arrow_outlined,
                          widget.controller.loadExample,
                          !widget.controller.busy,
                        ),
                        ('Settings', WorthhitIcons.tune, _settings, true),
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextButton.icon(
                            onPressed: !action.$4
                                ? null
                                : () {
                                    _scaffold.currentState?.closeDrawer();
                                    action.$3();
                                  },
                            style: TextButton.styleFrom(
                              alignment: AlignmentDirectional.centerStart,
                              minimumSize: const Size(44, 48),
                            ),
                            icon: Icon(action.$2),
                            label: AppText(action.$1),
                          ),
                        ),
                      const SizedBox(height: 32),
                    ],
                  ),
                  AppFooter(
                    key: const ValueKey('sidebar-app-footer'),
                    inDrawer: true,
                    opener: widget.opener,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _rail(bool expanded) => Container(
    key: expanded ? const ValueKey('desktop-rail') : null,
    width: expanded ? 196 : 64,
    padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 8, vertical: 20),
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
        const SizedBox(height: 28),
        if (expanded)
          FilledButton.icon(
            onPressed: _edit,
            style: FilledButton.styleFrom(
              backgroundColor: WorthhitPalette.of(context).ink,
              foregroundColor: WorthhitPalette.of(context).paper,
            ),
            icon: const Icon(WorthhitIcons.sell_outlined, size: 20),
            label: const AppText('Price check'),
          )
        else
          MergeSemantics(
            child: SelectableTooltip(
              message: AppStrings.of(context).text('Edit price check'),
              child: IconButton.filled(
                onPressed: _edit,
                icon: const Icon(WorthhitIcons.sell_outlined),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (expanded)
          TextButton.icon(
            onPressed: widget.controller.busy ? null : _clear,
            icon: const Icon(WorthhitIcons.add, size: 20),
            label: const AppText('Start fresh'),
          )
        else
          SelectableIconButton(
            tooltip: AppStrings.of(context).text('Start a fresh check'),
            onPressed: widget.controller.busy ? null : _clear,
            icon: const Icon(WorthhitIcons.add),
          ),
        const SizedBox(height: 8),
        if (expanded)
          TextButton.icon(
            onPressed: widget.controller.busy
                ? null
                : widget.controller.loadExample,
            icon: const Icon(WorthhitIcons.play_arrow_outlined, size: 20),
            label: const AppText('Try an example'),
          )
        else
          SelectableIconButton(
            tooltip: AppStrings.of(context).text('Try a synthetic example'),
            onPressed: widget.controller.busy
                ? null
                : widget.controller.loadExample,
            icon: const Icon(WorthhitIcons.play_arrow_outlined),
          ),
        const Spacer(),
        if (expanded) ...[
          const Icon(WorthhitIcons.devices_outlined, size: 26),
          const SizedBox(height: 12),
          const AppText(
            'Your draft stays\non this device.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, height: 1.5),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _settings,
            child: AppText(
              widget.controller.apiKey.isEmpty
                  ? 'Connect OpenRouter'
                  : 'Connection settings',
            ),
          ),
        ] else
          SelectableTooltip(
            message: AppStrings.of(context)
                .text('Drafts are stored on this device'),
            child: const Icon(WorthhitIcons.devices_outlined),
          ),
      ],
    ),
  );

  Widget _tabletTabs() => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
    child: Row(
      children: [
        Expanded(
          child: _tab(
            'tablet-editor-tab',
            'Edit item',
            WorthhitIcons.edit_outlined,
            _tabletTab == 0,
            () => setState(() => _tabletTab = 0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _tab(
            'tablet-estimate-tab',
            'Price picture',
            WorthhitIcons.receipt_long_outlined,
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
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
        backgroundColor: selected
            ? WorthhitPalette.of(context).lime
            : Colors.transparent,
        foregroundColor: selected
            ? WorthhitPalette.of(context).onLime
            : WorthhitPalette.of(context).ink,
      ),
      icon: Icon(icon, size: 18),
      label: AppText(label),
    ),
  );

  Widget _phoneNavigation() => Container(
    key: const ValueKey('phone-navigation'),
    decoration: BoxDecoration(
      color: WorthhitPalette.of(context).paper,
      border: Border(
        top: BorderSide(color: WorthhitPalette.of(context).ink, width: 2),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: SelectableTooltip(
                message: AppStrings.of(context).text(
                  widget.controller.busy
                      ? 'Cancel price check'
                      : _step == 0
                      ? 'Continue to evidence'
                      : widget.controller.result == null
                      ? 'Find a fair price'
                      : 'Check again',
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  key: ValueKey(_step == 0 ? 'next-step' : 'submit-check'),
                  onPressed: widget.controller.busy
                      ? widget.controller.cancel
                      : _step == 0
                      ? () => setState(() => _step = 1)
                      : _submit,
                  icon: Icon(
                    widget.controller.busy
                        ? WorthhitIcons.close
                        : WorthhitIcons.arrow_forward,
                    size: 18,
                  ),
                  label: AppText(
                    widget.controller.busy
                        ? 'Cancel'
                        : _step == 0
                        ? 'Continue'
                        : widget.controller.result == null
                        ? 'Estimate'
                        : 'Check again',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _phoneTab(0, 'Details', WorthhitIcons.edit_outlined),
                _phoneTab(1, 'Evidence', WorthhitIcons.search),
                _phoneTab(2, 'Estimate', WorthhitIcons.receipt_long_outlined),
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
          minimumSize: const Size(44, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          backgroundColor: index == _step
              ? WorthhitPalette.of(context).soft
              : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 2),
            AppText(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.1,
                fontWeight: index == _step ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
