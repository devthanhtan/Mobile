#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script sinh toàn bộ Sprite Sheet PNG chuẩn Pixel Art 16 màu cho dự án:
"Sinh Viên HUIT Đánh Quái Deadline" (Deadline Hunter - Flutter + Flame).

Tuân thủ docs/art/style_guide.md:
- Bảng màu giới hạn đúng 16 màu (hex), viền tối 1px (#141526), nền trong suốt RGBA.
- Sprite nguồn 64x64 (vẽ trên lưới logic 32x32 rồi phóng đại 2x bằng NEAREST).
- Boss nguồn 96x96 (vẽ trên lưới logic 48x48 rồi phóng đại 2x bằng NEAREST).
- Sinh cả file *_sheet.png (strip ngang cho SpriteAnimationComponent) lẫn file đơn
  frame 0 (*.png) để tương thích với Image.asset trên HUD/Lobby/StageMap.

Cách chạy:
    pip install pillow
    python tools/generate_sprites.py
"""

from pathlib import Path
from PIL import Image, ImageDraw

# ==============================================================================
# 1. BẢNG MÀU 16 MÀU PIXEL ART CHUẨN (docs/art/style_guide.md)
# ==============================================================================
PALETTE = {
    "ink": (0x14, 0x15, 0x26, 255),          # #1  #141526 Viền tối 1px chung
    "panel_dark": (0x1E, 0x21, 0x3A, 255),   # #2  #1E213A Xanh đen đậm
    "slate_border": (0x4A, 0x55, 0x80, 255), # #3  #4A5580 Xám xanh trung gian
    "steel": (0x7A, 0x86, 0xB6, 255),        # #4  #7A86B6 Thép sáng / kim loại
    "white": (0xF8, 0xFA, 0xFF, 255),        # #5  #F8FAFF Trắng sáng / hit-flash
    "cream": (0xFF, 0xE8, 0xC8, 255),        # #6  #FFE8C8 Da chibi / giấy sách
    "tan": (0xD4, 0x9A, 0x6A, 255),          # #7  #D49A6A Bóng da / trà sữa / gỗ
    "huit_blue": (0x00, 0x5B, 0xAC, 255),    # #8  #005BAC Xanh thương hiệu HUIT
    "cyan": (0x29, 0xE7, 0xFF, 255),         # #9  #29E7FF Cyan kính IT / laser
    "emerald": (0x38, 0xD9, 0x73, 255),      # #10 #38D973 Xanh lá SV Thực Phẩm
    "gold": (0xFF, 0xD5, 0x4F, 255),         # #11 #FFD54F Vàng mũ Kinh tế / xu
    "orange": (0xFF, 0x98, 0x00, 255),       # #12 #FF9800 Cam năng lượng / mì
    "red": (0xFF, 0x3B, 0x5C, 255),          # #13 #FF3B5C Đỏ Deadline / huy hiệu
    "crimson": (0x8E, 0x1B, 0x3A, 255),      # #14 #8E1B3A Đỏ sẫm bóng Boss
    "violet": (0x8F, 0x6B, 0xFF, 255),       # #15 #8F6BFF Tím quái Quiz
    "shadow": (0x09, 0x0A, 0x14, 255),       # #16 #090A14 Đen bóng sâu
}

ROOT_DIR = Path(__file__).resolve().parent.parent
IMAGES_DIR = ROOT_DIR / "assets" / "images"


# ==============================================================================
# 2. HÀM TIỆN ÍCH VẼ PIXEL & TỰ ĐỘNG BO VIỀN 1PX (#141526)
# ==============================================================================
def new_canvas(w: int = 32, h: int = 32) -> Image.Image:
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def apply_1px_outline(img: Image.Image, outline_color=PALETTE["ink"]) -> Image.Image:
    """Bo viền 1px sắc nét theo 4 hướng quanh mọi pixel không trong suốt."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] > 0:
                continue
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0:
                    dst[x, y] = outline_color
                    break
    return out


def make_hit_flash_frame(img: Image.Image) -> Image.Image:
    """Tạo frame hit-flash 100% trắng (#F8FAFF) giữ viền tối 1px để khỏi dùng ColorFilter."""
    w, h = img.size
    src = img.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dst = out.load()
    for y in range(h):
        for x in range(w):
            a = src[x, y][3]
            if a == 0:
                continue
            if src[x, y][:3] == PALETTE["ink"][:3]:
                dst[x, y] = PALETTE["ink"]
            else:
                dst[x, y] = PALETTE["white"]
    return out


def make_death_frames(base_img: Image.Image, count: int = 4) -> list[Image.Image]:
    """Sinh chuỗi frame death: nghiêng -> thu nhỏ chớp trắng -> vỡ hạt pixel."""
    w, h = base_img.size
    frames = []
    for i in range(count):
        t = (i + 1) / count
        canvas = new_canvas(w, h)
        draw = ImageDraw.Draw(canvas)
        if i == 0:
            shifted = base_img.rotate(-12, resample=Image.Resampling.NEAREST)
            canvas.alpha_composite(shifted, (0, 1))
        elif i == 1:
            flash = make_hit_flash_frame(base_img)
            sw, sh = max(8, int(w * 0.78)), max(8, int(h * 0.78))
            small = flash.resize((sw, sh), resample=Image.Resampling.NEAREST)
            canvas.alpha_composite(small, ((w - sw) // 2, (h - sh) // 2 + 2))
        else:
            # Vòng hạt pixel tan rã
            cx, cy = w // 2, h // 2 + 2
            radius = int(4 + t * (w * 0.28))
            offsets = [
                (-radius, -radius // 2),
                (radius, -radius // 2),
                (-radius // 2, radius // 2),
                (radius // 2, radius // 2),
                (0, -radius),
                (0, radius),
            ]
            color = PALETTE["cyan"] if i % 2 == 0 else PALETTE["gold"]
            for ox, oy in offsets:
                px, py = cx + ox, cy + oy
                size = 2 if i < count - 1 else 1
                draw.rectangle([px, py, px + size, py + size], fill=color)
            canvas = apply_1px_outline(canvas)
        frames.append(canvas)
    return frames


def upscale_nearest(img: Image.Image, target_size: int) -> Image.Image:
    return img.resize((target_size, target_size), resample=Image.Resampling.NEAREST)


def save_strip_and_preview(
    frames_logical: list[Image.Image],
    out_sheet_path: Path,
    out_single_path: Path,
    cell_size: int = 64,
) -> None:
    """Lưu strip ngang (*_sheet.png) và ảnh đơn frame 0 (*.png)."""
    out_sheet_path.parent.mkdir(parents=True, exist_ok=True)
    upscaled = [upscale_nearest(f, cell_size) for f in frames_logical]
    sheet = Image.new("RGBA", (cell_size * len(upscaled), cell_size), (0, 0, 0, 0))
    for idx, frame in enumerate(upscaled):
        sheet.paste(frame, (idx * cell_size, 0))
    sheet.save(out_sheet_path, "PNG")
    upscaled[0].save(out_single_path, "PNG")


# ==============================================================================
# 3. A. NHÂN VẬT CHIBI (3 CLASS: SV IT, SV THỰC PHẨM, SV KINH TẾ) — 64x64
#    idle 4f + walk 4f + hit 1f + death 4f = 13 frames
# ==============================================================================
def draw_chibi_student_frame(
    class_id: str,
    bob_y: int = 0,
    left_foot_dy: int = 0,
    right_foot_dy: int = 0,
    arm_swing: int = 0,
) -> Image.Image:
    img = new_canvas(32, 32)
    d = ImageDraw.Draw(img)

    if class_id == "it":
        shirt = PALETTE["huit_blue"]
        trim = PALETTE["cyan"]
        hair = PALETTE["panel_dark"]
    elif class_id == "food":
        shirt = PALETTE["emerald"]
        trim = PALETTE["white"]
        hair = PALETTE["tan"]
    else:  # eco
        shirt = PALETTE["panel_dark"]
        trim = PALETTE["gold"]
        hair = PALETTE["crimson"]

    # Chân (walk cycle)
    d.rectangle([11, 24 + left_foot_dy, 14, 27 + left_foot_dy], fill=PALETTE["panel_dark"])
    d.rectangle([17, 24 + right_foot_dy, 20, 27 + right_foot_dy], fill=PALETTE["panel_dark"])

    # Thân áo chibi
    by = 16 + bob_y
    d.rectangle([10, by, 21, by + 8], fill=shirt)
    d.rectangle([14, by, 17, by + 8], fill=trim)
    # Tay
    d.rectangle([8, by + 2 + arm_swing, 9, by + 6 + arm_swing], fill=shirt)
    d.rectangle([22, by + 2 - arm_swing, 23, by + 6 - arm_swing], fill=shirt)
    d.point((8, by + 6 + arm_swing), fill=PALETTE["cream"])
    d.point((23, by + 6 - arm_swing), fill=PALETTE["cream"])

    # Đầu chibi lớn (tỷ lệ ~50% thân)
    hy = 6 + bob_y
    d.rectangle([9, hy, 22, hy + 10], fill=PALETTE["cream"])
    d.rectangle([9, hy + 8, 22, hy + 10], fill=PALETTE["tan"])  # Bóng cằm
    # Tóc
    d.rectangle([9, hy - 1, 22, hy + 2], fill=hair)
    d.rectangle([8, hy, 10, hy + 5], fill=hair)

    # Mắt hướng sang phải (hướng trái sẽ lật ngang trong Flame)
    d.rectangle([13, hy + 4, 14, hy + 6], fill=PALETTE["ink"])
    d.rectangle([19, hy + 4, 20, hy + 6], fill=PALETTE["ink"])
    d.point((13, hy + 4), fill=PALETTE["white"])
    d.point((19, hy + 4), fill=PALETTE["white"])

    # Phụ kiện đặc trưng từng khoa
    if class_id == "it":
        # Kính cận gọng vuông xanh cyan phản sáng
        d.rectangle([12, hy + 3, 15, hy + 7], outline=PALETTE["cyan"])
        d.rectangle([18, hy + 3, 21, hy + 7], outline=PALETTE["cyan"])
        d.line([16, hy + 5, 17, hy + 5], fill=PALETTE["cyan"])
    elif class_id == "food":
        # Kính bảo hộ phòng Lab bản rộng + mũ trùm sạch
        d.rectangle([9, hy - 2, 22, hy + 1], fill=PALETTE["white"])
        d.rectangle([11, hy + 3, 21, hy + 7], outline=PALETTE["emerald"])
        d.point((12, hy + 4), fill=PALETTE["white"])
    else:
        # Mũ vàng SV Kinh tế + cà vạt vàng
        d.rectangle([8, hy - 3, 23, hy], fill=PALETTE["gold"])
        d.rectangle([10, hy - 5, 21, hy - 3], fill=PALETTE["gold"])
        d.rectangle([10, hy - 1, 21, hy], fill=PALETTE["orange"])

    return apply_1px_outline(img)


def generate_players() -> None:
    for cid in ("it", "food", "eco"):
        idle = [
            draw_chibi_student_frame(cid, bob_y=0),
            draw_chibi_student_frame(cid, bob_y=1),
            draw_chibi_student_frame(cid, bob_y=0),
            draw_chibi_student_frame(cid, bob_y=-1),
        ]
        walk = [
            draw_chibi_student_frame(cid, bob_y=-1, left_foot_dy=-1, right_foot_dy=1, arm_swing=-1),
            draw_chibi_student_frame(cid, bob_y=0, left_foot_dy=0, right_foot_dy=0, arm_swing=0),
            draw_chibi_student_frame(cid, bob_y=-1, left_foot_dy=1, right_foot_dy=-1, arm_swing=1),
            draw_chibi_student_frame(cid, bob_y=0, left_foot_dy=0, right_foot_dy=0, arm_swing=0),
        ]
        hit = [make_hit_flash_frame(idle[0])]
        death = make_death_frames(idle[0], count=4)
        all_frames = idle + walk + hit + death
        save_strip_and_preview(
            all_frames,
            IMAGES_DIR / "player" / f"player_{cid}_sheet.png",
            IMAGES_DIR / "player" / f"player_{cid}.png",
            cell_size=64,
        )


# ==============================================================================
# 4. B. QUÁI THƯỜNG (DEADLINE, EMAIL, QUIZ — 9 frames) & BOSS (19 frames, 96x96)
# ==============================================================================
def draw_enemy_frame(kind: str, frame_idx: int) -> Image.Image:
    img = new_canvas(32, 32)
    d = ImageDraw.Draw(img)
    bob = -1 if frame_idx % 2 == 1 else 0

    if kind == "deadline":
        # Đồng hồ báo thức đỏ + 2 chuông vàng rung lắc trên đầu
        bell_shift = -1 if frame_idx % 2 == 0 else 1
        d.rectangle([7 + bell_shift, 4 + bob, 11 + bell_shift, 7 + bob], fill=PALETTE["gold"])
        d.rectangle([20 - bell_shift, 4 + bob, 24 - bell_shift, 7 + bob], fill=PALETTE["gold"])
        d.ellipse([7, 8 + bob, 24, 25 + bob], fill=PALETTE["red"])
        d.ellipse([10, 11 + bob, 21, 22 + bob], fill=PALETTE["cream"])
        # Kim đồng hồ + mắt giận
        d.line([16, 16 + bob, 16, 12 + bob], fill=PALETTE["ink"])
        d.line([16, 16 + bob, 20, 16 + bob], fill=PALETTE["crimson"])
        d.rectangle([12, 14 + bob, 13, 16 + bob], fill=PALETTE["ink"])
        d.rectangle([18, 14 + bob, 19, 16 + bob], fill=PALETTE["ink"])
    elif kind == "email":
        # Phong bì bay vẫy cánh + huy hiệu chấm đỏ thông báo
        wing_y = 10 if frame_idx == 0 else (13 if frame_idx == 1 else (16 if frame_idx == 2 else 13))
        d.rectangle([3, wing_y, 7, wing_y + 4], fill=PALETTE["cyan"])
        d.rectangle([24, wing_y, 28, wing_y + 4], fill=PALETTE["cyan"])
        d.rectangle([7, 10 + bob, 24, 22 + bob], fill=PALETTE["cream"])
        d.line([7, 10 + bob, 15, 16 + bob], fill=PALETTE["slate_border"])
        d.line([24, 10 + bob, 16, 16 + bob], fill=PALETTE["slate_border"])
        # Huy hiệu đỏ góc phải trên
        badge_r = 4 if frame_idx % 2 == 0 else 3
        d.ellipse([21 - badge_r, 7 + bob, 21 + badge_r, 7 + bob + badge_r * 2], fill=PALETTE["red"])
        d.point((21, 9 + bob), fill=PALETTE["white"])
    else:  # quiz
        # Đề thi tím lao nhanh + dấu chấm than ! nhấp nháy
        lean = 1 if frame_idx % 2 == 1 else 0
        d.rectangle([8 + lean, 6 + bob, 23 + lean, 25 + bob], fill=PALETTE["violet"])
        d.rectangle([10 + lean, 8 + bob, 21 + lean, 23 + bob], fill=PALETTE["panel_dark"])
        excl_color = PALETTE["gold"] if frame_idx % 2 == 0 else PALETTE["red"]
        d.rectangle([15 + lean, 10 + bob, 17 + lean, 17 + bob], fill=excl_color)
        d.rectangle([15 + lean, 19 + bob, 17 + lean, 21 + bob], fill=excl_color)

    return apply_1px_outline(img)


def draw_boss_frame(boss_id: str, state: str, frame_idx: int) -> Image.Image:
    """Boss nguồn 96x96 (vẽ trên lưới logic 48x48)."""
    img = new_canvas(48, 48)
    d = ImageDraw.Draw(img)
    enraged = state == "phase2"
    attacking = state == "attack"
    bob = (-2 if frame_idx >= 2 else 2) if attacking else (-1 if frame_idx % 2 == 1 else 0)

    body_main = PALETTE["crimson"] if enraged else PALETTE["panel_dark"]
    accent = PALETTE["red"] if enraged else (PALETTE["orange"] if attacking else PALETTE["gold"])

    # Sừng Boss (phase 2 sừng đỏ rực sáng)
    horn_color = PALETTE["red"] if enraged else PALETTE["steel"]
    d.polygon([(8, 14 + bob), (4, 4 + bob), (14, 10 + bob)], fill=horn_color)
    d.polygon([(39, 14 + bob), (43, 4 + bob), (33, 10 + bob)], fill=horn_color)
    if enraged:
        d.point((5, 5 + bob), fill=PALETTE["white"])
        d.point((42, 5 + bob), fill=PALETTE["white"])

    # Thân Sách Đề Thi Cuối Kỳ / Boss khổng lồ
    d.rectangle([8, 10 + bob, 39, 39 + bob], fill=body_main)
    d.rectangle([11, 13 + bob, 36, 36 + bob], fill=PALETTE["cream"] if boss_id == "final_exam" else PALETTE["slate_border"])

    # Con dấu điểm F đỏ rực & mắt Boss
    d.rectangle([15, 17 + bob, 20, 22 + bob], fill=PALETTE["ink"])
    d.rectangle([27, 17 + bob, 32, 22 + bob], fill=PALETTE["ink"])
    eye_glow = PALETTE["red"] if (enraged or attacking) else PALETTE["gold"]
    d.rectangle([17, 18 + bob, 19, 20 + bob], fill=eye_glow)
    d.rectangle([28, 18 + bob, 30, 20 + bob], fill=eye_glow)

    # Dấu "F" / miệng gầm khi tung chiêu
    d.rectangle([18, 26 + bob, 29, 33 + bob], fill=accent)
    d.line([21, 27 + bob, 21, 32 + bob], fill=PALETTE["white"])
    d.line([21, 27 + bob, 26, 27 + bob], fill=PALETTE["white"])
    d.line([21, 29 + bob, 25, 29 + bob], fill=PALETTE["white"])

    return apply_1px_outline(img)


def generate_enemies_and_bosses() -> None:
    for kind in ("deadline", "email", "quiz"):
        move = [draw_enemy_frame(kind, i) for i in range(4)]
        hit = [make_hit_flash_frame(move[0])]
        death = make_death_frames(move[0], count=4)
        save_strip_and_preview(
            move + hit + death,
            IMAGES_DIR / "enemy" / f"enemy_{kind}_sheet.png",
            IMAGES_DIR / "enemy" / f"enemy_{kind}.png",
            cell_size=64,
        )

    for boss_id in ("final_exam", "dragon_dean", "blueprint", "golem"):
        idle = [draw_boss_frame(boss_id, "idle", i) for i in range(4)]
        attack = [draw_boss_frame(boss_id, "attack", i) for i in range(4)]
        phase2 = [draw_boss_frame(boss_id, "phase2", i) for i in range(4)]
        death = make_death_frames(idle[0], count=6)
        hit = [make_hit_flash_frame(idle[0])]
        save_strip_and_preview(
            idle + attack + phase2 + death + hit,
            IMAGES_DIR / "enemy" / f"boss_{boss_id}_sheet.png",
            IMAGES_DIR / "enemy" / f"boss_{boss_id}.png",
            cell_size=96,
        )


# ==============================================================================
# 5. C. VẬT PHẨM RƠI (CÀ PHÊ, MÌ GÓI, KHIÊN, XU) — 4 FRAME NHẤP NHÔ + LẤP LÁNH
# ==============================================================================
def draw_item_frame(kind: str, frame_idx: int) -> Image.Image:
    img = new_canvas(32, 32)
    d = ImageDraw.Draw(img)
    bob = -1 if frame_idx == 1 else (1 if frame_idx == 3 else 0)

    if kind == "coffee":
        d.rectangle([10, 11 + bob, 20, 24 + bob], fill=PALETTE["tan"])
        d.rectangle([10, 15 + bob, 20, 19 + bob], fill=PALETTE["cream"])
        d.rectangle([9, 9 + bob, 21, 11 + bob], fill=PALETTE["white"])
    elif kind == "noodle":
        d.rectangle([9, 12 + bob, 22, 24 + bob], fill=PALETTE["red"])
        d.rectangle([9, 15 + bob, 22, 18 + bob], fill=PALETTE["gold"])
        d.rectangle([11, 10 + bob, 20, 12 + bob], fill=PALETTE["cream"])
    elif kind == "shield":
        d.polygon(
            [(16, 7 + bob), (23, 11 + bob), (21, 21 + bob), (16, 25 + bob), (11, 21 + bob), (9, 11 + bob)],
            fill=PALETTE["huit_blue"],
        )
        d.polygon(
            [(16, 9 + bob), (21, 12 + bob), (19, 19 + bob), (16, 22 + bob), (13, 19 + bob), (11, 12 + bob)],
            fill=PALETTE["cyan"],
        )
    else:  # coin
        d.ellipse([9, 9 + bob, 22, 22 + bob], fill=PALETTE["gold"])
        d.ellipse([11, 11 + bob, 20, 20 + bob], fill=PALETTE["orange"])
        d.rectangle([15, 13 + bob, 16, 18 + bob], fill=PALETTE["white"])

    # Hạt sao 4 cánh lấp lánh đổi góc theo frame
    sparkle_coords = [(6, 7), (24, 8), (24, 23), (7, 23)]
    sx, sy = sparkle_coords[frame_idx % 4]
    d.point((sx, sy), fill=PALETTE["white"])
    d.point((sx - 1, sy), fill=PALETTE["gold"])
    d.point((sx + 1, sy), fill=PALETTE["gold"])
    d.point((sx, sy - 1), fill=PALETTE["gold"])
    d.point((sx, sy + 1), fill=PALETTE["gold"])

    return apply_1px_outline(img)


def generate_items() -> None:
    for kind in ("coffee", "noodle", "shield", "coin"):
        frames = [draw_item_frame(kind, i) for i in range(4)]
        save_strip_and_preview(
            frames,
            IMAGES_DIR / "item" / f"item_{kind}_sheet.png",
            IMAGES_DIR / "item" / f"item_{kind}.png",
            cell_size=64,
        )


# ==============================================================================
# 6. E. 5 VŨ KHÍ RIÊNG & HOẠT ẢNH ĐẠN / VỆT CHÉM (64x64)
# ==============================================================================
def generate_weapons() -> None:
    w_dir = IMAGES_DIR / "weapon"
    w_dir.mkdir(parents=True, exist_ok=True)

    # 1. Bút bi (weapon_pen.png) + đạn mực 3 frame (proj_pen_sheet.png)
    pen = new_canvas(32, 32)
    d = ImageDraw.Draw(pen)
    d.rectangle([6, 14, 22, 17], fill=PALETTE["huit_blue"])
    d.rectangle([10, 14, 18, 15], fill=PALETTE["cyan"])
    d.polygon([(22, 14), (27, 15), (22, 17)], fill=PALETTE["white"])
    upscale_nearest(apply_1px_outline(pen), 64).save(w_dir / "weapon_pen.png", "PNG")

    pen_bullets = []
    for i in range(3):
        bf = new_canvas(32, 32)
        bd = ImageDraw.Draw(bf)
        tail = 6 + i * 2
        bd.rectangle([14 - tail, 15, 16, 17], fill=PALETTE["huit_blue"])
        bd.ellipse([14, 13, 21, 19], fill=PALETTE["cyan"])
        bd.ellipse([17, 15, 19, 17], fill=PALETTE["white"])
        pen_bullets.append(apply_1px_outline(bf))
    save_strip_and_preview(pen_bullets, w_dir / "proj_pen_sheet.png", w_dir / "proj_pen.png", 64)

    # 2. Laptop (weapon_laptop.png)
    laptop = new_canvas(32, 32)
    d = ImageDraw.Draw(laptop)
    d.rectangle([8, 9, 23, 18], fill=PALETTE["panel_dark"])
    d.rectangle([10, 11, 21, 16], fill=PALETTE["cyan"])
    d.rectangle([6, 19, 25, 22], fill=PALETTE["steel"])
    upscale_nearest(apply_1px_outline(laptop), 64).save(w_dir / "weapon_laptop.png", "PNG")

    # 3. USB Shuriken (weapon_usb.png) + 4 frame xoay (proj_usb_sheet.png)
    usb_frames = []
    base_usb = new_canvas(32, 32)
    d = ImageDraw.Draw(base_usb)
    d.rectangle([8, 12, 19, 19], fill=PALETTE["gold"])
    d.rectangle([20, 13, 25, 18], fill=PALETTE["steel"])
    d.point((22, 14), fill=PALETTE["ink"])
    d.point((22, 17), fill=PALETTE["ink"])
    outlined_usb = apply_1px_outline(base_usb)
    for i in range(4):
        usb_frames.append(outlined_usb.rotate(-90 * i, resample=Image.Resampling.NEAREST))
    save_strip_and_preview(usb_frames, w_dir / "proj_usb_sheet.png", w_dir / "weapon_usb.png", 64)

    # 4. Trà sữa (weapon_boba.png) + đạn trân châu (proj_boba_sheet.png)
    boba = new_canvas(32, 32)
    d = ImageDraw.Draw(boba)
    d.rectangle([10, 11, 21, 24], fill=PALETTE["tan"])
    d.rectangle([9, 9, 22, 11], fill=PALETTE["cream"])
    d.rectangle([15, 5, 17, 11], fill=PALETTE["emerald"])
    d.ellipse([12, 20, 14, 22], fill=PALETTE["ink"])
    d.ellipse([17, 20, 19, 22], fill=PALETTE["ink"])
    upscale_nearest(apply_1px_outline(boba), 64).save(w_dir / "weapon_boba.png", "PNG")

    boba_bullets = []
    for i in range(3):
        bf = new_canvas(32, 32)
        bd = ImageDraw.Draw(bf)
        by = -1 if i == 1 else (1 if i == 2 else 0)
        bd.ellipse([11, 11 + by, 20, 20 + by], fill=PALETTE["panel_dark"])
        bd.ellipse([13, 12 + by, 16, 15 + by], fill=PALETTE["tan"])
        bd.point((14, 13 + by), fill=PALETTE["white"])
        boba_bullets.append(apply_1px_outline(bf))
    save_strip_and_preview(boba_bullets, w_dir / "proj_boba_sheet.png", w_dir / "proj_boba.png", 64)

    # 5. Giáo trình cận chiến (weapon_textbook.png) + 4 frame vung cung tròn
    book = new_canvas(32, 32)
    d = ImageDraw.Draw(book)
    d.rectangle([8, 7, 23, 24], fill=PALETTE["huit_blue"])
    d.rectangle([8, 7, 11, 24], fill=PALETTE["gold"])
    d.rectangle([13, 10, 20, 15], fill=PALETTE["cream"])
    d.rectangle([21, 8, 23, 23], fill=PALETTE["cream"])
    upscale_nearest(apply_1px_outline(book), 64).save(w_dir / "weapon_textbook.png", "PNG")

    slash_frames = []
    for i in range(4):
        sf = new_canvas(32, 32)
        sd = ImageDraw.Draw(sf)
        start_deg = -65 + i * 18
        end_deg = start_deg + 75
        sd.arc([4, 4, 28, 28], start=start_deg, end=end_deg, fill=PALETTE["gold"], width=3)
        sd.arc([6, 6, 26, 26], start=start_deg, end=end_deg, fill=PALETTE["white"], width=2)
        slash_frames.append(apply_1px_outline(sf))
    save_strip_and_preview(
        slash_frames,
        w_dir / "fx_textbook_slash_sheet.png",
        w_dir / "fx_textbook_slash.png",
        64,
    )


def main() -> None:
    print("Đang sinh toàn bộ sprite sheet pixel art 16 màu vào assets/images/...")
    generate_players()
    generate_enemies_and_bosses()
    generate_items()
    generate_weapons()
    print("Hoàn tất! Toàn bộ PNG 64x64 & Boss 96x96 đã được cập nhật.")


if __name__ == "__main__":
    main()
