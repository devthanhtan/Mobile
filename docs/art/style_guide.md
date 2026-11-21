# Art Style Guide — Deadline Hunter (`HUIT Survival 2D`)

Tài liệu quy chuẩn đồ họa pixel art và giao diện HUD/Menu cho dự án **Sinh Viên HUIT Đánh Quái Deadline**. Mọi sprite (Nhiệm vụ 3), bản đồ và giao diện Flutter (Nhiệm vụ 1) phải tuân thủ tài liệu này để giữ sự đồng nhất và dễ nhìn ở 60 FPS trên màn hình điện thoại.

---

## 1. Bảng màu chuẩn Pixel Art (Tối đa 16 màu)

Toàn bộ nhân vật, quái, Boss, vật phẩm, hiệu ứng và UI đều trích xuất từ **16 màu cốt lõi** dưới đây theo nguyên tắc *hue-shifting* (sáng ngả vàng ấm, tối ngả xanh/tím lạnh):

| # | Tên màu | Mã Hex | Ứng dụng cụ thể |
|---:|---|---|---|
| 1 | **Deep Ink Outline** | `#141526` | **Màu viền chung 1px** cho toàn bộ sprite; nền màn hình tối |
| 2 | **Dark Indigo Surface** | `#1E213A` | Nền bảng HUD/menu, nền sàn đấu tối |
| 3 | **Pixel Slate Border** | `#4A5580` | Viền khung UI 2px, đường kẻ gạch sàn |
| 4 | **Cool Steel** | `#7A86B6` | Trạng thái cooldown, thân Laptop/USB, chữ phụ |
| 5 | **Pure Pixel White** | `#F8FAFF` | Chữ chính HUD, phản quang mắt kính, lõi đạn, **frame hit-flash** |
| 6 | **Warm Chibi Cream** | `#FFE8C8` | Da mặt chibi, trang giấy giáo trình, viền sáng ấm |
| 7 | **Campus Wood Tan** | `#D49A6A` | Bóng da, bàn ghế giảng đường, ly trà sữa |
| 8 | **HUIT Primary Blue** | `#005BAC` | Đồng phục HUIT, áo SV IT, màu chủ đạo thương hiệu |
| 9 | **Electric Dash Cyan** | `#29E7FF` | Tia Dash, vòng khiên, tia laser Laptop, đạn mực sáng |
| 10 | **Vital Emerald** | `#38D973` | Thanh máu an toàn (`>35%`), áo bảo hộ SV Thực Phẩm, hồi máu |
| 11 | **Deadline Gold** | `#FFD54F` | Mũ vàng SV Kinh Tế, đồng xu, đồng hồ `05:00`, chữ cảnh báo |
| 12 | **HUIT Accent Orange** | `#FF9800` | Nút hành động chính (`CHƠI`, `TIẾP TỤC`), ánh sáng mì gói |
| 13 | **Danger Crimson** | `#FF3B5C` | Đạn quái/Boss, thanh máu nguy kịch (`<=35%`), chuông Deadline, huy hiệu Email |
| 14 | **Dark Boss Crimson** | `#8E1B3A` | Bóng đỏ đậm, nền thanh máu Boss, sừng Boss pha cuồng nộ |
| 15 | **Quiz Violet** | `#8F6BFF` | Màu nhấn quái Quiz, bóng lạnh cho khối tối |
| 16 | **Hard Shadow Ink** | `#090A14` | Bóng cứng pixel UI `Offset(2, 2)` và bóng đổ dưới chân (`alpha 0.35`) |

---

## 2. Quy tắc vẽ Sprite Pixel Art

### 2.1. Màu viền chung & Quy tắc viền 1px
- **Màu viền chung**: `#141526` (*Deep Ink Outline*) dùng thống nhất cho nhân vật, quái, Boss, vật phẩm và vũ khí.
- **Độ dày viền**: Đúng **1px** ở lưới logic (tức 1px sắc nét bao quanh toàn bộ đường bao ngoài bằng kết nối 4 hướng trên/dưới/trái/phải; không dùng anti-aliasing hay viền mờ).
- **Sàn đấu trường**: Không vẽ viền tối `#141526` cho gạch nền đi bộ để nhân vật và đạn luôn nổi bật.
- **Không mixed-pixel (mixels)**: Mọi tài nguyên đều vẽ cùng mật độ pixel và hiển thị bằng `FilterQuality.none` (Nearest-Neighbor).

### 2.2. Ánh sáng & Bóng đổ
- **Hướng sáng cố định**: Từ góc trên-trái (~11 giờ) xuyên suốt tất cả sprite.
- **Tô bóng dạng mảng (Cluster Shading)**: Nhóm pixel bóng thành mảng gọn, tránh chấm rải rác gây nhiễu khi sprite di chuyển nhanh.
- **Bóng đổ dưới chân (Ground Shadow)**:
  - Không vẽ cứng bóng đen đậm dính vào từng frame chạy/nhún của sprite.
  - Dùng một sprite bóng hình elip dẹt chung (`#090A14`, độ mờ `alpha = 0.35`, rộng ~65% bề ngang sprite, cao ~10px cho nhân vật/quái và ~24px cho Boss) đặt cố định ngay dưới chân.
- **Hiệu ứng trúng đòn (Hit Flash)**:
  - Dựng sẵn **1 frame màu trắng `#F8FAFF`** trong sprite sheet thay vì áp `ColorFilter` động lúc chạy (tránh gọi `saveLayer` gây tụt FPS).

### 2.3. Tỷ lệ Chibi & Nhận diện hình dáng (Silhouette)
- Góc nhìn **3/4 từ trên xuống**, đầu chiếm ~45–55% chiều cao để phụ kiện nhận diện rõ ngay cả khi thu về `48x48`:
  - **SV IT**: Áo xanh HUIT `#005BAC` + **kính cận gọng vuông** phản sáng `#29E7FF`.
  - **SV Thực Phẩm**: Áo blouse/xanh lá `#38D973` + **kính bảo hộ phòng thí nghiệm** nổi bật.
  - **SV Kinh Tế**: Vest tối gọn + **mũ vàng `#FFD54F`** dễ phân biệt từ xa.
- **Quái thường**:
  - **Deadline**: Đồng hồ báo thức có 2 chuông trên đầu rung lắc liên tục.
  - **Email**: Phong bì trắng/kem có cánh vẫy + chấm tròn đỏ thông báo `#FF3B5C`.
  - **Quiz**: Tờ đề kiểm tra màu tím `#8F6BFF` + dấu `!` vàng/đỏ nhấp nháy.
- **Hướng nhân vật**: Toàn bộ sprite mặc định quay sang **phải**; khi di chuyển hoặc ngắm sang trái chỉ lật ngang (`scale.x = -1.0`), không tạo sprite riêng cho hướng trái.

---

## 3. Kích thước Sprite & Hitbox

| Loại đối tượng | Sprite nguồn (PNG) | Hiển thị chuẩn | Tỷ lệ Hitbox | Ghi chú |
|---|---:|---:|---:|---|
| **Nhân vật (3 class)** | `64 x 64 px` / frame | `48 x 48 dp` | `60%` (`~29 dp`) | Hitbox nhỏ hơn hình để né đạn công bằng |
| **Quái thường** (Deadline, Email, Quiz) | `64 x 64 px` / frame | `48 x 48 dp` (Quiz `54`) | `60%` | Bố cục strip ngang không tràn khung |
| **Boss (Thi Cuối Kỳ, ...)** | **`96 x 96 px`** / frame | `96 x 96` (scale theo màn/uy lực Boss) | `72%` | Hiện giữ `bossSize` tương thích gameplay; sprite nguồn sinh chuẩn `96x96` |
| **Vật phẩm rơi** (Cà phê, Mì, Khiên, Xu) | `64 x 64 px` / frame | `32 x 32 dp` | `70%` | 4 frame nhấp nhô + sao lấp lánh |
| **Vũ khí cầm tay** | `64 x 64 px` | `30 x 30 dp` | — | Gắn xoay quanh nhân vật theo hướng ngắm |
| **Đạn / Hiệu ứng** | `32 x 32` hoặc `64 x 64` | `16 x 16 dp` | `45%` | Đạn người chơi tông lạnh/vàng; đạn quái luôn viền đỏ `#FF3B5C` + lõi sáng |

---

## 4. Tóm tắt Quy tắc HUD & Menu (rút từ Skill `pixel-game-hud-ui`)

1. **Vùng chạm tối thiểu `48dp`**:
   - Mọi nút bấm tương tác (**Cài đặt âm thanh**, **Tạm dừng**, **VỀ SẢNH**, **TIẾP TỤC / CHƠI LẠI**) đều có chiều rộng/chiều cao tối thiểu **`48 x 48 dp`**.
   - Khoảng cách giữa các nút lân cận tối thiểu **`8–12 dp`** để tránh bấm nhầm khi đang di chuyển và né đạn.
2. **Độ lớn cụm điều khiển chiến đấu (Màn hình ngang)**:
   - **Virtual Joystick (góc dưới trái)**: đường kính **`124 dp`**, núm kéo bán kính **`22 dp`**.
   - **Nút Bắn (góc dưới phải — chính)**: đường kính **`104 dp`**, hỗ trợ nhấn giữ và kéo chỉnh hướng ngắm.
   - **Nút Dash 8s**: đường kính **`74 dp`**, viền cyan sáng khi sẵn sàng, phủ quạt tối + số đếm ngược rõ nét khi hồi chiêu.
   - **Nút Đổi vũ khí (Slot 1/2)**: đường kính **`66 dp`**, hiển thị sprite vũ khí `FilterQuality.none` + badge số slot.
3. **Độ tương phản & Khung Pixel**:
   - Chữ trắng `#F8FAFF` và vàng `#FFD54F` luôn đặt trên nền panel tối `#141526` (`alpha 0.86`) đạt độ tương phản **`> 10:1`** (vượt xa ngưỡng 4.5:1).
   - Khung HUD dùng bo góc pixel nhỏ (`6–8 dp`), viền đặc **`2px`**, bóng cứng `Offset(2, 2)` với **`blurRadius: 0`** (không dùng blur nặng gây giảm FPS).
4. **Font Pixel (Google Fonts & Tiếng Việt)**:
   - **Google Fonts khuyến nghị**:
     - `Pixelify Sans` — ưu tiên hàng đầu cho giao diện tiếng Việt vì giữ nét pixel vuông và hiển thị đủ dấu.
     - `Press Start 2P` / `Silkscreen` / `VT323` — phù hợp cho chỉ số số học/ASCII (`05:00`, `HP`, `STAGE 1-1`).
   - **Thiết lập hiện tại trong `lib/constants.dart`**: Dùng `pixelFontFamily = 'monospace'` kèm `FontFeature.tabularFigures()` cho đồng hồ, HP, Xu, Kill và hồi chiêu để chữ thẳng hàng, không bị giật khung khi đếm và không cần cài thêm package ngoài.
5. **Tập trung cấu hình**:
   - Toàn bộ bảng màu 16 màu, kích thước nút, kích thước chữ, bo góc và độ dày viền đều khai báo tập trung tại `lib/constants.dart`.
