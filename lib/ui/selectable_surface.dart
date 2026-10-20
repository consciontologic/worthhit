import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'worthhit_icons.dart';
import 'worthhit_theme.dart';

/// Keep selection below a route's Overlay so touch copy toolbars can open and
/// Select all does not include the workspace behind an open dialog.
Future<T?> showSelectableDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  builder: (context) => SelectionArea(child: builder(context)),
);

/// Keep the item's activation recognizer inside its selection scope so a
/// normal tap still chooses the item while dragging can copy its label.
class SelectablePopupMenuItem<T> extends PopupMenuItem<T> {
  const SelectablePopupMenuItem({super.key, super.value, required super.child});

  @override
  PopupMenuItemState<T, SelectablePopupMenuItem<T>> createState() =>
      _SelectablePopupMenuItemState<T>();
}

class _SelectablePopupMenuItemState<T>
    extends PopupMenuItemState<T, SelectablePopupMenuItem<T>> {
  @override
  Widget build(BuildContext context) =>
      SelectionArea(child: super.build(context));
}

/// Hints remain copyable without triggering the underlying action.
class SelectableTooltip extends StatelessWidget {
  const SelectableTooltip({
    super.key,
    required this.message,
    required this.child,
  });
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    richMessage: _TooltipText(
      message,
      ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width - 48).clamp(160, 380),
        ),
        child: SelectionArea(child: Text(message)),
      ),
    ),
    ignorePointer: false,
    enableTapToDismiss: false,
    exitDuration: const Duration(milliseconds: 500),
    showDuration: const Duration(seconds: 10),
    child: child,
  );
}

class _TooltipText extends WidgetSpan {
  const _TooltipText(this.text, Widget content) : super(child: content);
  final String text;

  @override
  void computeToPlainText(
    StringBuffer buffer, {
    bool includeSemanticsLabels = true,
    bool includePlaceholders = true,
  }) => buffer.write(text);
}

class SelectableIconButton extends StatelessWidget {
  const SelectableIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.style,
  });
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: SelectableTooltip(
      message: tooltip,
      child: IconButton(onPressed: onPressed, icon: icon, style: style),
    ),
  );
}

/// Optional explanatory copy stays one action away from the working form.
class ContextHelp extends StatelessWidget {
  const ContextHelp({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => SelectableIconButton(
    tooltip: AppStrings.of(context).text(title),
    icon: const Icon(WorthhitIcons.help_outline, size: 20),
    onPressed: () => showSelectableDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: AppText(title),
        content: SingleChildScrollView(child: child),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Done'),
          ),
        ],
      ),
    ),
  );
}
