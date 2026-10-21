---
name: Worthhit
description: Know the range. Make a fair deal.
colors:
  paper: "#ECEDE5"
  ink: "#252A25"
  lime: "#CAEF63"
  muted: "#555D53"
  soft: "#E2E5D9"
  line: "#B6BCAE"
  surface: "#F6F7EF"
  warning: "#F3DFCD"
  onLime: "#20241D"
typography:
  headline:
    fontFamily: "WorthhitDisplay"
    fontSize: "30px"
    fontWeight: 700
    lineHeight: 1.12
    letterSpacing: "-0.7px"
  title:
    fontFamily: "WorthhitDisplay"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.22
    letterSpacing: "-0.35px"
  body:
    fontFamily: "WorthhitSans"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "WorthhitSans"
    fontSize: "15px"
    fontWeight: 700
    lineHeight: 1.35
rounded:
  control: "2px"
  estimate: "0px"
  panel: "0px"
spacing:
  tight: "8px"
  group: "16px"
  section: "24px"
components:
  button-primary:
    backgroundColor: "{colors.lime}"
    textColor: "{colors.onLime}"
    rounded: "{rounded.control}"
    padding: "14px 18px"
  button-secondary:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "13px 16px"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "16px 14px"
  estimate:
    backgroundColor: "{colors.lime}"
    textColor: "{colors.onLime}"
    rounded: "{rounded.estimate}"
    padding: "20px"
---

# Worthhit design and identity

Worthhit is a price-checking workspace for careful second-hand decisions. Its
visual hierarchy puts the product, simple inputs and explicit estimate action first.
Sources and calculation assumptions belong in the result, not a required form. The user approved an editorial neo-brutalist direction after the
reference host was blocked. That image was not analyzed or reproduced.

## Direction contract

Graphite, warm neutral surfaces and restrained lime; square panels and sharp
rules; Space Grotesk headings with Noto reading text. No photographs, people,
animals, physical-object illustrations, decorative gradients or purple.
The generated mark concept informed an independently authored geometric W.
The production SVG is original vector geometry, not a claimed vector conversion
of the raster concept. No trademark clearance is claimed.

| Token | Light | Dark |
|---|---|---|
| Canvas | `#ECEDE5` | `#161A18` |
| Surface | `#F6F7EF` | `#1D241F` |
| Secondary surface | `#E2E5D9` | `#252D26` |
| Text / rules | `#252A25` | `#E9EDE1` |
| Primary accent | `#CAEF63` | `#CAEF63` |
| Text on accent | `#20241D` | `#20241D` |

Controls have 2px corners; panels are square. Borders are normally 2px. Only
the admitted price range gets a restrained hard shadow. Reading text remains
selectable. Color never implies that an item, source or seller is verified.
Keyboard focus, disabled states and warnings retain textual/structural cues.

Phones present one editor for product, currency, condition and optional notes, with
an immediate estimate action and access to the result. Tablets and desktops can
show editor and result together. The homepage Models button opens an anchored
catalog with usable input capabilities and context limits. Images/Video controls
remain visible but disabled with an explanation for unsupported models. Keep at
least 44px touch targets and let large text expand. Optional explanations belong
in contextual help; search fees, transmitted content and estimate limitations stay
visible where users make the decision.
Arabic uses directional padding and RTL. UI and explanatory text follow the
selected language; evidence quotations do not change language.

## Asset handoff

All paths below are in the repository. No identity export has a white background.

| Use | Files | Background |
|---|---|---|
| Main logo | `assets/brand/logo-light.svg`, `logo-dark.svg` and matching PNGs | Transparent |
| Compact mark | `assets/brand/mark-light.svg`, `mark-dark.svg` and 512px PNGs | Transparent |
| Browser tab | `web/favicon.svg`, explicit light/dark SVGs, PNG/ICO fallback | Adaptive SVG transparent; fallback graphite |
| PWA any-purpose | `web/icons/Icon-192.png`, `Icon-512.png` | Transparent lime |
| Maskable launcher | `web/icons/Icon-maskable-192.png`, `Icon-maskable-512.png` | Graphite with centered safe-zone mark |
| Apple launcher | `web/icons/apple-touch-icon.png` (180px) | Graphite |
| Social preview | `web/social-card.png` (1200×630); vector in `assets/brand/` | Graphite |

Use the dark variant on dark surfaces and the light variant on light surfaces.
Do not stretch, rotate or add a glow. Leave clear space around the mark; do not
place text inside the launcher safe zone. System favicons adapt with CSS; an
explicit app theme updates the browser favicon and toolbar color.

`tool/brand_assets.py` recreates the exports with optional local design tools:
CairoSVG 2.9.1, fonttools 4.67.0 and Pillow 13.0.0. Application/release builds use
committed assets. Space Grotesk and Noto fonts are bundled under OFL licenses;
download sources and SHA256 values are recorded in `assets/fonts/sources.json`.
The image-generation concept is not shipped as an app asset.

The design exploration seed was `7aba5435`; the user's explicit approved
direction takes precedence over generated challenger suggestions.

## Interface symbols

`assets/icons/` holds 35 original transparent SVG symbols and the 4.9KB
WorthhitIcons font used by Flutter. `tool/generate_icons.py` reproduces both from
shared vector geometry. Use 18–24px symbols with theme-provided colors, plus
localized tooltips and semantic names for icon-only controls. Only the forward
action arrow mirrors with RTL. Source, estimate, evidence and trust symbols are
navigation cues, never proof of verification or a guaranteed price.
