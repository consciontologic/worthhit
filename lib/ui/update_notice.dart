import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../l10n/app_strings.dart';
import 'selectable_surface.dart';
import 'worthhit_icons.dart';
import 'worthhit_theme.dart';

/// A waiting worker is only activated after an explicit, safe user action.
class UpdateNotice extends StatelessWidget {
  const UpdateNotice({
    super.key,
    required this.controller,
    this.dismissible = true,
  });
  final AppController controller;
  final bool dismissible;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.updateAvailable ||
          (dismissible && !controller.updateNoticeVisible)) {
        return const SizedBox.shrink();
      }
      final palette = WorthhitPalette.of(context);
      final strings = AppStrings.of(context);
      final message =
          controller.updateError ??
          controller.persistenceError ??
          (controller.busy
              ? 'Finish your check before updating.'
              : 'Draft saved on update. Re-enter your key.');
      final content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2, end: 8),
            child: Icon(WorthhitIcons.update, size: 18, color: palette.ink),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'Update ready',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.safeMessage(message),
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            key: const ValueKey('update-apply'),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: const TextStyle(
                fontFamily: 'WorthhitSans',
                fontFamilyFallback: ['WorthhitArabic', 'WorthhitChinese'],
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: controller.busy || controller.updating
                ? null
                : controller.applyUpdate,
            child: AppText(controller.updating ? 'Updating…' : 'Update'),
          ),
          if (dismissible)
            SelectableIconButton(
              key: const ValueKey('update-later'),
              style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
              tooltip: strings.text('Later'),
              onPressed: controller.updating
                  ? null
                  : controller.dismissUpdateNotice,
              icon: const Icon(WorthhitIcons.close, size: 16),
            ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Semantics(
          key: const ValueKey('update-announcement'),
          liveRegion: true,
          child: Container(
            key: const ValueKey('update-notice'),
            width: double.infinity,
            padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 4, 6),
            decoration: BoxDecoration(
              color: palette.soft,
              border: BorderDirectional(
                start: BorderSide(color: palette.ink, width: 3),
                top: BorderSide(color: palette.line),
                bottom: BorderSide(color: palette.line),
                end: BorderSide(color: palette.line),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (MediaQuery.textScalerOf(context).scale(12) > 16) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      content,
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: actions,
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 4),
                    actions,
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
