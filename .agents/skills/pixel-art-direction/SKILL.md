---
name: pixel-art-direction
description: >-
  Guides pixel art direction, limited color palettes (<=16 colors), outline rules,
  chibi proportions, silhouette readability, and integer/nearest-neighbor scaling
  for 2D top-down pixel art mobile games. Activate when defining art style guides,
  choosing palettes, reviewing sprites/maps, or designing visual consistency.
---

# Pixel Art Direction (2D Top-Down Mobile Games)

Use this skill whenever establishing or applying pixel art visual standards for characters, enemies, bosses, props, items, and top-down arena maps.

## Core Design Rules

1. **Unified Pixel Grid (No Mixels)**
   - Keep a consistent source texel density across entities (e.g., `64x64` source canvas for standard characters/enemies/weapons, `96x96` or `128x128` for bosses, `32x32` or `64x64` for pickups).
   - Always render with nearest-neighbor filtering (`FilterQuality.none` in Flutter/Flame) — never bilinear blur on pixel art.
   - Avoid arbitrary non-uniform scaling on sprites unless used momentarily for squash-and-stretch.

2. **Limited Palette Discipline (Max 16 Core Colors)**
   - Restrict core gameplay art to a cohesive <= 16-color master palette with hue-shifted ramps (highlights shift warmer/yellow, shadows shift cooler/purple-blue).
   - Reserve highest saturation and brightness for **interactive gameplay elements**: player, enemy bullets, pickups, and telegraph warnings.
   - Keep arena floors lower contrast and slightly desaturated so entities pop immediately.
   - See [palette_and_shading.md](./references/palette_and_shading.md) for hue-shifting rules, shadow recipes, and silhouette checks.

3. **1px Dark Outline Standard**
   - Wrap foreground actors (players, enemies, bosses, weapons, pickups) in a crisp **1px unified dark outline** using a deep chromatic ink (e.g., `#141526` or `#1B192E`) rather than flat pure black `#000000`, except where extreme contrast is needed.
   - Never apply heavy dark outlines to walkable floor tiles.
   - Avoid "jaggies" (irregular pixel staircases) and "orphan pixels" (isolated single pixels creating visual noise).

4. **Top-Down Chibi Silhouette & Grounding**
   - Use 3/4 top-down perspective (visible front face + slight top of head/shoulders).
   - Chibi proportions: head ~45–55% of body height so eyes, glasses, hats, and expressions stay legible at `48x48` display size on phones.
   - Every actor needs a soft, flat elliptical **ground shadow** centered beneath the feet (`alpha ~0.30–0.38`) to anchor depth on the arena floor.
   - Every character class and enemy archetype must be distinguishable in solid black silhouette alone (distinct headgear, prop, or body shape).

## Workflow Checklist

1. Define or verify the project's master palette (`<= 16` hex colors) and shared ink outline color.
2. Verify source vs display dimensions and hitboxes (hitbox smaller than visual sprite for fair dodging, ~60% for player/enemies, ~70% for bosses).
3. Check contrast separation between 4 visual layers:
   - Layer 1 (Lowest contrast): Arena floor & perimeter props
   - Layer 2 (Medium-high contrast): Player, enemies, bosses
   - Layer 3 (Highest contrast): Bullets, laser beams, attack telegraphs, pickups
   - Layer 4 (Crisp framed UI): HUD bars, timer, controls
4. Validate sprites on actual mobile viewport scale (downscaled to `48x48` dp) to confirm shapes remain readable without muddying.
