---
name: pixel-game-vfx-feel
description: >-
  Guides 2D pixel action combat game feel ("juice"), distinct weapon VFX
  (projectiles, lasers, ricochet, melee arcs), boss attack telegraphs, and
  zero-allocation 60 FPS mobile VFX implementation in Flame. Activate when
  designing weapon mechanics, hit effects, particles, or optimizing combat feel.
---

# Pixel Game VFX & Combat Feel (60 FPS Mobile Budget)

Use this skill when designing weapon behavior, projectile/melee visuals, combat feedback, and boss telegraphs for 2D top-down pixel action games in Flutter/Flame.

## 1. Combat Feedback Principles ("Juice" Without Visual Clutter)

- **Anticipation -> Impact -> Follow-through**:
  - **Muzzle Flash**: 1–2 frames (`0.05s`) crisp pixel star/spark at weapon tip when firing.
  - **Hit Feedback**: `0.08s` white flash frame on target + slight directional knockback (`4–8 px`) + 3–5 tiny square pixel sparks from an object pool.
  - **Camera Shake**: Micro-shake only for heavy moments (player hit, laser shot, boss slam) — intensity `3–6 px`, duration `0.10–0.18s`. Never shake continuously on rapid light shots.
  - **Boss Telegraphs**: Always preview radial bursts (expanding bright ring) and dash charges (dashed/solid red lane) for `0.5–0.65s` before damage triggers.
- See [weapon_vfx_patterns.md](./references/weapon_vfx_patterns.md) for weapon archetypes (rapid ink, charge laser, ricochet shuriken, healing boba, melee sweep).

## 2. Strict 60 FPS Mobile Performance Contract

Every new weapon, projectile, slash, or particle MUST obey these rules:
1. **Object Pooling**: Reuse bullets, hit particles, muzzle flashes, and floating damage numbers from fixed-cap pools instead of calling `world.add` / `removeFromParent` dozens of times per second.
2. **Pre-Cached `Paint` Objects**: Declare all `Paint` instances as `static final` or component fields. Never allocate `Paint()`, `MaskFilter`, or `ColorFilter.mode(...)` inside `render()`.
3. **Avoid `saveLayer` & Blur Filters**: Never use `MaskFilter.blur` on 20+ simultaneous bullets or particles on mobile GPUs; fake pixel glow with 2–3 layered solid alpha circles/rectangles using cached paints.
4. **No Full-World Scans**: Weapon hits, pierce checks, and melee arcs must query the game's cached `enemies` list (and `boss` reference), never `game.world.children`.
5. **Hard Entity Caps**: Enforce max simultaneous enemies, bullets, and particles via constants in `constants.dart` so worst-case combat never drops below 60 FPS.

## Verification Checklist

- [ ] Distinct silhouette + color + sound hook for every weapon type.
- [ ] Enemy bullets remain unmistakably distinguishable from all player weapon VFX.
- [ ] Zero `Paint()` / `Vector2` / `ColorFilter` allocations inside `render()` loops.
- [ ] Particle count and active projectile count stay bounded under continuous firing.
