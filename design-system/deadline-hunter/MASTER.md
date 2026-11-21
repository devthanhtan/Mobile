# Deadline Hunter — Design System Master (`HUIT Survival 2D`)

> Tài liệu hệ thống thiết kế tổng hợp từ bộ skill thiết kế game 2D pixel art trong `.agents/skills/` (`pixel-art-direction`, `pixel-sprite-animation`, `pixel-game-hud-ui`, `pixel-game-vfx-feel`).
> Áp dụng cho dự án **Sinh Viên HUIT Đánh Quái Deadline** (`Flutter + Flame`, màn hình ngang *Landscape*).

---

## 1. Định vị phong cách (Visual Identity)

- **Thể loại**: Top-down 2D Action Roguelite (*Soul Knight-like*), sinh tồn 05:00 → đấu Boss.
- **Chủ đề**: Sinh viên HUIT (IT, Thực Phẩm, Kinh Tế) chiến đấu chống lại Deadline, Email, Quiz và Boss Kỳ Thi.
- **Phong cách mỹ thuật**: **Retro Cute Chibi Pixel Art** — sắc nét (`FilterQuality.none`), bảng màu giới hạn **16 màu**, viền tối **1px** đồng nhất (`#141526`), độ tương phản rõ giữa 4 tầng hình ảnh:
  1. **Sàn đấu trường** (tương phản thấp nhất, không viền đen gắt).
  2. **Nhân vật, Quái, Boss** (chibi dễ nhận diện qua silhouette, có bóng chân mềm).
  3. **Đạn, Laser, Telegraph, Vật phẩm** (độ bão hòa và độ sáng cao nhất).
  4. **HUD & Menu Pixel** (nền tối bán trong suốt `#141526`, viền pixel `2px`, bóng cứng không blur).

---

## 2. Hệ thống màu chuẩn (16-Color Master Palette)

| # | Token (`GameConstants`) | Mã Hex | Vai trò thiết kế |
|---|---|---|---|
| 1 | `pixelInk` / `backgroundColor` | `#141526` | Viền tối 1px cho mọi sprite, nền tối sâu |
| 2 | `pixelPanelDark` / `cardColor` | `#1E213A` | Nền hộp thoại, bảng HUD, gạch sàn đậm |
| 3 | `pixelPanelBorder` / `cardBorderColor` | `#4A5580` | Viền khung pixel 2px, chi tiết sàn |
| 4 | `pixelSlate` | `#7A86B6` | Trạng thái khóa/cooldown, kim loại, text phụ |
| 5 | `pixelWhite` | `#F8FAFF` | Chữ chính HUD (tương phản > 13:1 trên `#141526`), lõi đạn, frame hit-flash |
| 6 | `pixelCream` | `#FFE8C8` | Da chibi, trang sách giáo trình, highlight ấm |
| 7 | `pixelTan` | `#D49A6A` | Bóng da, nội thất gỗ giảng đường, trà sữa |
| 8 | `primaryColor` (`pixelHuitBlue`) | `#005BAC` | Xanh thương hiệu HUIT, đồng phục, badge slot |
| 9 | `dashCyanColor` (`pixelCyan`) | `#29E7FF` | Kỹ năng Dash 8s, khiên, đạn năng lượng/laser |
| 10 | `hudHpHealthyColor` (`pixelEmerald`) | `#38D973` | Thanh HP an toàn (`> 35%`), hiệu ứng hồi máu |
| 11 | `hudGoldColor` (`pixelGold`) | `#FFD54F` | Xu, mũ SV Kinh tế, đồng hồ sinh tồn, tiêu đề Boss |
| 12 | `accentColor` (`pixelOrange`) | `#FF9800` | CTA chính (`CHƠI`, `TIẾP TỤC`, `CHƠI LẠI`), điểm nhấn HUIT |
| 13 | `hudDangerColor` (`pixelDangerRed`) | `#FF3B5C` | HP thấp (`<= 35%`), thanh máu Boss, đạn quái, cảnh báo 30s cuối |
| 14 | `hudBossPanelBg` (`pixelDeepCrimson`) | `#8E1B3A` | Nền/bóng cảnh báo Boss & pha cuồng nộ |
| 15 | `pixelViolet` | `#8F6BFF` | Bóng tím lạnh (hue-shifting), quái Quiz |
| 16 | `pixelShadowBlack` | `#090A14` | Bóng cứng pixel UI `Offset(2, 2)` (`blurRadius: 0`) & bóng chân |

---

## 3. Hệ thống chữ (Pixel Typography & Tiếng Việt)

- **Google Fonts khuyến nghị**:
  - **Chính (hỗ trợ đầy đủ dấu tiếng Việt)**: **`Pixelify Sans`** — giữ nét khối pixel mà không vỡ dấu tiếng Việt.
  - **Số liệu / Nhãn Arcade ASCII** (`05:00`, `100/100`, `1-1`, `DASH`): **`Press Start 2P`** hoặc **`Silkscreen`** hoặc **`VT323`**.
- **Chính sách hiện tại trong code (không tự cài thêm package)**:
  - Dùng `GameConstants.pixelFontFamily = 'monospace'` kết hợp `FontFeature.tabularFigures()` cho toàn bộ đồng hồ, HP, Xu, Kill và bộ đếm hồi chiêu Dash để các con số không bị giật ngang khi thay đổi.
  - Khi cần bật Google Fonts sau này, chỉ cần thêm `google_fonts` vào `pubspec.yaml` (hoặc nhúng file `PixelifySans.ttf` vào `assets/fonts/`) và cập nhật 1 chỗ duy nhất tại `GameConstants.pixelFontFamily`.

---

## 4. Quy chuẩn HUD & Ergonomics cho Mobile Landscape (Flutter)

### Kích thước vùng chạm (Touch Targets)
- **Tối thiểu bắt buộc**: **`48 x 48 dp`** cho mọi nút bấm (Cài đặt âm thanh, Tạm dừng, nút trong hộp thoại Pause/Win/Lose).
- **Khoảng cách giữa các nút cạnh nhau**: tối thiểu **`8–12 dp`**.
- **Chiều cao vùng HUD trên cùng**: giữ gọn dưới `14%` chiều cao màn hình, giữ khoảng giữa trống trong suốt 5 phút sinh tồn (chỉ hiện thanh máu Boss khi vào pha Boss).

### Thông số cụm điều khiển (đồng bộ trong `lib/constants.dart`)

| Thành phần | Token `GameConstants` | Kích thước | Ghi chú |
|---|---|---|---|
| Virtual Joystick (trái dưới) | `hudJoystickSize` / `hudJoystickKnobRadius` | `124 dp` / knob `22 dp` | Vòng viền pixel rõ nét khi kéo |
| Nút Bắn + Kéo ngắm (phải dưới) | `hudShootButtonSize` | `104 dp` | Nút lớn nhất cho ngón cái phải |
| Nút Dash 8s | `hudDashButtonSize` | `74 dp` | Viền cyan khi sẵn sàng, phủ quạt tối + số giây khi hồi |
| Nút Đổi vũ khí (Slot 1/2) | `hudWeaponSwitchButtonSize` | `66 dp` | Sprite `FilterQuality.none` + badge số slot |
| Nút Tương tác Sảnh chờ | `hudLobbyInteractButtonSize` | `92 dp` | Đổi màu theo mục tiêu (Cổng / Đồng đội / Lướt) |
| Nút Cài đặt / Tạm dừng | `hudMinTouchTarget` | `48 x 48 dp` | Khung vuông bo góc pixel `6 dp`, viền `2 px` |
| Nút Modal (`VỀ SẢNH` / `TIẾP TỤC`) | `hudModalButtonHeight` | cao `48 dp` | Đạt chuẩn chạm `>= 48 dp` |

### Quy tắc khung Pixel UI
- Bo góc nhỏ gọn (`6–8 dp`), viền solid `2.0 px` (`GameConstants.hudBorderWidth`).
- Dùng bóng cứng pixel `Offset(2, 2)` với **`blurRadius: 0`** thay cho `blurRadius: 12–20` để vừa đúng chất retro vừa giảm tải raster GPU trên điện thoại tầm trung.

---

## 5. Ngân sách hiệu năng gắn với thiết kế (60 FPS Contract)

- Mọi sprite sử dụng `FilterQuality.none`, nạp sẵn một lần trong `onLoad()`.
- Hạn chế tối đa `BackdropFilter` và `BoxShadow` có blur lớn trên HUD chiến đấu.
- Tách lớp cập nhật HUD khỏi vòng lặp 60 FPS (nhiệm vụ 2 sẽ bổ sung `RepaintBoundary` và lượng tử hóa notifier).
