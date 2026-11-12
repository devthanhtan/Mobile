# Sinh Viên HUIT Đánh Quái Deadline (HUIT Survival 2D)

Game hành động sinh tồn góc nhìn từ trên xuống (*top-down action roguelite* phong cách *Soul Knight*) xây dựng bằng **Flutter** và **Flame Engine**.

- **Repository**: `https://github.com/devthanhtan/Mobile.git`
- **Tên package Dart (`pubspec.yaml`)**: `huit_deadline`
- **Hướng màn hình**: Màn hình ngang (*Landscape* — `sensorLandscape`)

---

## 1. Yêu cầu hệ thống & Môi trường bắt buộc

Trước khi clone về phát triển hoặc chạy thử, máy tính cần đáp ứng các điều kiện sau:

| Thành phần | Phiên bản / Yêu cầu | Ghi chú |
| --- | --- | --- |
| **Git** | Phiên bản mới bất kỳ | Dùng để clone source (~40 MB, không cần Git LFS) |
| **Flutter SDK** | **`>= 3.47.5`** (channel `stable`) | Đã kiểm thử ổn định trên Flutter `3.47.5` |
| **Dart SDK** | **`>= 3.13.4 < 4.0.0`** | Khai báo `sdk: ^3.13.4` trong `pubspec.yaml` |
| **Android Studio** | Phiên bản mới có **Plugin Flutter & Dart** | Khuyên dùng bản mới nhất hỗ trợ AGP `9.1.0` |
| **JDK (Java)** | **JDK 17** | Dự án dùng `JavaVersion.VERSION_17` / `JVM_17` |
| **Android Gradle Plugin / Gradle** | AGP **`9.1.0`**, Kotlin **`2.4.0`**, Gradle **`9.3.1`** | Cần **Internet lần đầu** để tự tải Gradle & thư viện |
| **RAM khuyến nghị** | **>= 12–16 GB RAM** (mặc định Gradle `-Xmx8G`) | Nếu máy 8 GB RAM, xem mục **Xử lý lỗi thường gặp** bên dưới |
| **Thiết bị chạy thử** | Android Emulator (API hỗ trợ bởi Flutter) hoặc điện thoại Android bật USB Debugging | Nên xoay ngang emulator khi chơi thử |

> **Lưu ý nền tảng**: Hiện dự án đã được cấu hình, kiểm thử unit/widget test và build APK trực tiếp cho **Android** (trên Windows). Nếu muốn build cho **iOS/macOS**, cần máy macOS có sẵn Xcode và CocoaPods.

---

## 2. Hướng dẫn tải về & Mở bằng Android Studio (Chi tiết cho người mới)

### Bước 1: Kiểm tra môi trường Flutter trên máy
Mở Terminal / PowerShell và chạy:
```bash
flutter doctor -v
```
Đảm bảo các mục **Flutter**, **Android toolchain**, **Android Studio** đều báo xanh `[✓]`.
- Nếu chưa chấp nhận bản quyền Android SDK, chạy:
  ```bash
  flutter doctor --android-licenses
  ```
- Nếu Flutter đang ở phiên bản cũ (Dart `< 3.13.4`), chạy:
  ```bash
  flutter upgrade
  ```

### Bước 2: Clone mã nguồn về máy
Chọn thư mục lưu **không có dấu tiếng Việt và không chứa khoảng trắng** (khuyến nghị ví dụ `D:\Projects\Mobile` trên Windows):
```bash
git clone https://github.com/devthanhtan/Mobile.git
cd Mobile
```

### Bước 3: Tải dependencies & sinh file cấu hình local
```bash
flutter pub get
```
Lệnh này sẽ tự tải các thư viện (`flame`, `flame_audio`, `shared_preferences`, ...) và tự động sinh file `android/local.properties` theo đường dẫn SDK trên máy của bạn.

### Bước 4: Cài Plugin & Mở dự án trong Android Studio
1. Mở **Android Studio**.
2. Vào **Plugins** (`Settings` -> `Plugins` -> tab `Marketplace`), cài đặt **Flutter** (plugin **Dart** sẽ được hỏi cài kèm, chọn đồng ý) rồi khởi động lại Android Studio nếu được yêu cầu.
3. Tại màn hình chính Android Studio, chọn **Open** (KHÔNG chọn *New Flutter Project*), trỏ đúng tới thư mục **`Mobile`** vừa clone rồi nhấn **OK**.
4. Kiểm tra cấu hình SDK trong Android Studio:
   - Vào **File -> Settings -> Languages & Frameworks -> Flutter**: kiểm tra **Flutter SDK path** trỏ đúng thư mục cài Flutter trên máy bạn.
   - Đợi thanh tiến trình góc dưới hoàn tất *Pub get / Indexing / Gradle sync*.
5. Mở **Device Manager** trong Android Studio để khởi động một **Android Emulator** (nên chọn cấu hình màn hình ngang hoặc xoay ngang máy ảo) hoặc cắm điện thoại Android thật đã bật **USB Debugging**.
6. Chọn thiết bị trên thanh công cụ phía trên, chọn target **`lib/main.dart`**, sau đó nhấn nút **Run (`▶`)**.

---

## 3. Các lệnh kiểm tra nhanh bằng dòng lệnh

Trước khi commit/push code mới, nên chạy đầy đủ 3 bước kiểm tra sau:

```bash
# Kiểm tra phân tích mã tĩnh (lint / warning / error)
flutter analyze

# Chạy toàn bộ unit & widget test
flutter test

# Build thử file Android Debug APK (kết quả tại build/app/outputs/flutter-apk/app-debug.apk)
flutter build apk --debug
```

---

## 4. Xử lý các lỗi thường gặp khi mới tải repo

1. **Lỗi thiếu RAM khi Gradle build (`OutOfMemoryError` hoặc máy bị đơ khi build)**
   - Mở `android/gradle.properties`, sửa dòng 1 từ `-Xmx8G -XX:MaxMetaspaceSize=4G` xuống mức nhẹ hơn như:
     ```properties
     org.gradle.jvmargs=-Xmx3G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=512m -XX:+HeapDumpOnOutOfMemoryError
     ```
2. **Lỗi Kotlin Daemon / Cache trên Windows khi ổ dự án (`D:\`) khác ổ Pub Cache (`C:\`)**
   - Dự án đã đặt sẵn `kotlin.incremental=false` trong `android/gradle.properties`. Nếu vẫn kẹt cache cũ, chạy:
     ```bash
     flutter clean
     flutter pub get
     ```
3. **Lỗi `Invalid module name: '...' - must be a valid Dart package name`**
   - Nếu tạo mới hoặc đổi tên module/package trong Android Studio, tên package Dart **bắt buộc viết thường và dùng dấu gạch dưới** (`lower_case_with_underscores`, ví dụ `huit_deadline`), không viết hoa kiểu `HuitDeadline`.
4. **Lỗi `flutter.sdk not set in local.properties`**
   - Chạy `flutter pub get` ở thư mục gốc dự án để Flutter tự tạo lại file `android/local.properties`.

---

## 5. Cấu trúc dự án để phát triển thêm

```text
lib/
├── main.dart                         # Khởi tạo app, khóa hướng màn hình ngang (Landscape)
├── constants.dart                    # Hằng số kích thước sprite, thông số Dash 8s, sinh tồn 5 phút, màu UI
├── models/
│   ├── player_class.dart             # 3 lớp nhân vật HUIT (IT, Thực Phẩm, Kinh Tế) & chỉ số/vũ khí
│   ├── weapon_info.dart              # Thông số từng loại vũ khí (sát thương, tốc độ bắn, số đạn, màu đạn)
│   └── stage_info.dart               # Thông tin các màn 1-1 -> 1-4 (bản đồ, Boss, máu Boss, màu chủ đề)
├── services/
│   ├── audio_settings_service.dart   # Bật/tắt & chỉnh âm lượng Nhạc nền (BGM) và Hiệu ứng (SFX)
│   └── stage_progress_service.dart   # Lưu tiến trình mở khóa màn chơi (qua màn trước mở màn sau)
├── game/
│   ├── lobby_game.dart               # Sảnh chờ tương tác: di chuyển, đổi nhân vật & vào cổng chọn màn
│   └── huit_game.dart                # Engine trận đấu: sinh tồn 05:00 -> quái biến mất -> triệu hồi Boss
├── components/
│   ├── arena_background.dart         # Hiển thị bản đồ pixel art & khung giới hạn vùng chiến đấu
│   ├── player_component.dart         # Nhân vật, auto-aim quái gần nhất, Dash 8s, đổi vũ khí, nhận vật phẩm
│   ├── enemy_component.dart          # Quái thường (Deadline cận chiến; Email & Quiz bắn đạn tầm xa)
│   ├── boss_component.dart           # Boss kích thước lớn (188x188) với 3 mẫu chiêu thức & pha cuồng nộ
│   ├── bullet_component.dart         # Đạn người chơi & quái/Boss (chống trượt khi quái áp sát cự ly gần)
│   └── item_component.dart           # Vật phẩm rơi (Cà phê, Mì ly, Khiên, Xu)
└── ui/
    ├── splash_screen.dart            # Màn hình chờ (1 nút CHƠI + 1 nút Cài đặt âm thanh góc phải)
    ├── main_menu_screen.dart         # Giao diện Sảnh chờ đi lại được + Joystick + nút tương tác
    ├── game_screen.dart              # Giao diện trong trận (ô HP + đồng hồ sinh tồn, Boss HP, cụm nút điều khiển)
    └── widgets/
        ├── game_controls.dart        # Joystick ảo, nút Bắn, nút Dash 8s, nút Đổi vũ khí
        ├── stage_map_dialog.dart     # Bản đồ chọn màn 1-1 -> 1-4 (có trạng thái khóa/mở khóa)
        └── audio_settings_dialog.dart# Hộp thoại chỉnh Nhạc nền & Hiệu ứng âm thanh

assets/
├── audio/                            # Nhạc nền & SFX (.wav)
└── images/                           # Sprite nhân vật, quái, Boss, vũ khí, vật phẩm, UI và 4 bản đồ đấu trường

test/
├── widget_test.dart                  # Kiểm thử luồng Splash -> Lobby -> Bản đồ chọn màn -> GameScreen
└── game_controls_test.dart           # Kiểm thử điều khiển, sinh tồn 5 phút -> Boss, auto-aim & point-blank
```

### Gợi ý mở rộng nhanh
- **Thêm màn chơi mới (`1-5`, ...)**: Thêm ảnh nền vào `assets/images/maps/`, Boss vào `assets/images/enemy/`, rồi khai báo một `StageInfo` mới trong `lib/models/stage_info.dart`.
- **Thêm nhân vật hoặc vũ khí mới**: Chỉnh trong `lib/models/player_class.dart` và `lib/models/weapon_info.dart`.
- **Thêm loại quái mới**: Mở rộng `NormalEnemyType` và hành vi trong `lib/components/enemy_component.dart`.
