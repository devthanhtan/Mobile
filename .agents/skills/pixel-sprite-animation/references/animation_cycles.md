# Top-Down Pixel Animation Cycles Reference

## 1. Frame Timing (`stepTime` in Flame)

| State | Frames | Loop | `stepTime` | Motion Keyframes |
| --- | --- | --- | --- | --- |
| Player `idle` | 4 | Yes | `0.16s` | F0 neutral -> F1 squash 1px down -> F2 neutral -> F3 subtle head/breath up 1px |
| Player `walk` | 4 | Yes | `0.10s` | F0 left foot forward + body up 1px -> F1 passing neutral -> F2 right foot forward + body up 1px -> F3 passing neutral |
| Entity `hit` | 1 | No | `0.08s` | Solid white silhouette (pre-baked PNG frame, zero runtime `ColorFilter`) |
| Entity `death` | 4 | No | `0.09s` | F0 knockback tilt -> F1 flash + shrink -> F2 pixel burst ring -> F3 fading dust specks |
| Enemy `deadline` move | 4 | Yes | `0.10s` | Clock body hops + twin alarm bells shake left/right alternately + angry brows pulse |
| Enemy `email` move | 4 | Yes | `0.11s` | Envelope flaps wings up/mid/down/mid + red notification badge pulses |
| Enemy `quiz` move | 4 | Yes | `0.09s` | Forward dash lean + exclamation mark `!` blinks bright gold/red |
| Boss `idle` | 4 | Yes | `0.15s` | Heavy breathing squash/stretch (2px) + floating aura runes shift |
| Boss `attack` | 4 | No | `0.12s` | F0–F1 wind-up/telegraph crouch + bright charge -> F2 slam/release peak -> F3 recovery |
| Boss `phase2` | 4 | Yes | `0.10s` | Enraged red glowing horns/eyes + jagged aura crackle + faster breathing |
| Boss `death` | 6 | No | `0.11s` | F0–F1 violent shake + cracks -> F2–F3 white-hot flash bursts -> F4–F5 pixel scatter + fade |
| Pickup `item` | 4 | Yes | `0.16s` | 2px sinusoidal bob + 4-point star sparkle toggling between corners |
| Projectile `spin` (USB) | 4 | Yes | `0.06s` | 0° -> 90° -> 180° -> 270° crisp pixel rotation |
| Projectile `ink` (Pen) | 3 | Yes | `0.07s` | Tapered blue ink droplet + animated tail wisp |
| Melee `slash` (Book) | 4 | No | `0.05s` | F0 windup -> F1 fast 120° arc smear -> F2 wide sweep peak -> F3 dissipating trail |

## 2. Automatic 1px Outline Algorithm (Pillow Helper Pattern)
When generating pixel art procedurally:
1. Draw base colors at logical resolution (`32x32` for `64x64` 2x crisp pixel look, or `48x48` -> `96x96` for bosses) leaving at least a 2-pixel transparent border around the content.
2. Iterate transparent pixels `(x, y)` that have at least one 4-neighbor `(x±1, y)` or `(x, y±1)` with `alpha > 0`.
3. Set those neighbor pixels to the shared dark ink outline color (`#141526FF`).
4. Upscale by exact integer factor (`2x`) with `Image.Resampling.NEAREST`.
5. For the `hit` frame: replace every pixel with `alpha > 0` by `(255, 255, 255, 255)` (or keep dark outline + white interior for extra crispness).

## 3. Caching Pattern in Flame
- Load each PNG strip once into `game.images`.
- Build `SpriteAnimation.fromFrameData(image, SpriteAnimationData.sequenced(amount: N, stepTime: t, textureSize: Vector2(w, h), loop: loop))` inside a game-level cache map (e.g., `Map<String, SpriteAnimation>`).
- Note: Because `SpriteAnimationTicker` holds per-instance playback progress while `SpriteAnimation` holds shared frames, share `SpriteAnimation` safely across components (each `SpriteAnimationComponent` creates its own ticker automatically).
