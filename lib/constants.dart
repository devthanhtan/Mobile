import 'package:flutter/material.dart';

/// Hằng số kích thước sprite, bảng màu 16 màu chuẩn pixel art, token HUD/menu
/// và thông số gameplay cho game "Sinh viên HUIT đánh quái Deadline"
class GameConstants {
  // --- Sprite Size Constants (Original & Display) ---
  /// Sprite nguồn nhân vật/quái/vật phẩm/vũ khí chuẩn 64x64 px
  static const double originalSpriteSize = 64.0;

  /// Sprite nguồn Boss chuẩn 96x96 px (theo docs/art/style_guide.md)
  static const double bossSourceSpriteSize = 96.0;

  /// Kích thước hiển thị người chơi trong game (48x48)
  static const double playerSize = 48.0;

  /// Kích thước hiển thị quái thường trong game (48x48)
  static const double enemySize = 48.0;

  /// Kích thước hiển thị Boss gây áp lực lớn (~4x người chơi)
  static const double bossSize = 188.0;

  /// Kích thước vật phẩm rơi (32x32)
  static const double itemSize = 32.0;

  /// Kích thước vũ khí (30x30)
  static const double weaponSize = 30.0;

  /// Kích thước đạn người chơi (16x16)
  static const double bulletSize = 16.0;

  /// Tỷ lệ hitbox so với kích thước sprite (60% để va chạm công bằng)
  static const double hitboxRatio = 0.6;

  /// Tỷ lệ hitbox Boss (72% để vừa dễ né vừa dễ bắn trúng thân Boss lớn)
  static const double bossHitboxRatio = 0.72;

  // --- Arena & Combat Constants ---
  /// Kích thước bản đồ đấu trường (px)
  static const double arenaWidth = 1600.0;
  static const double arenaHeight = 1600.0;
  static const double arenaTileSize = 64.0;
  static const double arenaPlayableMargin = 96.0;

  /// Thông số thời gian sinh tồn 5 phút (300 giây) trước khi Boss xuất hiện
  static const double survivalDurationSeconds = 300.0;

  /// Thông số kỹ năng Dash (Lướt) hồi chiêu 8 giây
  static const double dashCooldownSeconds = 8.0;
  static const double dashDurationSeconds = 0.22;
  static const double dashSpeedMultiplier = 3.2;

  /// Thông số bắn đạn cơ bản
  static const double bulletSpeed = 480.0;
  static const double bulletMaxDistance = 560.0;
  static const double baseFireCooldown = 0.26;
  static const double enemyBulletSpeed = 240.0;

  // --- Performance, Pooling & AI Throttling Constants ---
  /// Giới hạn số lượng quái, đạn, hạt hiệu ứng & số sát thương cùng lúc để giữ vững 60 FPS
  static const int maxEnemies = 34;
  static const int maxActiveBullets = 120;
  static const int maxActiveParticles = 64;
  static const int maxActiveDamageNumbers = 24;

  /// Kẹp dt mỗi bước mô phỏng tối đa 1/30 giây để chống xuyên hitbox khi giật khung hình
  static const double maxDeltaTime = 1.0 / 30.0;

  /// Chu kỳ chọn lại mục tiêu auto-aim (giây) thay vì quét mỗi frame
  static const double autoAimRefreshInterval = 0.15;

  /// Khoảng cách coi là quái ở xa người chơi để giảm tần suất cập nhật AI (mỗi 3 frame)
  static const double farEnemyAiDistance = 520.0;
  static const double farEnemyAiDistanceSq =
      farEnemyAiDistance * farEnemyAiDistance;
  static const int farEnemyAiFrameInterval = 3;

  /// Biên dự phòng khi cắt bỏ vẽ ngoài khung nhìn camera (viewport culling)
  static const double cameraCullMargin = 96.0;

  /// Cờ bật HUD FPS bằng --dart-define=SHOW_FPS=true (tự động bật trong debug/profile)
  static const bool showFpsOverlayEnv = bool.fromEnvironment(
    'SHOW_FPS',
    defaultValue: false,
  );

  // --- Full Flutter Asset Paths (UI & Preview) ---
  static const String splashBgAsset = 'assets/images/ui/splash_bg.png';
  static const String lobbyBgAsset = 'assets/images/ui/lobby_bg.png';
  static const String lobbyFlameBgPath = 'ui/lobby_bg.png';

  // --- Audio Filenames (relative to assets/audio/) ---
  static const String bgmThemeAudio = 'bgm_theme.wav';
  static const String sfxShootAudio = 'sfx_shoot.wav';
  static const String sfxDashAudio = 'sfx_dash.wav';
  static const String sfxUiAudio = 'sfx_ui.wav';

  // --- Asset Paths Relative to assets/images/ (for Flame Images) ---
  // Player
  static const String playerITPath = 'player/player_it.png';
  static const String playerFoodPath = 'player/player_food.png';
  static const String playerEcoPath = 'player/player_eco.png';

  // Enemy & Bosses
  static const String enemyDeadlinePath = 'enemy/enemy_deadline.png';
  static const String enemyEmailPath = 'enemy/enemy_email.png';
  static const String enemyQuizPath = 'enemy/enemy_quiz.png';
  static const String bossFinalExamPath = 'enemy/boss_final_exam.png';
  static const String bossGolemPath = 'enemy/boss_golem.png';
  static const String bossBlueprintPath = 'enemy/boss_blueprint.png';
  static const String bossDragonDeanPath = 'enemy/boss_dragon_dean.png';

  // Item
  static const String itemCoffeePath = 'item/item_coffee.png';
  static const String itemNoodlePath = 'item/item_noodle.png';
  static const String itemShieldPath = 'item/item_shield.png';
  static const String itemCoinPath = 'item/item_coin.png';

  // Weapon
  static const String weaponPenPath = 'weapon/weapon_pen.png';
  static const String weaponLaptopPath = 'weapon/weapon_laptop.png';
  static const String weaponUsbPath = 'weapon/weapon_usb.png';
  static const String weaponBobaPath = 'weapon/weapon_boba.png';
  static const String weaponTextbookPath = 'weapon/weapon_textbook.png';

  // Arena Maps
  static const String mapExamHallPath = 'maps/arena_exam_hall.png';
  static const String mapLibraryPath = 'maps/arena_library.png';
  static const String mapLabPath = 'maps/arena_lab.png';
  static const String mapCanteenPath = 'maps/arena_canteen.png';

  // ===========================================================================
  // BẢNG MÀU 16 MÀU PIXEL ART CHUẨN (docs/art/style_guide.md)
  // ===========================================================================
  static const Color pixelInk = Color(0xFF141526); // #1 Viền tối 1px & nền chính
  static const Color pixelPanelDark = Color(0xFF1E213A); // #2 Nền panel/thẻ HUD
  static const Color pixelPanelBorder = Color(0xFF4A5580); // #3 Viền khung 2px
  static const Color pixelSlate = Color(0xFF7A86B6); // #4 Text phụ & cooldown
  static const Color pixelWhite = Color(0xFFF8FAFF); // #5 Text chính & hit flash
  static const Color pixelCream = Color(0xFFFFE8C8); // #6 Da chibi & trang sách
  static const Color pixelTan = Color(0xFFD49A6A); // #7 Gỗ giảng đường & bóng da
  static const Color pixelHuitBlue = Color(0xFF005BAC); // #8 Xanh thương hiệu HUIT
  static const Color pixelCyan = Color(0xFF29E7FF); // #9 Dash, khiên, laser
  static const Color pixelEmerald = Color(0xFF38D973); // #10 HP an toàn & hồi máu
  static const Color pixelGold = Color(0xFFFFD54F); // #11 Xu, đồng hồ, mũ vàng
  static const Color pixelOrange = Color(0xFFFF9800); // #12 Nút CTA & điểm nhấn
  static const Color pixelDangerRed = Color(0xFFFF3B5C); // #13 HP thấp, đạn quái, Boss
  static const Color pixelDeepCrimson = Color(0xFF8E1B3A); // #14 Nền cảnh báo Boss
  static const Color pixelViolet = Color(0xFF8F6BFF); // #15 Bóng tím & quái Quiz
  static const Color pixelShadowBlack = Color(0xFF090A14); // #16 Bóng cứng pixel

  // --- Legacy / Semantic Theme Aliases (giữ tương thích toàn dự án) ---
  static const Color primaryColor = pixelHuitBlue;
  static const Color accentColor = pixelOrange;
  static const Color dashCyanColor = pixelCyan;
  static const Color backgroundColor = pixelInk;
  static const Color cardColor = pixelPanelDark;
  static const Color cardBorderColor = pixelPanelBorder;

  // --- Semantic HUD Surface & State Colors ---
  static const Color hudSurfaceColor = Color(0xDB141526); // pixelInk ~86% alpha
  static const Color hudOverlayScrimColor = Color(0xBF090A14); // phủ modal tối
  static const Color hudBossPanelBgColor = Color(0xE6260B18); // nền thanh máu Boss
  static const Color hudWarningBannerBgColor = Color(0xE08E1B3A); // nền cảnh báo Boss
  static const Color hudTrackBgColor = Color(0xFF0E1020); // rãnh nền thanh HP
  static const Color hudHpHealthyColor = pixelEmerald;
  static const Color hudDangerColor = pixelDangerRed;
  static const Color hudGoldColor = pixelGold;
  static const Color hudTextPrimaryColor = pixelWhite;
  static const Color hudTextSecondaryColor = pixelSlate;

  // --- HUD Typography & Pixel Frame Tokens ---
  /// Font pixel fallback không cần thêm package ngoài (khuyến nghị Google Fonts: Pixelify Sans)
  static const String pixelFontFamily = 'monospace';
  static const List<FontFeature> hudTabularFigures = [
    FontFeature.tabularFigures(),
  ];

  static const double hudCornerRadius = 6.0;
  static const double hudModalCornerRadius = 8.0;
  static const double hudBorderWidth = 2.0;
  static const double hudBarCornerRadius = 3.0;

  /// Bóng cứng pixel không blur (tối ưu raster GPU & đúng chất retro)
  static const List<BoxShadow> hudPixelShadow = [
    BoxShadow(
      color: pixelShadowBlack,
      offset: Offset(2, 2),
      blurRadius: 0,
    ),
  ];

  // --- HUD Touch Targets & Control Sizes (chuẩn mobile >= 48dp) ---
  static const double hudMinTouchTarget = 48.0;
  static const double hudButtonGap = 10.0;
  static const double hudTopPaddingH = 14.0;
  static const double hudTopPaddingV = 8.0;
  static const double hudBottomMarginH = 22.0;
  static const double hudBottomMarginV = 18.0;

  static const double hudJoystickSize = 124.0;
  static const double hudJoystickKnobRadius = 22.0;
  static const double hudShootButtonSize = 104.0;
  static const double hudDashButtonSize = 74.0;
  static const double hudWeaponSwitchButtonSize = 66.0;
  static const double hudLobbyInteractButtonSize = 92.0;

  static const double hudHpBarWidth = 86.0;
  static const double hudHpBarHeight = 10.0;
  static const double hudBossBarMaxWidth = 320.0;
  static const double hudBossBarHeight = 10.0;
  static const double hudStageChipMaxWidth = 116.0;
  static const double hudModalWidth = 380.0;
  static const double hudModalButtonHeight = 48.0;
  static const double hudSplashPlayButtonWidth = 216.0;
  static const double hudSplashPlayButtonHeight = 52.0;

  // --- HUD Font Sizes ---
  static const double hudStatFontSize = 10.5;
  static const double hudTimerFontSize = 11.5;
  static const double hudStageFontSize = 11.0;
  static const double hudBossTitleFontSize = 10.5;
  static const double hudBossWarningSubSize = 12.5;
  static const double hudBossWarningTitleSize = 16.5;
  static const double hudModalTitleSize = 16.5;
  static const double hudModalBodySize = 12.5;

  /// Tạo TextStyle thống nhất theo font pixel và chữ số căn đều cho HUD
  static TextStyle hudTextStyle({
    required double fontSize,
    Color color = hudTextPrimaryColor,
    FontWeight fontWeight = FontWeight.w800,
    double? letterSpacing,
    double? height,
    bool tabularNumbers = false,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: pixelFontFamily,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: tabularNumbers ? hudTabularFigures : null,
      shadows: shadows,
    );
  }

  /// Khung pixel chuẩn cho các panel HUD/thẻ thông tin
  static BoxDecoration hudPixelBoxDecoration({
    Color color = hudSurfaceColor,
    Color borderColor = cardBorderColor,
    double borderWidth = hudBorderWidth,
    double borderRadius = hudCornerRadius,
    bool withShadow = true,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: withShadow ? hudPixelShadow : null,
    );
  }

  // --- Preference Keys ---
  static const String highScoreKey = 'huit_deadline_high_score';
}
