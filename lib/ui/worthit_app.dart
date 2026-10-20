import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../domain/appraisal.dart';
import 'draft_editor.dart';
import 'result_panel.dart';
import 'settings_panel.dart';
import 'worthit_theme.dart';

class WorthitApp extends StatefulWidget {
  const WorthitApp({super.key, required this.controller});
  final AppController controller;

  @override
  State<WorthitApp> createState() => _WorthitAppState();
}

class _WorthitAppState extends State<WorthitApp> {
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Worthit — Good deals. Less guesswork.',
    debugShowCheckedModeBanner: false,
    theme: worthitTheme(),
    home: _Workspace(controller: widget.controller),
  );
}

class _Workspace extends StatefulWidget {
  const _Workspace({required this.controller});
  final AppController controller;

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
    widget.controller.appraise();
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
    backgroundColor: WorthitColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      side: BorderSide(color: WorthitColors.ink, width: 2),
    ),
    builder: (_) => SettingsPanel(controller: widget.controller),
  );

  Future<void> _clear() async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a fresh check?'),
        content: const Text(
          'This clears the current draft and report from this device. '
          'Export a report first if you want to keep it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep this check'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start fresh'),
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
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: Semantics(
                              key: const ValueKey('error-banner'),
                              liveRegion: true,
                              child: StatusNotice(
                                message: widget.controller.error!,
                                warning: true,
                              ),
                            ),
                          ),
                        if (widget.controller.persistenceError != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: Semantics(
                              liveRegion: true,
                              child: StatusNotice(
                                message: widget.controller.persistenceError!,
                                warning: true,
                              ),
                            ),
                          ),
                        if (widget.controller.updateAvailable)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: StatusNotice(
                              message:
                                  'A new version is ready. Your draft '
                                  'will stay; you’ll need to re-enter your key.',
                              action: TextButton(
                                onPressed: widget.controller.busy
                                    ? null
                                    : widget.controller.applyUpdate,
                                child: const Text('Update app'),
                              ),
                            ),
                          ),
                        if (!phone && !desktop) _tabletTabs(),
                        Expanded(
                          child: desktop
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(
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
                                          color: const Color(0xFFFFFDF7),
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

  Widget _panel(Widget child, {Color color = Colors.white}) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: WorthitColors.ink, width: 2),
      borderRadius: BorderRadius.circular(10),
    ),
    child: child,
  );

  Widget _header(bool phone, bool desktop) => Padding(
    padding: EdgeInsets.fromLTRB(
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
              const Expanded(child: WorthitBrand())
            else
              Expanded(
                child: Text(
                  'Good deals. Less guesswork.',
                  style: desktop
                      ? Theme.of(context).textTheme.headlineMedium
                      : Theme.of(context).textTheme.titleLarge,
                ),
              ),
            const SizedBox(width: 10),
            IconButton(
              key: const ValueKey('settings-button'),
              tooltip: 'Connection and model settings',
              onPressed: _settings,
              style: IconButton.styleFrom(
                side: const BorderSide(color: WorthitColors.ink, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: const Icon(Icons.tune),
            ),
            if (phone)
              PopupMenuButton<String>(
                key: const ValueKey('phone-more-menu'),
                tooltip: 'More actions',
                onSelected: (action) {
                  if (action == 'clear') _clear();
                  if (action == 'example') widget.controller.loadExample();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'clear',
                    enabled: !widget.controller.busy,
                    child: const Text('Start fresh'),
                  ),
                  PopupMenuItem(
                    value: 'example',
                    enabled: !widget.controller.busy,
                    child: const Text('Try a synthetic example'),
                  ),
                ],
              ),
          ],
        ),
        if (!phone) ...[
          const SizedBox(height: 8),
          Text(
            widget.controller.selectedModel == null
                ? 'Second-hand prices, grounded in evidence. Connect a model '
                      'to check your item.'
                : 'Second-hand prices, grounded in evidence. '
                      '${widget.controller.selectedModel!.name} connected.',
            style: const TextStyle(color: WorthitColors.muted),
          ),
        ],
      ],
    ),
  );

  Widget _rail(bool expanded) => Container(
    key: expanded ? const ValueKey('desktop-rail') : null,
    width: expanded ? 220 : 80,
    padding: EdgeInsets.symmetric(horizontal: expanded ? 20 : 12, vertical: 28),
    decoration: const BoxDecoration(
      color: WorthitColors.soft,
      border: Border(right: BorderSide(color: WorthitColors.ink, width: 2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: WorthitBrand(compact: !expanded)),
        const SizedBox(height: 38),
        if (expanded)
          FilledButton.icon(
            onPressed: _edit,
            style: FilledButton.styleFrom(
              backgroundColor: WorthitColors.ink,
              foregroundColor: WorthitColors.paper,
            ),
            icon: const Icon(Icons.sell_outlined, size: 20),
            label: const Text('Price check'),
          )
        else
          IconButton.filled(
            tooltip: 'Edit price check',
            onPressed: _edit,
            icon: const Icon(Icons.sell_outlined),
          ),
        const SizedBox(height: 12),
        if (expanded)
          TextButton.icon(
            onPressed: widget.controller.busy ? null : _clear,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Start fresh'),
          )
        else
          IconButton(
            tooltip: 'Start a fresh check',
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
            label: const Text('Try an example'),
          )
        else
          IconButton(
            tooltip: 'Try a synthetic example',
            onPressed: widget.controller.busy
                ? null
                : widget.controller.loadExample,
            icon: const Icon(Icons.play_arrow_outlined),
          ),
        const Spacer(),
        if (expanded) ...[
          const Icon(Icons.devices_outlined, size: 26),
          const SizedBox(height: 12),
          const Text(
            'Your draft stays\non this device.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, height: 1.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your API key stays in memory for this session only.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: WorthitColors.muted),
          ),
          const SizedBox(height: 22),
          OutlinedButton(
            onPressed: _settings,
            child: Text(
              widget.controller.apiKey.isEmpty
                  ? 'Connect OpenRouter'
                  : 'Connection settings',
            ),
          ),
        ] else
          const Tooltip(
            message: 'Drafts are stored on this device',
            child: Icon(Icons.devices_outlined),
          ),
      ],
    ),
  );

  Widget _tabletTabs() => Padding(
    padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
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
        backgroundColor: selected ? WorthitColors.lime : Colors.transparent,
      ),
      icon: Icon(icon, size: 20),
      label: Text(label),
    ),
  );

  Widget _phoneNavigation() => Container(
    decoration: const BoxDecoration(
      color: WorthitColors.paper,
      border: Border(top: BorderSide(color: WorthitColors.ink, width: 2)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                label: Text(
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
          backgroundColor: index == _step ? WorthitColors.soft : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(
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
