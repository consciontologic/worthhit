# Worthhit UI icons

Original angular symbols for second-hand price checks. The 35 glyphs use a
24-unit grid and two-unit stroke, with chamfered shapes derived from the price
tag. Transparent SVGs and the font contain the same outlined geometry.

Use `Icon(WorthhitIcons.update)` and the `WorthhitIcons` font registered in
`pubspec.yaml`. Icons inherit `IconTheme` colors in light and dark mode. They have
no background fill. Use 18–24 logical pixels for compact controls and preserve
touch targets of at least 44 pixels. Give icon-only actions localized tooltips and semantic
labels; familiar symbols should replace redundant copy, not essential guidance.
Only the forward navigation arrow mirrors in RTL. Playback, external links,
price tags and other pictograms retain their direction.

`tool/generate_icons.py` is the master artwork and generates the SVGs,
`WorthhitIcons.ttf`, `manifest.json` and `lib/ui/worthhit_icons.dart`. Keep existing
manifest codepoints stable when adding a symbol. Rebuild using the project-local
design environment used by `tool/brand_assets.py`:

```sh
.local/brand-tools/bin/python tool/generate_icons.py
dart format lib/ui/worthhit_icons.dart
flutter test test/ui/worthhit_icons_test.dart
```

Optional design dependencies are pinned in the generator's header. Production
builds use the committed files and do not run the generator. The ignored review
sheet `.impeccable/review/worthhit-icons-contact-sheet.png` compares every icon at
20, 24 and 48 pixels on warm neutral and graphite surfaces.

The Logos & app icons workflow and a generated raster concept informed the visual
direction; the production paths are separately authored vectors. These assets
use the repository's MIT license. No trademark clearance is claimed.
