import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'app_footer.dart';
import 'app_navigation.dart';
import 'information_content.g.dart';
import 'selectable_surface.dart';
import 'worthhit_icons.dart';
import 'worthhit_theme.dart';

/// The English source prose is generated from the public HTML documents. Only
/// structured text and checked links reach this view; HTML is never executed.
class InformationPage extends StatefulWidget {
  const InformationPage({
    super.key,
    required this.location,
    required this.opener,
  });
  final AppLocation location;
  final PageOpener opener;

  @override
  State<InformationPage> createState() => _InformationPageState();
}

class _InformationPageState extends State<InformationPage> {
  final _sections = <String, GlobalKey>{};
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _sections[widget.location.section]?.currentContext;
      if (context != null) Scrollable.ensureVisible(context);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doc =
        informationContent[widget.location.name] as Map<String, dynamic>;
    final sections = doc['sections'] as List<dynamic>;
    final label = switch (widget.location.name) {
      'terms' => 'Terms and conditions',
      'liability' => 'Liability',
      _ => 'About',
    };
    final palette = WorthhitPalette.of(context);
    return SelectionArea(
      child: Scaffold(
        key: ValueKey('information-${widget.location.name}'),
        backgroundColor: palette.paper,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: palette.ink)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    SelectableIconButton(
                      key: const ValueKey('information-back'),
                      tooltip: AppStrings.of(context).text('Back'),
                      onPressed: AppNavigation.maybeOf(context)!.back,
                      icon: const RotatedBox(
                        quarterTurns: 2,
                        child: Icon(WorthhitIcons.arrow_forward),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppText(
                        label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('information-scroll'),
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Semantics(
                        localeForSubtree: const Locale('en'),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                doc['title'] as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                doc['lead'] as String,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                doc['updated'] as String,
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 24),
                              for (final section in sections) ...[
                                TextButton(
                                  style: TextButton.styleFrom(
                                    alignment: Alignment.centerLeft,
                                  ),
                                  onPressed: () => Scrollable.ensureVisible(
                                    _sections[section['id']]!.currentContext!,
                                  ),
                                  child: Text(section['title'] as String),
                                ),
                              ],
                              const SizedBox(height: 24),
                              for (final section in sections) ...[
                                Semantics(
                                  header: true,
                                  child: Text(
                                    section['title'] as String,
                                    key: _sections.putIfAbsent(
                                      section['id'] as String,
                                      GlobalKey.new,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                for (final block
                                    in section['blocks'] as List<dynamic>)
                                  for (final (index, paragraph)
                                      in (block['paragraphs'] as List<dynamic>)
                                          .indexed)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (block['type'] != 'paragraph') ...[
                                            Text(
                                              block['type'] == 'ordered'
                                                  ? '${index + 1}.'
                                                  : '•',
                                            ),
                                            const SizedBox(width: 12),
                                          ],
                                          Expanded(
                                            child: _InformationParagraph(
                                              spans: paragraph as List<dynamic>,
                                              opener: widget.opener,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                const SizedBox(height: 20),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AppFooter(opener: widget.opener),
            ],
          ),
        ),
      ),
    );
  }
}

class _InformationParagraph extends StatelessWidget {
  const _InformationParagraph({required this.spans, required this.opener});
  final List<dynamic> spans;
  final PageOpener opener;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6);
    return Text.rich(
      TextSpan(
        children: [
          for (final span in spans)
            if (span['href'] != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: _InformationLink(
                  text: span['text'] as String,
                  destination: span['href'] as String,
                  opener: opener,
                  style: style?.copyWith(
                    fontWeight: span['strong'] == true ? FontWeight.w700 : null,
                  ),
                ),
              )
            else
              TextSpan(
                text: span['text'] as String,
                style: TextStyle(
                  fontWeight: span['strong'] == true ? FontWeight.w700 : null,
                ),
              ),
        ],
      ),
      style: style,
    );
  }
}

/// Inline navigation buttons support keyboard focus and activation while the
/// Flutter router owns navigation. Text participates in the shared SelectionArea
/// alongside the paragraph text before and after this inline widget.
class _InformationLink extends StatefulWidget {
  const _InformationLink({
    required this.text,
    required this.destination,
    required this.opener,
    required this.style,
  });
  final String text;
  final String destination;
  final PageOpener opener;
  final TextStyle? style;

  @override
  State<_InformationLink> createState() => _InformationLinkState();
}

class _InformationLinkState extends State<_InformationLink> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _activate() =>
      openInformationLink(context, widget.destination, opener: widget.opener);

  @override
  Widget build(BuildContext context) {
    final palette = WorthhitPalette.of(context);
    return Semantics(
      key: ValueKey('information-link-${widget.destination}'),
      // Native semantic anchors can navigate independently of Flutter. Keep
      // the router authoritative so an action never reloads or loses context.
      button: true,
      label: widget.text,
      focusable: true,
      focused: _focused,
      onTap: _activate,
      excludeSemantics: true,
      child: Material(
        color: _focused ? palette.soft : Colors.transparent,
        shape: Border(
          bottom: BorderSide(color: palette.ink, width: _focused ? 3 : 1),
        ),
        child: InkWell(
          onTap: _activate,
          focusNode: _focus,
          onFocusChange: (value) => setState(() => _focused = value),
          excludeFromSemantics: true,
          child: Text(widget.text, style: widget.style),
        ),
      ),
    );
  }
}
