---
name: Worthit
description: Good deals. Less guesswork.
colors:
  paper: "#FFF9ED"
  ink: "#20211D"
  lime: "#D4F267"
  coral: "#FF8B70"
  muted: "#5C5D52"
  soft: "#F1EBDD"
  line: "#D5D0C2"
typography:
  headline:
    fontFamily: "WorthitSans"
    fontSize: "29px"
    fontWeight: 700
    lineHeight: 1.12
    letterSpacing: "-0.6px"
  title:
    fontFamily: "WorthitSans"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.25
  body:
    fontFamily: "WorthitSans"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "WorthitSans"
    fontSize: "16px"
    fontWeight: 700
    lineHeight: 1.35
rounded:
  control: "6px"
  estimate: "8px"
  panel: "10px"
spacing:
  tight: "8px"
  group: "16px"
  section: "24px"
components:
  button-primary:
    backgroundColor: "{colors.lime}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "14px 20px"
  button-secondary:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "13px 16px"
  input:
    backgroundColor: "#FFFFFF"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "16px 14px"
  estimate:
    backgroundColor: "{colors.lime}"
    textColor: "{colors.ink}"
    rounded: "{rounded.estimate}"
    padding: "20px"
---

# Design System: Worthit

## Overview

**Creative North Star: "The fair-deal workbench"**

Warm paper, decisive ink, and a lime action color make a practical price-checking
tool feel approachable. The user’s neo-brutalist direction appears in solid
outlines, plain geometry, bold lettering, and a small number of hard shadows.
Information stays calmer than the accent.

**Key Characteristics:**
- Visible evidence before confidence.
- Bold controls and quiet reading surfaces.
- Device-specific workflows with one continuous draft.

## Colors

Paper is the application canvas; soft is the navigation and contextual-help
surface. Ink carries text and structure. Lime marks the primary action, selected
choices, and an observed comparable range. Coral is reserved for restrained
attention accents; warning text uses a darker accessible red.

**The Evidence Rule.** Color never implies that a source, seller, or price is
verified. Uncertainty must be written in words.

## Typography

WorthitSans is a locally bundled Roboto family in regular and bold weights.
Headlines are short and sentence case. Form labels remain fully visible above
inputs. Long descriptions, quotes, and source URLs wrap naturally; report text is
selectable. Body copy uses a generous line height, with compact secondary text
reserved for provenance and help.

## Layout

Below 700 logical pixels, a guided Details → Evidence → Estimate flow has a
bottom primary action and three persistent destinations. Between 700 and 1099,
a compact icon rail and Edit item / Price picture tabs provide a focused tablet
workspace. At 1100 and above, a 220-pixel rail anchors independently scrollable
form and result columns. At text scale 1.8 or above, the guided layout takes
precedence regardless of width.

The form owns persistent text controllers and focus nodes, and is reparented
with a GlobalKey across device layouts. Navigation changes organization, not
the draft. Controls are at least 48 logical pixels in their smallest tap
dimension. Form groups use 20-pixel separation and panels use 24–28-pixel gutters.

## Elevation & Depth

Two-pixel ink borders define work surfaces. A hard offset shadow is used only on
the lime empty-state mark and observed-price block, where it reinforces the
requested neo-brutalism. Most components use flat tonal layering. There are no
gradients, glass effects, or decorative motion.

## Shapes

Controls have restrained rounded corners; panels are slightly softer. Standard
Material icons share the same simple weight and scale. Price values are written
directly, without a chart that could imply an unsupported distribution.

## Components

The primary button uses lime, an ink outline, and an explicit action verb.
Secondary buttons use an outline with standard hover/focus feedback. Selected
goal and navigation controls expose semantic selected state. Inputs use white
surfaces and a heavier focused outline.

Connection settings keep credentials obscured by default and clearly describe
session-only storage. Model refresh, endpoint inspection, cancellation, and
explicit retry remain user actions. Errors announce themselves through a live
region. Results distinguish insufficient evidence, missing details, prohibited
items, and admitted observed-price ranges.

## Do's and Don'ts

- Do keep evidence, caveats, and next questions selectable.
- Do use a written explanation alongside every warning or estimate.
- Do preserve text and focus when switching layouts.
- Don't use heavy purple, gradients, or decorative motion.
- Don't imply that a plausible price is a verified transaction.
- Don't hide a model failure by automatically retrying or changing models.
