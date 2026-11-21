---
name: pixel-sprite-animation
description: >-
  Guides 2D pixel art sprite sheet layout, chibi character/enemy/boss/item
  animation cycles, Pillow-based procedural sprite generation, and Flame
  SpriteAnimation caching. Activate when designing sprite sheets, writing sprite
  generator scripts, or integrating animations in Flame.
---

# Pixel Sprite Sheet & Animation Workflow

Use this skill when designing, generating, or wiring frame-by-frame pixel animations for characters, enemies, bosses, pickups, and weapons in Flutter/Flame.

## Sprite Sheet Standards

1. **Horizontal Strip Layout**
   - Export each animation state (or full entity sheet) as a crisp PNG with **transparent background** (`RGBA`) and **zero anti-aliasing**.
   - Uniform cell size per strip (e.g., `64x64` cells -> 4-frame strip is `256x64`; `96x96` boss -> 4-frame strip is `384x96`).
   - Keep consistent **feet baseline** (e.g., 4–6px from bottom edge) across every frame so sprites never jitter vertically when switching states.
   - **Left-facing = horizontal flip** (`scale.x = -1.0`): author all sprites facing **right** by default; never duplicate left-facing sheets unless asymmetric armor/text requires it.

2. **Minimum Required Frame Budgets**
   - **Player classes**: `idle` (4f), `walk` (4f), `hit` (1f pure-white silhouette flash), `death` (4f).
   - **Normal enemies**: `move/idle` (4f), `hit` (1f), `death` (4f).
   - **Bosses**: `idle` (4f), `attack` (4f with clear anticipation/telegraph on frames 1–2 and release on frames 3–4), `phase2` (4f enraged glow/horns), `death` (6f dramatic burst/collapse).
   - **Pickups/Items**: `bob_sparkle` (4f vertical 1–2px bob + rotating 4-point pixel sparkle).
   - **Weapon projectiles / melee**: 2–4f loop (ink trail, spinning shuriken, pulsing laser beam, 4f melee slash arc).
   - See [animation_cycles.md](./references/animation_cycles.md) for per-frame motion breakdowns and timing (`stepTime`).

3. **Python / Pillow Generation Rules**
   - Always create canvases in `RGBA` with `(0, 0, 0, 0)` background.
   - Draw on a logical pixel grid (e.g., `32x32` upscaled 2x with `Image.Resampling.NEAREST` to `64x64`, or native `64x64` with explicit 2px/1px strokes) — **never** use `BILINEAR`, `BICUBIC`, or `LANCZOS`.
   - Apply the 1px dark outline pass automatically after drawing the base silhouette (check 4-connected neighbors of opaque pixels) to guarantee uniform, unbroken outlines with zero stray pixels.
   - Generate the 1-frame `hit` sprite directly from the idle silhouette filled with pure white `#FFFFFF` (preserving alpha) so Flame never needs runtime `ColorFilter` / `saveLayer` for hit-flash!

4. **Flame Integration & Performance Rules**
   - Preload all sprite sheet PNGs once in `onLoad()` using `game.images.loadAll(...)`.
   - Build and **cache** each `SpriteAnimation` (or `SpriteAnimationData`) **once per entity type/state** in a central registry/cache — never recreate `SpriteAnimation` from scratch on every enemy/bullet spawn.
   - Always set `paint.filterQuality = FilterQuality.none` on `SpriteAnimationComponent`.

## Validation Steps

1. Verify every exported PNG has exact expected dimensions (`frameWidth * frameCount`, `frameHeight`), `RGBA` mode, and only colors from the style guide palette.
2. Confirm no sprite clips past its cell edges during walk bob, attack anticipation, or spin frames.
3. Verify Flame animation caching: spawning 30+ enemies reuses cached `SpriteAnimation` instances without decoding images or reallocating frame lists.
