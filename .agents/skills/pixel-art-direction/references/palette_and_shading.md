# Pixel Palette, Shading & Silhouette Reference

## 1. Hue-Shifting Rule
Never shade pixel art by simply mixing pure white or pure black into a base color:
- **Highlights**: Shift hue slightly toward **yellow/warm** while raising brightness and slightly lowering saturation.
- **Shadows**: Shift hue slightly toward **blue/violet** while lowering brightness and slightly raising saturation.
- **Outline Ink**: Use one shared very dark cool tone (e.g., `#141526` or `#181425`) across all sprites so characters, enemies, and items feel part of the same world.

## 2. Recommended 16-Color Role Allocation (Action Roguelite)
Allocate a <=16-color palette by functional role so gameplay clarity is automatic:

| Slot | Role | Visual Purpose |
| --- | --- | --- |
| 1 | Deep Ink Outline | Universal 1px sprite outline & deep UI border |
| 2 | Dark Floor Base | Main walkable arena background (low saturation) |
| 3 | Mid Floor Tile | Subtle tile pattern / architectural detail |
| 4 | Warm Floor Accent | Campus / arena trim, borders, cracks |
| 5 | Pure Highlight White | Specular glints, bullet cores, hit-flash frame, HUD text |
| 6 | Warm Cream / Skin | Chibi faces, paper/book pages, light accents |
| 7 | Warm Tan / Wood | Skin shadow, desks, cardboard, warm midtone |
| 8 | Hero Primary Blue | Player accent / UI primary identity |
| 9 | Electric Cyan | Shield, dash trail, player energy bullets, interactive glow |
| 10 | Vivid Green | HP healthy bar, heal items, safe indicators |
| 11 | Warm Gold / Yellow | Coins, badges, hats, warning accents, critical trim |
| 12 | Bright Orange | Fire/accent weapons, urgency highlight, boss charge |
| 13 | Danger Red | Enemy projectiles, low HP, alarm bells, boss enraged state |
| 14 | Deep Crimson | Red shading, dark danger shadow, boss aura base |
| 15 | Soft Lavender / Violet | Tech/magic shade, quiz enemies, night shadow tint |
| 16 | Steel Gray | Laptops, metal weapons, disabled/cooldown states |

## 3. Shading Guidelines at 64x64 Source
- **Light source**: Fixed top-left (approx. 11 o'clock) across all assets.
- **Cluster shading**: Group shading pixels into clean clusters (avoid noisy checkerboard dithering on small moving sprites).
- **Rim light**: Optional 1px bright accent on top edge of heads/weapons to separate from dark floors.
- **Ground shadow**: Shared semi-transparent dark ellipse (`~65%` sprite width, `~20%` sprite height) rendered under feet; never bake heavy opaque shadows into animated sprites that flip or bounce.

## 4. Visual Readability Tests
- **Squint / 50% Zoom Test**: Shrink sprite to `48x48` (or `32x32`). Can you still identify class gear (glasses, goggles, yellow hat) and enemy type (alarm clock, flying envelope, exclamation quiz)?
- **Grayscale Contrast Test**: Convert a screenshot to grayscale. Bullets and actors must clearly separate in value from the floor.
- **Player vs Enemy Bullet Rule**:
  - Player bullets: Cool/bright tones (cyan, white-core, gold, boba brown with bright rim).
  - Enemy bullets: Warm danger tones (bright red/magenta outer rim + pale white-pink core) so players never confuse threats with their own shots.
