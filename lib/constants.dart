import 'package:flutter/material.dart';

/// Hằng số định nghĩa kích thước, assets và thông số game "Sinh viên HUIT đánh quái Deadline"
class GameConstants {
  // --- Sprite Size Constants (Original & Display) ---
  /// Sprite gốc có kích thước 64x64 px
  static const double originalSpriteSize = 64.0;

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

  // Arena Maps
  static const String mapExamHallPath = 'maps/arena_exam_hall.png';
  static const String mapLibraryPath = 'maps/arena_library.png';
  static const String mapLabPath = 'maps/arena_lab.png';
  static const String mapCanteenPath = 'maps/arena_canteen.png';

  // --- UI Colors & Theme ---
  static const Color primaryColor = Color(0xFF005BAC); // HUIT Corporate Blue
  static const Color accentColor = Color(0xFFFF9800); // HUIT Accent Orange
  static const Color dashCyanColor = Color(0xFF29E7FF); // Dash lightning cyan
  static const Color backgroundColor = Color(0xFF141526);
  static const Color cardColor = Color(0xFF1F2238);
  static const Color cardBorderColor = Color(0xFF3D4468);

  // --- Preference Keys ---
  static const String highScoreKey = 'huit_deadline_high_score';
}
