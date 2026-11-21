# Sinh Viên HUIT Đánh Quái Deadline (HUIT Survival 2D — Deadline Hunter)

Game hành động sinh tồn góc nhìn từ trên xuống (*top-down 2D pixel action roguelite* phong cách *Soul Knight*) xây dựng bằng **Flutter** và **Flame Engine**, đã được tối ưu **60 FPS** trên thiết bị di động.

- **Repository**: `https://github.com/devthanhtan/Mobile.git`
- **Tên package Dart (`pubspec.yaml`)**: `huit_deadline`
- **Hướng màn hình**: Màn hình ngang (*Landscape* — `landscapeLeft` / `landscapeRight`)
- **Hệ thống thiết kế & Art Style Guide**:
  - [design-system/deadline-hunter/MASTER.md](design-system/deadline-hunter/MASTER.md)
  - [docs/art/style_guide.md](docs/art/style_guide.md)
  - Bộ skill thiết kế game 2D pixel art cho Antigravity tại `.agents/skills/` (`pixel-art-direction`, `pixel-sprite-animation`, `pixel-game-hud-ui`, `pixel-game-vfx-feel`).

---

## 1. Yêu cầu hệ thống & Môi trường bắt buộc

| Thành phần | Phiên bản / Yêu cầu | Ghi chú |
| --- | --- | --- |
| **Git** | Phiên bản mới bất kỳ | Dùng để clone source (~40 MB, không cần Git LFS) |
| **Flutter SDK** | **`>= 3.47.5`** (hỗ trợ tốt `3.50.0` channel `stable`) | Kiểm tra bằng `flutter doctor -v` |
| **Dart SDK** | **`>= 3.13.4 < 4.0.0`** | Khai báo `sdk: ^3.13.4` trong `pubspec.yaml` |
| **Android Studio** | Phiên bản mới có **Plugin Flutter & Dart** | Khuyên dùng bản mới nhất hỗ trợ AGP `9.1.1+` |
| **JDK (Java)** | **JDK 17+** (hoặc JBR đi kèm Android Studio) | Dự án dùng `JavaVersion.VERSION_17` |
| **Android Gradle Plugin / Gradle** | AGP **`9.1.1`**, Kotlin **`2.4.0`**, Gradle **`9.3.1`** | Cần **Internet lần đầu** để tự tải Gradle & thư viện |
| **Windows Developer Mode** | **Bật** (`start ms-settings:developers`) | Cần thiết trên Windows để hỗ trợ symlink khi build plugin |
| **Python + Pillow** *(tùy chọn)* | Python `3.9+` + `pip install pillow` | Dùng khi muốn chạy lại script `tools/generate_sprites.py` |

---

## 2. Hướng dẫn cài đặt & Chạy dự án (Dòng lệnh & Android Studio)

### Bước 1: Kiểm tra môi trường & Bật Developer Mode (Windows)
Mở PowerShell / Terminal:
```powershell
# Mở cài đặt Windows để bật Developer Mode (nếu chưa bật)
start ms-settings:developers

# Kiểm tra môi trường Flutter
flutter doctor -v
```

### Bước 2: Tải dependencies & sinh file cấu hình local
Tại thư mục gốc dự án (`D:\Project\Mobile`):
```powershell
flutter pub get
```
Lệnh này tải các thư viện (`flame`, `flame_audio`, `shared_preferences`, ...) và tự sinh file `android/local.properties`.

### Bước 3: Chạy game bằng dòng lệnh (CLI)
Khởi động trước một **Android Emulator** (hoặc cắm điện thoại Android thật đã bật **USB Debugging**):
```powershell
# Xem danh sách thiết bị đang kết nối
flutter devices

# Chạy chế độ Debug (phát triển)
flutter run

# Chạy chế độ Profile (khuyên dùng để đo đúng 60 FPS AOT trên máy thật/emulator)
flutter run --profile
```

### Bước 4: Mở và chạy bằng Android Studio
1. Mở **Android Studio** -> chọn **Open** -> trỏ tới thư mục **`D:\Project\Mobile`**.
2. Kiểm tra đường dẫn SDK nếu nút `main.dart` hiện dấu `X` đỏ hoặc nút **Run (`▶`)** bị mờ:
   - Vào **File -> Settings -> Languages & Frameworks -> Flutter**: đặt **Flutter SDK path** (ví dụ `C:\Users\<User>\flutter`) -> **Apply**.
   - Vào **File -> Settings -> Languages & Frameworks -> Dart**: tích **Enable Dart support for the project 'Mobile'**, kiểm tra **Dart SDK path** là `C:\Users\<User>\flutter\bin\cache\dart-sdk` -> **Apply -> OK**.
3. Khởi động **Android Emulator** trong **Device Manager** (hoặc chọn điện thoại thật), chọn target **`main.dart`**, rồi nhấn **Run (`▶`)** (hoặc **Run -> Flutter Run 'main.dart' in Profile Mode** để trải nghiệm mượt nhất).
4. **Lưu ý khi cập nhật code / asset mới**: Khi có thay đổi ở `onLoad()` hoặc thêm file ảnh mới trong `assets/images/`, hãy nhấn **Stop (`■`) rồi bấm Run (`▶`) lại** (hoặc **Hot Restart `Ctrl+Shift+\`**) thay vì chỉ *Hot Reload* để APK đóng gói đầy đủ asset mới và khởi tạo lại camera.

---

## 3. Tính năng Gameplay, 3 Lớp Nhân vật & 5 Vũ khí riêng

### 3 Lớp Nhân vật Sinh viên HUIT (Sprite Chibi `64x64`, hoạt ảnh `idle` 4f / `walk` 4f / `hit` 1f / `death` 4f)
1. **Sinh Viên IT** (*Kính cận cyan* — Sát thương `+20%`):
   - Slot 1: **Bút Bi Thần Tốc**
   - Slot 2: **Laptop Laser Code**
2. **Sinh Viên Thực Phẩm** (*Kính bảo hộ Lab* — Máu tối đa `140 HP`):
   - Slot 1: **Trà Sữa Trân Châu**
   - Slot 2: **Giáo Trình Đại Cương**
3. **Sinh Viên Kinh Tế** (*Mũ vàng năng động* — Tốc độ chạy `+20%`):
   - Slot 1: **USB Phi Tiêu**
   - Slot 2: **Giáo Trình Đại Cương**

### 5 Loại Vũ khí riêng (`lib/models/weapon_config.dart` — Data + Strategy Pattern)
| Vũ khí | Cơ chế & Tính năng riêng | Hoạt ảnh & Hiệu ứng (Pooled VFX) |
| --- | --- | --- |
| **1. Bút Bi Thần Tốc** | Bắn nhanh (`5.0 phát/s`), sát thương ổn định, chính xác cao | Đạn mực 3 frame + vệt xanh ngắn phía sau + muzzle flash nhỏ |
| **2. Laptop Laser Code** | **Giữ nút bắn nạp `0.4s`** rồi xả tia laser xuyên **mọi quái** trên đường thẳng | Cầu tụ năng lượng ở mũi máy + tia laser 4 bước glow + giật nhẹ camera |
| **3. USB Phi Tiêu** | Ném xoay như shuriken, **nảy tường đấu trường tối đa 2 lần** & nảy qua quái, gây sát thương mỗi lần nảy | 4 frame xoay `90°` sắc nét + tia lửa vàng khi nảy tường/trúng đích |
| **4. Trà Sữa Trân Châu** | Đạn trân châu nảy nhẹ, **mỗi lần bắn trúng quái hồi `+3 HP`** cho người chơi | Đạn trân châu bóng kem + nổ **hạt bong bóng rỗng** khi trúng |
| **5. Giáo Trình Đại Cương** | Cận chiến vung theo **cung tròn ~130°**, đánh trúng toàn bộ quái trong tầm và **đẩy lùi mạnh (`36px`)** | Hoạt ảnh vung 4 frame + vệt quét cung tròn vàng/trắng |

---

## 4. Kiến trúc tối ưu 60 FPS đã triển khai

1. **Va chạm & Auto-aim không quét `world.children`**:
   - Dùng registry riêng (`enemies`, `items`, `activeBullets`) đăng ký ở `onMount` và gỡ ở `onRemove`.
   - `EnemyComponent`, `BossComponent`, `ItemComponent` dùng `CollisionType.passive`; chỉ `PlayerComponent` và `BulletComponent` là `active` (loại bỏ hoàn toàn kiểm tra va chạm quái-với-quái $O(N^2)$).
   - Đạn người chơi kiểm tra giao cắt đoạn thẳng (**swept segment-vs-circle**) tối đa 1 lần/frame trực tiếp trên `game.enemies` + `game.boss`.
   - Auto-aim làm mới mỗi **`0.15s`** bằng khoảng cách bình phương (không `sqrt`, không cấp phát `Vector2`).
2. **Object Pool & Giảm áp lực Garbage Collector (0 cấp phát trong `render()`)**:
   - Toàn bộ `Paint` được cache dạng `static final` hoặc field; `TextPainter` của số sát thương được cache theo giá trị sát thương.
   - **Object Pool** cho `BulletComponent` (max `120`), hạt hiệu ứng/bong bóng (max `64`), số sát thương (max `24`), muzzle flash, tia laser và vệt chém cận chiến trong `CombatVfxLayerComponent`.
   - `PixelSpriteCache` tạo **1 lần duy nhất** trong `onLoad()` toàn bộ `SpriteAnimation`, bóng chân dùng chung và frame nháy trắng (loại bỏ `ColorFilter` động / `saveLayer` lúc chạy).
3. **Tối ưu Render & HUD**:
   - `ArenaBackgroundComponent` ghi toàn bộ nền + biên đấu trường **1 lần** ra `ui.Picture` rồi phát lại mỗi frame.
   - **Viewport culling** (`isVisibleInCamera`) bỏ qua vẽ mọi thực thể nằm ngoài khung nhìn camera.
   - Đồng hồ sinh tồn chỉ cập nhật `ValueNotifier` khi đổi giây nguyên (`1 Hz`); nút `DashButton` vẽ quạt hồi chiêu trực tiếp bằng `CustomPainter(repaint: cooldownListenable)` (0 rebuild widget khi quét quạt); từng cụm HUD và `GameWidget` đều bọc `RepaintBoundary`.
   - AI quái ở xa (`> 520px`) chỉ tính lại hướng mỗi 3 frame lệch pha; kẹp `dt <= 1/30s`.

---

## 5. Các lệnh kiểm tra, Benchmark & Sinh lại Sprite Sheet

```powershell
# 1. Kiểm tra phân tích mã tĩnh
flutter analyze

# 2. Chạy toàn bộ unit, widget & performance benchmark test (12 tests)
flutter test

# 3. Chạy riêng bài đo benchmark hiệu năng 32 quái + đạn liên thanh
flutter test test/performance_benchmark_test.dart

# 4. Sinh lại toàn bộ sprite sheet PNG 16 màu (64x64 & Boss 96x96) bằng Python + Pillow
pip install pillow
python tools/generate_sprites.py

# 5. Build thử Android Debug APK
flutter build apk --debug
```

---

## 6. Xử lý các lỗi thường gặp

1. **Lỗi `Timeout waiting for exclusive access to file: ...gradle-9.3.1-all.zip`**
   - Do có 2 tiến trình Gradle chạy cùng lúc (ví dụ extension *Gradle for Java* trong VS Code/Antigravity chạy đè với Android Studio). Hãy bấm **Cancel** thông báo *Gradle: Configure project* trong VS Code, hoặc tắt `java.exe` bị treo:
     ```powershell
     taskkill /F /IM java.exe 2>$null
     Remove-Item -Recurse -Force "$env:USERPROFILE\.gradle\wrapper\dists\gradle-9.3.1-all" -ErrorAction SilentlyContinue
     $env:JAVA_HOME = "E:\Android\Android Studio\jbr"
     cd D:\Project\Mobile\android
     .\gradlew --version
     ```
2. **Lỗi thiếu RAM khi Gradle build (`OutOfMemoryError`)**
   - Mở `android/gradle.properties`, giảm `-Xmx8G` xuống `-Xmx3G -XX:MaxMetaspaceSize=1G`.
3. **Camera hoặc sprite mới chưa cập nhật sau khi sửa code**
   - Khi sửa logic khởi tạo `onLoad()` hoặc thêm asset ảnh mới, cần bấm **Stop (`■`) rồi Run (`▶`) lại** (hoặc **Hot Restart**), vì *Hot Reload* không nạp lại asset bundle mới vào APK và không chạy lại `onLoad()`.

---

## 7. Cấu trúc thư mục dự án

```text
lib/
├── main.dart                         # Khởi tạo app, khóa hướng màn hình ngang (Landscape)
├── constants.dart                    # Bảng 16 màu pixel art, token HUD >=48dp, giới hạn Pool & AI
├── models/
│   ├── player_class.dart             # 3 lớp nhân vật HUIT (IT, Thực Phẩm, Kinh Tế)
│   ├── weapon_info.dart              # Lớp cơ sở thông tin vũ khí
│   ├── weapon_config.dart            # Data + 5 WeaponStrategy (Bút bi, Laptop, USB, Trà sữa, Giáo trình)
│   └── stage_info.dart               # Thông tin các màn 1-1 -> 1-4 & Boss tương ứng
├── services/
│   ├── audio_settings_service.dart   # Quản lý BGM & SFX (có chống nghẽn AudioTrack khi bắn nhanh)
│   └── stage_progress_service.dart   # Lưu tiến trình mở khóa màn chơi
├── utils/
│   ├── fps_monitor.dart              # Bộ đếm FPS / FrameTiming 2Hz (chỉ bật ở debug/profile)
│   └── pixel_sprite_cache.dart       # Cache SpriteAnimation 1 lần, bóng chân chung & frame hit-flash
├── game/
│   ├── lobby_game.dart               # Sảnh chờ tương tác: di chuyển, đổi nhân vật & vào cổng chọn màn
│   └── huit_game.dart                # Core FlameGame: Registry, Bullet Pool, sinh tồn 05:00 -> Boss
├── components/
│   ├── arena_background.dart         # Nền bản đồ ghi 1 lần ra ui.Picture
│   ├── combat_vfx_layer.dart         # Object Pool cho hạt, bong bóng, muzzle flash, laser, vệt chém, sát thương
│   ├── player_component.dart         # Nhân vật SpriteAnimationComponent, auto-aim 0.15s, Dash 8s
│   ├── enemy_component.dart          # Quái thường SpriteAnimationComponent + AI giảm tải theo khoảng cách
│   ├── boss_component.dart           # Boss lớn với hoạt ảnh idle/attack/phase2/death
│   ├── bullet_component.dart         # Đạn Pooled với swept hit check & hoạt ảnh riêng từng vũ khí
│   └── item_component.dart           # Vật phẩm rơi 4 frame nhấp nhô + lấp lánh
└── ui/
    ├── splash_screen.dart            # Màn hình chờ phong cách pixel
    ├── main_menu_screen.dart         # Giao diện Sảnh chờ đi lại được
    ├── game_screen.dart              # HUD trận đấu bọc RepaintBoundary + FpsOverlayWidget
    └── widgets/
        ├── game_controls.dart        # Joystick, nút Bắn, nút Dash (CustomPainter 0-rebuild), Đổi vũ khí
        ├── stage_map_dialog.dart     # Bản đồ chọn màn 1-1 -> 1-4
        └── audio_settings_dialog.dart# Hộp thoại chỉnh Nhạc nền & SFX

tools/
└── generate_sprites.py               # Script Python + Pillow sinh toàn bộ sprite sheet PNG 16 màu
docs/art/
└── style_guide.md                    # Quy chuẩn bảng 16 màu, viền 1px, kích thước sprite & HUD
design-system/deadline-hunter/
└── MASTER.md                         # Tài liệu tổng hợp hệ thống thiết kế Deadline Hunter
.agents/skills/                       # 4 skill thiết kế game 2D pixel art cho Antigravity
```
