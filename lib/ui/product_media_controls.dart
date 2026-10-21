import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../l10n/app_strings.dart';
import 'selectable_surface.dart';
import 'worthhit_icons.dart';
import 'worthhit_theme.dart';

class ProductMediaControls extends StatelessWidget {
  const ProductMediaControls({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final model = controller.selectedModel;
    final blocked = controller.busy || controller.pickingMedia;
    Widget button(String kind, String label, IconData icon, bool supported) =>
        SelectableTooltip(
          message: AppStrings.of(context).text(
            supported
                ? '4 files maximum, 8 MiB each, 12 MiB total.'
                : 'Choose a model that supports this media type.',
          ),
          child: OutlinedButton.icon(
            key: ValueKey('add-$kind'),
            onPressed: blocked || !supported
                ? null
                : () => controller.pickMedia(
                    allowedMimeTypes: model!.allowedMediaMimeTypes
                        .where((mime) => mime.startsWith('$kind/'))
                        .toSet(),
                  ),
            icon: Icon(icon, size: 18),
            label: AppText(label),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            button(
              'image',
              'Add images',
              Icons.add_photo_alternate_outlined,
              model?.acceptsImages ?? false,
            ),
            button(
              'video',
              'Add video',
              Icons.video_library_outlined,
              model?.acceptsVideo ?? false,
            ),
            if (controller.pickingMedia)
              TextButton.icon(
                onPressed: controller.cancelMediaPick,
                icon: const Icon(WorthhitIcons.close, size: 18),
                label: const AppText('Cancel'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        AppText(
          'Optional photos or video. Sent only when you request an estimate. Files clear on reload.',
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            color: WorthhitPalette.of(context).muted,
          ),
        ),
        for (final file in controller.attachments)
          Row(
            children: [
              Expanded(
                child: Text(
                  file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SelectableIconButton(
                tooltip: AppStrings.of(context)
                    .text('Remove {name}', {'name': file.name}),
                onPressed: blocked
                    ? null
                    : () => controller.removeMedia(file.id),
                icon: const Icon(WorthhitIcons.close, size: 18),
              ),
            ],
          ),
        if (controller.mediaError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                AppStrings.of(context).safeMessage(controller.mediaError!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
      ],
    );
  }
}
