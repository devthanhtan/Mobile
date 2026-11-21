# Weapon VFX & Mechanics Patterns (Data-Driven Strategy)

## 1. Five Distinct Weapon Archetypes (Soul Knight-Style)

| Weapon | Archetype | Visual / Animation | Gameplay Hook | VFX Budget (Pooled) |
| --- | --- | --- | --- | --- |
| **Bút bi (Pen)** | Rapid light shot | 2–3f blue ink bolt + short trailing tail + small cyan muzzle flash | High fire rate, low damage, crisp accuracy | 2–3 blue pixel sparks on hit |
| **Laptop** | Charge piercing laser | Hold 0.4s charge glow at tip -> animated cyan-white beam across arena | Pierces all enemies along line; slight camera kick | Beam fades in `0.16s`, sparks on each pierced target |
| **USB** | Spinning ricochet | 4f spinning metallic shuriken | Bounces off arena playable walls up to 2 times; deals damage each bounce | Metallic yellow sparks on wall bounce & enemy hit |
| **Trà sữa (Boba)** | Bouncing sustain shot | Glossy dark pearl + cream highlight, slight arc/bounce | Deals damage + heals player small HP on hit | 3–4 expanding hollow pixel bubbles on hit |
| **Giáo trình (Textbook)** | Melee arc cleave | 4f 120° pixel sweep arc + white/gold slash smear | Wide close-range cleave + strong knockback + optional bullet clear | Paper/gold pixel flecks along arc |

## 2. Hit Particle Pool Spec
- **Shape**: `2x2` to `4x4` solid pixel squares (rendered with `canvas.drawRect` using a single pooled `Paint` whose `.color` is updated per color batch, or pre-cached palette paints).
- **Lifetime**: `0.18–0.32s` with simple linear drag (`vel *= 0.90`).
- **Global Cap**: Max `64` active particles on screen; when full, recycle the oldest particle immediately.

## 3. Data-Driven Strategy Structure
Separate static stats (`weapon_config.dart`: `id`, `name`, `fireRate`, `damage`, `speed`, `pierce`, `maxBounces`, `knockback`, `chargeTime`, `healOnHit`, `sfxHook`) from execution strategy (`WeaponBehavior` implementations: `RapidProjectileWeapon`, `ChargeLaserWeapon`, `RicochetWeapon`, `HealingBobaWeapon`, `MeleeArcWeapon`) so adding a 6th weapon requires zero edits to `PlayerComponent`.
