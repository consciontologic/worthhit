import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../api/open_router_client.dart';
import '../l10n/app_strings.dart';
import 'selectable_surface.dart';
import 'worthhit_icons.dart';
import 'worthhit_theme.dart';

/// An anchored, searchable catalogue whose metadata stays beside selection.
class HomepageModelsButton extends StatefulWidget {
  const HomepageModelsButton({super.key, required this.controller});
  final AppController controller;
  @override
  State<HomepageModelsButton> createState() => _HomepageModelsButtonState();
}

class _HomepageModelsButtonState extends State<HomepageModelsButton> {
  final _menu = MenuController();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final state = widget.controller;
      final viewport = MediaQuery.sizeOf(context);
      final width = math.min(480.0, viewport.width - 24);
      final height = math.min(540.0, viewport.height * .7);
      final models = state.models
          .where(
            (model) => '${model.name} ${model.id}'.toLowerCase().contains(
              _query.toLowerCase(),
            ),
          )
          .toList();
      return MenuAnchor(
        controller: _menu,
        consumeOutsideTap: true,
        style: MenuStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          backgroundColor: WidgetStatePropertyAll(
            WorthhitPalette.of(context).surface,
          ),
          shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
          side: WidgetStatePropertyAll(
            BorderSide(color: WorthhitPalette.of(context).ink, width: 2),
          ),
        ),
        menuChildren: [
          SizedBox(
            width: width,
            height: height,
            child: SelectionArea(
              child: CustomScrollView(
                key: const ValueKey('model-menu-scroll'),
                controller: _scroll,
                primary: false,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            12,
                            8,
                            4,
                            4,
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: AppText(
                                  'Choose a free model',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              SelectableIconButton(
                                tooltip: AppStrings.of(context)
                                    .text('Close models'),
                                onPressed: _menu.close,
                                icon: const Icon(WorthhitIcons.close),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            key: const ValueKey('model-search'),
                            controller: _search,
                            decoration: InputDecoration(
                              hintText: AppStrings.of(context)
                                  .text('Search models'),
                              prefixIcon: const Icon(WorthhitIcons.search),
                            ),
                            onChanged: (value) =>
                                setState(() => _query = value),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: AppText(
                                  '{count} free models',
                                  params: {'count': models.length},
                                ),
                              ),
                              SelectableIconButton(
                                tooltip: AppStrings.of(context).text(
                                  state.catalogLoading
                                      ? 'Refreshing…'
                                      : 'Refresh models',
                                ),
                                onPressed: state.catalogLoading || state.busy
                                    ? null
                                    : state.refreshModels,
                                icon: const Icon(
                                  WorthhitIcons.refresh,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                    ),
                  ),
                  if (models.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: AppText(
                          'No matching models. Refresh or change your search.',
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: models.length,
                      itemBuilder: (context, index) => _row(models[index]),
                    ),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: AppText(
                        'Media support is advertised, not guaranteed. 4 files maximum, 8 MiB each, 12 MiB total.',
                        style: TextStyle(fontSize: 11, height: 1.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        builder: (context, menu, child) => OutlinedButton.icon(
          key: const ValueKey('homepage-models'),
          onPressed: state.busy || state.pickingMedia
              ? null
              : () => menu.isOpen ? menu.close() : menu.open(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          icon: const Icon(WorthhitIcons.hub_outlined, size: 18),
          label: const AppText('Models'),
        ),
      );
    },
  );

  Widget _row(ModelInfo model) {
    final selected = widget.controller.selectedModel?.id == model.id;
    return TextButton(
      key: ValueKey('choose-model-${model.id}'),
      onPressed: widget.controller.busy || widget.controller.pickingMedia
          ? null
          : () {
              widget.controller.selectModel(model);
              _menu.close();
            },
      style: TextButton.styleFrom(
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.all(12),
        shape: const RoundedRectangleBorder(),
        backgroundColor: selected ? WorthhitPalette.of(context).soft : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  model.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (selected) const Icon(WorthhitIcons.check, size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            model.id,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              const AppText('Text'),
              AppText(model.acceptsImages ? 'Images supported' : 'No images'),
              AppText(model.acceptsVideo ? 'Video supported' : 'No video'),
            ],
          ),
          const SizedBox(height: 4),
          AppText(
            model.supportsTools ? 'Web search compatible' : 'No web search',
          ),
          AppText(
            model.contextLength > 0
                ? 'Context: {count} tokens'
                : 'Context limit not reported',
            params: {'count': model.contextLength},
            style: const TextStyle(fontSize: 11),
          ),
          if (model.maxCompletionTokens != null)
            AppText(
              'Maximum answer: {count} tokens',
              params: {'count': model.maxCompletionTokens!},
              style: const TextStyle(fontSize: 11),
            ),
          if (model.inputModalities.contains('video') && !model.acceptsVideo)
            const AppText(
              'Video disabled by free-route safeguards',
              style: TextStyle(fontSize: 11),
            ),
        ],
      ),
    );
  }
}
