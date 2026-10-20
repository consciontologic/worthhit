import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_identity.dart';
import '../l10n/app_strings.dart';
import '../platform/document_preferences.dart';
import 'selectable_surface.dart';
import 'app_navigation.dart';
import 'worthhit_icons.dart';
import 'worthhit_theme.dart';

typedef PageOpener = bool Function(Uri uri);

/// Internal information routes retain the active Flutter session. External links
/// dispatch synchronously so browser popup protection retains user activation.
void openInformationLink(
  BuildContext context,
  String destination, {
  PageOpener opener = openPage,
}) {
  final route = AppLocation.parse(Uri.parse(destination));
  final navigation = AppNavigation.maybeOf(context);
  if (route != null &&
      route.name != '' &&
      route.name != 'settings' &&
      navigation != null) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen == true) scaffold!.closeDrawer();
    navigation.open(route);
    return;
  }
  final uri = resolvePage(destination);
  try {
    if (opener(uri)) return;
  } catch (_) {
    // The fallback must also work when a platform denies access to window.open.
  }
  showSelectableDialog<void>(
    context: context,
    builder: (context) => _LinkFallback(uri: uri),
  );
}

class _LinkFallback extends StatefulWidget {
  const _LinkFallback({required this.uri});
  final Uri uri;

  @override
  State<_LinkFallback> createState() => _LinkFallbackState();
}

class _LinkFallbackState extends State<_LinkFallback> {
  bool _copyFailed = false;

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: '${widget.uri}'));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _copyFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const AppText('Could not open this link'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText(
            'Your check is still here. Copy this address and open it in a new tab.',
          ),
          const SizedBox(height: 16),
          SelectableText('${widget.uri}', textDirection: TextDirection.ltr),
          if (_copyFailed) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: const AppText(
                'Copy failed. Select and copy the address above.',
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const AppText('Close'),
      ),
      FilledButton.icon(
        onPressed: _copy,
        icon: const Icon(WorthhitIcons.content_copy, size: 18),
        label: const AppText('Copy link'),
      ),
    ],
  );
}

class AppFooter extends StatelessWidget {
  const AppFooter({super.key, this.inDrawer = false, this.opener = openPage});
  final bool inDrawer;
  final PageOpener opener;

  static const information = {
    'About': 'about/',
    'Terms and conditions': 'terms/',
    'Liability': 'liability/',
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final palette = WorthhitPalette.of(context);
      final strings = AppStrings.of(context);
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final compact = inDrawer || constraints.maxWidth < 800 * scale;
      final buttonStyle = TextButton.styleFrom(
        foregroundColor: palette.muted,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: Theme.of(context).textTheme.bodySmall,
      );
      IconData symbol(String label) => switch (label) {
        'GitHub' => WorthhitIcons.code,
        'About' => WorthhitIcons.info_outline,
        'Terms and conditions' => WorthhitIcons.receipt_long_outlined,
        'Liability' => WorthhitIcons.shield_outlined,
        _ => WorthhitIcons.open_in_new,
      };
      Widget link(String label, String destination, {String? key}) => Semantics(
        key: ValueKey(key ?? 'footer-${destination.split('/').first}'),
        link: true,
        hint: label == 'GitHub' ? strings.text('Opens in a new tab') : null,
        child: SelectableIconButton(
          tooltip: strings.text(label),
          onPressed: () =>
              openInformationLink(context, destination, opener: opener),
          style: buttonStyle,
          icon: Icon(symbol(label), size: 18),
        ),
      );
      return Container(
        padding: EdgeInsets.symmetric(horizontal: inDrawer ? 16 : 24),
        decoration: BoxDecoration(
          color: inDrawer ? null : palette.paper,
          border: Border(top: BorderSide(color: palette.ink)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    label: strings.text('Version {version}', {
                      'version': appVersion,
                    }),
                    excludeSemantics: true,
                    child: Text(
                      'v$appVersion',
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.muted),
                    ),
                  ),
                  link('GitHub', sourceRepositoryUrl, key: 'footer-github'),
                ],
              ),
            ),
            if (compact)
              PopupMenuButton<String>(
                key: const ValueKey('footer-info-menu'),
                tooltip: strings.text('Information links'),
                onSelected: (destination) =>
                    openInformationLink(context, destination, opener: opener),
                itemBuilder: (context) => [
                  for (final entry in information.entries)
                    SelectablePopupMenuItem(
                      value: entry.value,
                      child: Semantics(
                        link: true,
                        child: Row(
                          children: [
                            Icon(symbol(entry.key), size: 18),
                            const SizedBox(width: 10),
                            Flexible(child: AppText(entry.key)),
                          ],
                        ),
                      ),
                    ),
                ],
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(WorthhitIcons.info_outline, size: 18),
                        SizedBox(width: 4),
                        Icon(WorthhitIcons.expand_less, size: 16),
                      ],
                    ),
                  ),
                ),
              )
            else
              for (final entry in information.entries)
                link(entry.key, entry.value),
          ],
        ),
      );
    },
  );
}
