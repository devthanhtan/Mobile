---
name: pixel-game-hud-ui
description: >-
  Guides mobile landscape HUD layout, touch ergonomics (>=48dp targets), retro
  pixel UI framing, high-contrast typography (with Vietnamese diacritic safety),
  and low-rebuild Flutter HUD architecture for 2D pixel action games. Activate
  when designing or styling game HUDs, menus, dialogs, joysticks, or buttons.
---

# Pixel Game HUD & Mobile Ergonomics (Flutter)

Use this skill when designing or updating in-game HUDs, virtual controls, menus, and dialogs for 2D pixel-art mobile action games in landscape orientation.

## Core UI/UX Rules

1. **Landscape Thumb-Zone Ergonomics**
   - **Minimum touch target**: Every interactive button (pause, audio, weapon switch, dash, dialog buttons) MUST be at least **`48x48 dp`**.
   - **Minimum spacing**: Keep `>= 8–12 dp` gap between adjacent action buttons to prevent mis-taps during frantic combat.
   - **Left thumb**: Virtual joystick (`116–128 dp` outer diameter, `20–24 dp` knob radius) padded comfortably inside `SafeArea` (`left >= 20`, `bottom >= 16`).
   - **Right thumb cluster (Soul Knight layout)**:
     - Primary **Shoot** button: largest (`96–108 dp`), positioned nearest the natural right-thumb resting arc.
     - **Dash** button: `68–76 dp`, clear radial/linear cooldown ring + concise `0.1s` or `1s` countdown.
     - **Weapon Switch** button: `60–68 dp`, crisp pixel weapon icon + slot badge (`1` / `2`).
   - See [mobile_hud_ergonomics.md](./references/mobile_hud_ergonomics.md) for exact dimensions, color tokens, and layout zones.

2. **Retro Pixel Panel Styling**
   - Use **sharp or subtle pixel-stepped corners** (`borderRadius: 4–8 dp`, avoiding overly bubbly glassmorphism) with a **2px solid border** (`1px` inner highlight / dark outer drop shadow offset `(2, 2)`, `blurRadius: 0` for authentic pixel crispness and cheaper GPU cost than large blurs).
   - Keep HUD panel backgrounds dark semi-opaque (`#141526` at `0.82–0.88` opacity) so text stays readable over any bright arena floor or explosion.
   - Ensure text/icon contrast is **>= 4.5:1** (`#FFFFFF` / `#FFD54F` / `#29E7FF` on `#141526`).

3. **Pixel Typography & Vietnamese Support**
   - Preferred Google Fonts for pixel aesthetics:
     - **`Pixelify Sans`** (strong pixel character AND supports Vietnamese diacritics).
     - **`VT323`** (retro terminal display; good for numbers/timers, check diacritic kerning).
     - **`Press Start 2P`** / **`Silkscreen`** (authentic arcade bitmap look — ideal for ASCII/numbers like `05:00`, `HP 100/100`, `STAGE 1-1`, `DASH`, but lacks full Vietnamese diacritics; pair with `Pixelify Sans` or clean `monospace` fallback for Vietnamese body text).
   - Always use `FontFeature.tabularFigures()` (or monospace) on timers, HP numbers, coins, and cooldowns so digits never jitter horizontally while counting.

4. **Flutter HUD Performance Discipline**
   - Centralize ALL HUD colors, spacing, font families, and control sizes in `constants.dart` (single source of truth).
   - Wrap `GameWidget` and each independent HUD cluster (top-left stats, top-center boss/stage banner, bottom-left joystick, bottom-right controls) in `RepaintBoundary` so UI repaints never invalidate the Flame canvas and vice versa.
   - Never trigger `ValueListenableBuilder` 60 times/sec for text that only changes once per second (quantize timer to whole seconds `ceil()`, cooldown to `0.1s` or paint via `CustomPainter` with a dedicated `Listenable`).

## Validation Checklist

- [ ] Every tappable element >= `48x48 dp` with clear visual pressed feedback.
- [ ] All HUD colors, borders, font styles, and control sizes live in `constants.dart`.
- [ ] Top HUD leaves center gameplay arena unobstructed (`< 14%` viewport height).
- [ ] Zero large `BackdropFilter` or heavy `blurRadius` shadows in live combat HUD.
- [ ] Vietnamese labels remain crisp and legible without broken diacritics.
