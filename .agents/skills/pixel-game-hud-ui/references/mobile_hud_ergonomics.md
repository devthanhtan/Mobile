# Mobile Landscape Pixel HUD Ergonomics & Tokens Reference

## 1. Screen Safe-Zone Map (Landscape 16:9 / 20:9)

```text
+-------------------------------------------------------------------+
| [Top-Left: Player Stats]   [Top-Center: Boss HP]   [Pause/Audio]  |  <- Max 12-14% height
|  Portrait + HP + Shield      (only in Boss phase)   (>=48x48 dp)  |
|  Timer 05:00 | Coins | Kills                                      |
|                                                                   |
|                         PLAYABLE ARENA                            |
|                  (Unobstructed center viewport)                   |
|                                                                   |
|   (  Joystick  )                                 [Weapon 66dp]    |
|     124x124 dp                    ( Shoot )       [Dash 74dp]     |
|                                   104x104 dp                      |
+-------------------------------------------------------------------+
```

## 2. Recommended Control Dimensions

| Control | Size (dp) | Touch Target | Notes |
| --- | --- | --- | --- |
| Virtual Joystick | `124 x 124` (knob radius `22`) | Full pad | Translucent ring, crisp pixel crosshair |
| Primary Shoot Button | `104 x 104` | `104 x 104` | Warm accent border, supports drag-to-aim |
| Dash Button | `74 x 74` | `74 x 74` | Cyan ready state, dark gray + arc/bar on cooldown |
| Weapon Switch Button | `66 x 66` | `66 x 66` | Shows `FilterQuality.none` sprite + slot badge |
| Pause / Audio Buttons | `48 x 48` | `48 x 48` | Pixel-framed square button (upgrade from tiny <40dp icons) |
| Modal Action Buttons | Height `>= 48` | `>= 140 x 48` | Crisp 2px pixel bevel, instant high contrast |

## 3. Pixel Frame Styling Recipe (Flutter)
Instead of expensive blurred drop shadows (`blurRadius: 16-24`), use crisp pixel-art hard offset shadows:
```dart
BoxDecoration(
  color: Color(0xDD141526), // High-contrast dark ink surface
  borderRadius: BorderRadius.circular(6),
  border: Border.all(color: Color(0xFF4A5580), width: 2),
  boxShadow: const [
    BoxShadow(
      color: Color(0xFF0A0B14),
      offset: Offset(2, 2),
      blurRadius: 0, // Zero blur = authentic pixel style + faster GPU raster
    ),
  ],
)
```

## 4. Semantic HUD Colors
- **HP Healthy (>35%)**: `#38D973` (bright pixel emerald)
- **HP Critical (<=35%)**: `#FF3B5C` (vivid crimson-red)
- **Shield / Dash Ready**: `#29E7FF` (electric cyan)
- **Timer Normal / Coins**: `#FFD54F` (pixel gold)
- **Timer Urgent (<=30s) / Boss Warning**: `#FF3B5C` with `#FFD54F` border
- **Cooldown / Disabled**: `#5C6480` (muted slate)
- **Panel Surface**: `#141526` (`~86%` alpha) with `#3D4468` / `#5A6594` pixel border
