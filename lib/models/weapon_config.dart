import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../components/player_component.dart';
import '../constants.dart';
import '../game/huit_game.dart';
import '../services/audio_settings_service.dart';
import 'weapon_info.dart';

/// Phân loại 5 vũ khí đặc trưng của sinh viên HUIT
enum WeaponKind {
  pen, // Bút bi: bắn nhanh, đạn mực 3 frame + vệt xanh ngắn, muzzle flash nhỏ
  laptop, // Laptop: giữ nạp 0.4s bắn tia laser xuyên mọi quái trên đường thẳng + giật nhẹ camera
  usb, // USB: phi tiêu shuriken 4 frame xoay, nảy tường tối đa 2 lần, sát thương mỗi lần nảy
  boba, // Trà sữa: đạn trân châu nảy nhẹ, trúng quái hồi máu nhỏ + bong bóng nổ
  textbook, // Giáo trình (cận chiến): vung cung tròn 4 frame + vệt quét, đẩy lùi quái
}

/// Kiểu hiển thị hoạt ảnh của đạn trong BulletComponent
enum BulletVisualStyle {
  standard,
  penInk,
  usbShuriken,
  bobaPearl,
}

/// Cấu hình dữ liệu (Data-Driven) kết hợp Strategy cho từng loại vũ khí.
/// Kế thừa [WeaponInfo] để giữ tương thích hoàn toàn với toàn bộ HUD/loadout hiện có.
class WeaponConfig extends WeaponInfo {
  final WeaponKind kind;
  final double fireRate; // Số lần bắn/vung mỗi giây
  final double speed;
  final int pierce; // Số mục tiêu xuyên qua (999 = xuyên toàn bộ)
  final int bounce; // Số lần nảy tường tối đa
  final double knockback; // Lực đẩy lùi quái (px)
  final double chargeDuration; // Thời gian giữ nút nạp trước khi bắn (Laptop = 0.4s)
  final double healOnHit; // Máu hồi cho người chơi mỗi lần trúng (Trà sữa)
  final double meleeRadius; // Bán kính quét cận chiến (Giáo trình)
  final double meleeArcRadians; // Góc quét cung tròn cận chiến
  final BulletVisualStyle bulletVisualStyle;
  final Color secondaryColor;
  final int hitParticleCount;
  final bool hitBubbleEffect;
  final String sfxHook; // Tên file âm thanh riêng (để trống '' nếu chưa có file)
  final WeaponStrategy strategy;

  const WeaponConfig({
    required this.kind,
    required super.name,
    required super.assetPath,
    required super.flamePath,
    required this.fireRate,
    required super.damage,
    required this.speed,
    required this.pierce,
    required this.bounce,
    required this.knockback,
    required super.bulletColor,
    required this.secondaryColor,
    required this.strategy,
    this.chargeDuration = 0.0,
    this.healOnHit = 0.0,
    this.meleeRadius = 0.0,
    this.meleeArcRadians = 0.0,
    this.bulletVisualStyle = BulletVisualStyle.standard,
    this.hitParticleCount = 4,
    this.hitBubbleEffect = false,
    this.sfxHook = '',
    super.bulletCount = 1,
    super.spreadAngleRadians = 0.0,
  }) : super(
         fireCooldown: 1.0 / fireRate,
         bulletSpeed: speed,
       );

  // ===========================================================================
  // KHAI BÁO 5 VŨ KHÍ CHUẨN CỦA SINH VIÊN HUIT
  // ===========================================================================

  /// 1. Bút bi: bắn nhanh, sát thương thấp, đạn mực 3 frame + vệt xanh ngắn, muzzle flash nhỏ
  static const WeaponConfig pen = WeaponConfig(
    kind: WeaponKind.pen,
    name: 'Bút Bi Thần Tốc',
    assetPath: 'assets/images/${GameConstants.weaponPenPath}',
    flamePath: GameConstants.weaponPenPath,
    fireRate: 5.0, // cooldown 0.20s
    damage: 24.0,
    speed: 540.0,
    pierce: 0,
    bounce: 0,
    knockback: 6.0,
    bulletColor: GameConstants.pixelCyan,
    secondaryColor: GameConstants.pixelHuitBlue,
    bulletVisualStyle: BulletVisualStyle.penInk,
    hitParticleCount: 3,
    sfxHook: GameConstants.sfxShootAudio,
    strategy: PenWeaponStrategy(),
  );

  /// 2. Laptop: giữ nạp 0.4s bắn laser xuyên mọi quái trên đường thẳng + glow + giật nhẹ camera
  static const WeaponConfig laptop = WeaponConfig(
    kind: WeaponKind.laptop,
    name: 'Laptop Laser Code',
    assetPath: 'assets/images/${GameConstants.weaponLaptopPath}',
    flamePath: GameConstants.weaponLaptopPath,
    fireRate: 2.0,
    damage: 64.0,
    speed: 1400.0,
    pierce: 999,
    bounce: 0,
    knockback: 16.0,
    chargeDuration: 0.40,
    bulletColor: GameConstants.pixelCyan,
    secondaryColor: GameConstants.pixelWhite,
    hitParticleCount: 6,
    sfxHook: '', // Để trống hook cho SFX laser riêng
    strategy: LaptopLaserWeaponStrategy(),
  );

  /// 3. USB: ném xoay như shuriken (4 frame xoay), nảy tường tối đa 2 lần, sát thương mỗi lần nảy
  static const WeaponConfig usb = WeaponConfig(
    kind: WeaponKind.usb,
    name: 'USB Phi Tiêu',
    assetPath: 'assets/images/${GameConstants.weaponUsbPath}',
    flamePath: GameConstants.weaponUsbPath,
    fireRate: 3.6,
    damage: 28.0,
    speed: 520.0,
    pierce: 0,
    bounce: 2,
    knockback: 9.0,
    bulletColor: GameConstants.pixelGold,
    secondaryColor: GameConstants.pixelSlate,
    bulletVisualStyle: BulletVisualStyle.usbShuriken,
    hitParticleCount: 4,
    sfxHook: GameConstants.sfxShootAudio,
    strategy: UsbShurikenWeaponStrategy(),
  );

  /// 4. Trà sữa: đạn trân châu nảy nhẹ, trúng quái hồi máu nhỏ + hiệu ứng bong bóng khi trúng
  static const WeaponConfig boba = WeaponConfig(
    kind: WeaponKind.boba,
    name: 'Trà Sữa Trân Châu',
    assetPath: 'assets/images/${GameConstants.weaponBobaPath}',
    flamePath: GameConstants.weaponBobaPath,
    fireRate: 3.3,
    damage: 30.0,
    speed: 470.0,
    pierce: 0,
    bounce: 0,
    knockback: 8.0,
    healOnHit: 3.0,
    bulletColor: GameConstants.pixelTan,
    secondaryColor: GameConstants.pixelEmerald,
    bulletVisualStyle: BulletVisualStyle.bobaPearl,
    hitParticleCount: 5,
    hitBubbleEffect: true,
    sfxHook: '', // Để trống hook cho SFX bong bóng trà sữa
    strategy: BobaWeaponStrategy(),
  );

  /// 5. Giáo trình (cận chiến): vung theo cung tròn 4 frame + vệt quét, đẩy lùi quái mạnh
  static const WeaponConfig textbook = WeaponConfig(
    kind: WeaponKind.textbook,
    name: 'Giáo Trình Đại Cương',
    assetPath: 'assets/images/${GameConstants.weaponTextbookPath}',
    flamePath: GameConstants.weaponTextbookPath,
    fireRate: 2.5,
    damage: 46.0,
    speed: 0.0,
    pierce: 999,
    bounce: 0,
    knockback: 36.0,
    meleeRadius: 96.0,
    meleeArcRadians: 2.25, // ~129 độ
    bulletColor: GameConstants.pixelGold,
    secondaryColor: GameConstants.pixelWhite,
    hitParticleCount: 5,
    sfxHook: '', // Để trống hook cho SFX vung sách cận chiến
    strategy: TextbookMeleeWeaponStrategy(),
  );

  static const List<WeaponConfig> allWeapons = [
    pen,
    laptop,
    usb,
    boba,
    textbook,
  ];
}

// =============================================================================
// STRATEGY PATTERN CHO 5 LOẠI VŨ KHÍ (TUÂN THỦ POOL & 0 ALLOCATION Ở NHIỆM VỤ 2)
// =============================================================================

abstract class WeaponStrategy {
  const WeaponStrategy();

  /// Xử lý khi người chơi đang giữ hoặc nhả nút bắn trong mỗi frame.
  /// Trả về true nếu vũ khí vừa khai hỏa (để đặt lại cooldown).
  bool updateAndTryFire({
    required PlayerComponent player,
    required HuitDeadlineGame game,
    required WeaponConfig config,
    required Vector2 aimDir,
    required bool isShooting,
    required bool canFireNow,
    required double dt,
  }) {
    if (!isShooting || !canFireNow) {
      return false;
    }
    executeFire(
      player: player,
      game: game,
      config: config,
      aimDir: aimDir,
    );
    return true;
  }

  void executeFire({
    required PlayerComponent player,
    required HuitDeadlineGame game,
    required WeaponConfig config,
    required Vector2 aimDir,
  });

  static void playWeaponSfx(WeaponConfig config) {
    if (config.sfxHook.isEmpty) {
      AudioSettingsService.instance.playShoot();
      return;
    }
    AudioSettingsService.instance.playShoot();
  }
}

/// 1. Strategy Bút Bi: Bắn nhanh đạn mực 3 frame + vệt xanh ngắn + muzzle flash nhỏ từ pool
class PenWeaponStrategy extends WeaponStrategy {
  const PenWeaponStrategy();

  @override
  void executeFire({
    required PlayerComponent player,
    required HuitDeadlineGame game,
    required WeaponConfig config,
    required Vector2 aimDir,
  }) {
    WeaponStrategy.playWeaponSfx(config);
    final px = player.position.x;
    final py = player.position.y;
    final tipX = px + aimDir.x * 18.0;
    final tipY = py + aimDir.y * 18.0;

    // Muzzle flash nhỏ ở đầu ngòi bút (lấy từ pool trong CombatVfxLayerComponent)
    game.spawnMuzzleFlash(
      x: tipX,
      y: tipY,
      color: config.bulletColor,
      radius: 7.0,
    );

    game.spawnBullet(
      x: px + aimDir.x * 4.0,
      y: py + aimDir.y * 4.0,
      dirX: aimDir.x,
      dirY: aimDir.y,
      damage: config.damage * player.classInfo.damageMultiplier,
      speed: config.speed,
      color: config.bulletColor,
      maxDistance: GameConstants.bulletMaxDistance,
      isEnemyBullet: false,
      bulletRadius: 7.5,
      visualStyle: BulletVisualStyle.penInk,
      knockback: config.knockback,
      secondaryColor: config.secondaryColor,
    );
  }
}

/// 2. Strategy Laptop: Giữ nút nạp 0.4s rồi bắn tia laser xuyên toàn bộ quái trên đường thẳng
class LaptopLaserWeaponStrategy extends WeaponStrategy {
  const LaptopLaserWeaponStrategy();

  @override
  bool updateAndTryFire({
    required PlayerComponent player,
    required HuitDeadlineGame game,
    required WeaponConfig config,
    required Vector2 aimDir,
    required bool isShooting,
    required bool canFireNow,
    required double dt,
  }) {
    if (!isShooting) {
      player.weaponChargeTimer = 0.0;
      return false;
    }
    if (!canFireNow) {
      return false;
    }

    player.weaponChargeTimer += dt;
    final tipX = player.position.x + aimDir.x * 20.0;
    final tipY = player.position.y + aimDir.y * 20.0;

    // Hiệu ứng tụ năng lượng ở đầu Laptop trong 0.4s nạp
    if (player.weaponChargeTimer < config.chargeDuration) {
      final progress = (player.weaponChargeTimer / config.chargeDuration).clamp(
        0.0,
        1.0,
      );
      game.updateChargingOrb(
        x: tipX,
        y: tipY,
        progress: progress,
        color: config.bulletColor,
      );
      return false;
    }

    player.weaponChargeTimer = 0.0;
    executeFire(
      player: player,
      game: game,
      config: config,
      aimDir: aimDir,
    );
    return true;
  }

  @override
  void executeFire({
    required PlayerComponent player,
    required HuitDeadlineGame game,
    required WeaponConfig config,
    required Vector2 aimDir,
  }) {
    WeaponStrategy.playWeaponSfx(config);
    const laserLength = 640.0;
    const beamHalfWidth = 14.0;
    final startX = player.position.x + aimDir.x * 16.0;
    final startY = player.position.y + aimDir.y * 16.0;
    final endX = startX + aimDir.x * laserLength;
    final endY = startY + aimDir.y * laserLength;
    final finalDamage = config.damage * player.classInfo.damageMultiplier;

    // Hiệu ứng tia laser kéo dài + glow từ pool & giật nhẹ camera
    game.spawnLaserBeam(
      startX: startX,
      startY: startY,
      endX: endX,
      endY: endY,
      coreColor: config.secondaryColor,
      glowColor: config.bulletColor,
    );
    game.triggerScreenShake(intensity: 4.5, duration: 0.12);

    final abx = endX - startX;
    final aby = endY - startY;
    final abLenSq = abx * abx + aby * aby;

    // Xuyên MỌI quái trên đường thẳng (chỉ duyệt danh sách game.enemies đã cache)
    final enemies = game.enemies;
    for (int i = enemies.length - 1; i >= 0; i--) {
      final enemy = enemies[i];
      if (!enemy.isMounted || enemy.isDead || enemy.isVanishing) {
        continue;
      }
      final hitR = enemy.size.x * 0.45 + beamHalfWidth;
      if (_segmentHitsCircle(
        startX,
        startY,
        abx,
        aby,
        abLenSq,
        enemy.position.x,
        enemy.position.y,
        hitR,
      )) {
        enemy.takeDamage(
          finalDamage,
          aimDir,
          knockbackDistance: config.knockback,
        );
      }
    }

    final boss = game.boss;
    if (boss != null && boss.isMounted && !boss.isDead) {
      final bossR =
          (boss.size.x * GameConstants.bossHitboxRatio) * 0.5 + beamHalfWidth;
      if (_segmentHitsCircle(
        startX,
        startY,
        abx,
        aby,
        abLenSq,
        boss.position.x,
        boss.position.y,
        bossR,
      )) {
        boss.takeDamage(finalDamage);
      }
    }
  }

  static bool _segmentHitsCircle(
    double ax,
    double ay,
    double abx,
    double aby,
    double abLenSq,
    double cx,
    double cy,
    double radius,
  ) {
    double closestX = ax;
    double closestY = ay;
    if (abLenSq > 0.000001) {
      double t = ((cx - ax) * abx + (cy - ay) * aby) / abLenSq;
      if (t < 0.0) {
        t = 0.0;
      } else if (t > 1.0) {
        t = 1.0;
      }
      closestX = ax + abx * t;
      closestY = ay + aby * t;
    }
    final dx = cx - closestX;
    final dy = cy - closestY;
    return (dx * dx + dy * dy) <= radius * radius;
  }
}

/// 3. Strategy USB: Ném xoay 4 frame như shuriken, nảy tường tối đa 2 lần, sát thương mỗi lần nảy
class UsbShurikenWeaponStrategy extends WeaponStrategy {
  const UsbShurikenWeaponStrategy();

  @override
  void executeFire({
    required PlayerComponent player,
    required HuitDeadlineGame game,
    required WeaponConfig config,
    required Vector2 aimDir,
  }) {
    WeaponStrategy.playWeaponSfx(config);
    final px = player.position.x;
    final py = player.position.y;

    game.spawnMuzzleFlash(
      x: px + aimDir.x * 16.0,
      y: py + aimDir.y * 16.0,
      color: config.bulletColor,
      radius: 6.5,
    );

    game.spawnBullet(
      x: px + aimDir.x * 4.0,
      y: py + aimDir.y * 4.0,
      dirX: aimDir.x,
      dirY: aimDir.y,
      damage: config.damage * player.classInfo.damageMultiplier,
      speed: config.speed,
      color: config.bulletColor,
      maxDistance: GameConstants.bulletMaxDistance * 1.45,
      isEnemyBullet: false,
      bulletRadius: 9.0,
      visualStyle: BulletVisualStyle.usbShuriken,
      remainingBounces: config.bounce,
      knockback: config.knockback,
      secondaryColor: config.secondaryColor,
    );
  }
}

/// 4. Strategy Trà Sữa: Đạn trân châu nảy nhẹ, trúng quái hồi máu nhỏ cho người chơi + nổ bong bóng
class BobaWeaponStrategy extends WeaponStrategy {
  const BobaWeaponStrategy();

  @override
  void executeFire({
    required PlayerComponent player,
    required HuitDeadlineGame game,
    required WeaponConfig config,
    required Vector2 aimDir,
  }) {
    WeaponStrategy.playWeaponSfx(config);
    final px = player.position.x;
    final py = player.position.y;

    game.spawnMuzzleFlash(
      x: px + aimDir.x * 16.0,
      y: py + aimDir.y * 16.0,
      color: config.secondaryColor,
      radius: 7.5,
    );

    game.spawnBullet(
      x: px + aimDir.x * 4.0,
      y: py + aimDir.y * 4.0,
      dirX: aimDir.x,
      dirY: aimDir.y,
      damage: config.damage * player.classInfo.damageMultiplier,
      speed: config.speed,
      color: config.bulletColor,
      maxDistance: GameConstants.bulletMaxDistance,
      isEnemyBullet: false,
      bulletRadius: 8.5,
      visualStyle: BulletVisualStyle.bobaPearl,
      healOnHit: config.healOnHit,
      bubbleOnHit: config.hitBubbleEffect,
      knockback: config.knockback,
      secondaryColor: config.secondaryColor,
    );
  }
}

/// 5. Strategy Giáo Trình (Cận chiến): Vung theo cung tròn 4 frame + vệt quét, đẩy lùi quái
class TextbookMeleeWeaponStrategy extends WeaponStrategy {
  const TextbookMeleeWeaponStrategy();

  @override
  void executeFire({
    required PlayerComponent player,
    required HuitDeadlineGame game,
    required WeaponConfig config,
    required Vector2 aimDir,
  }) {
    WeaponStrategy.playWeaponSfx(config);
    final px = player.position.x;
    final py = player.position.y;
    final centerAngle = math.atan2(aimDir.y, aimDir.x);
    final finalDamage = config.damage * player.classInfo.damageMultiplier;
    final radius = config.meleeRadius;
    final minCos = math.cos(config.meleeArcRadians * 0.5);

    // Kích hoạt hoạt ảnh vung 4 frame + vệt quét cung tròn từ pool trong CombatVfxLayerComponent
    game.spawnMeleeSlashArc(
      x: px,
      y: py,
      centerAngle: centerAngle,
      sweepRadians: config.meleeArcRadians,
      radius: radius,
      primaryColor: config.bulletColor,
      secondaryColor: config.secondaryColor,
    );

    // Kiểm tra quái nằm trong hình quạt cận chiến (chỉ duyệt game.enemies đã cache)
    final enemies = game.enemies;
    for (int i = enemies.length - 1; i >= 0; i--) {
      final enemy = enemies[i];
      if (!enemy.isMounted || enemy.isDead || enemy.isVanishing) {
        continue;
      }
      final dx = enemy.position.x - px;
      final dy = enemy.position.y - py;
      final distSq = dx * dx + dy * dy;
      final maxR = radius + enemy.size.x * 0.45;
      if (distSq > maxR * maxR) {
        continue;
      }
      // Quái áp sát (< 26px) luôn trúng; ở xa hơn kiểm tra góc hình quạt
      bool inCone = distSq <= 26.0 * 26.0;
      if (!inCone && distSq > 0.0001) {
        final invDist = 1.0 / math.sqrt(distSq);
        final dot = (dx * invDist) * aimDir.x + (dy * invDist) * aimDir.y;
        inCone = dot >= minCos;
      }
      if (inCone) {
        enemy.takeDamage(
          finalDamage,
          aimDir,
          knockbackDistance: config.knockback,
        );
      }
    }

    final boss = game.boss;
    if (boss != null && boss.isMounted && !boss.isDead) {
      final dx = boss.position.x - px;
      final dy = boss.position.y - py;
      final distSq = dx * dx + dy * dy;
      final maxR =
          radius + (boss.size.x * GameConstants.bossHitboxRatio) * 0.5;
      if (distSq <= maxR * maxR) {
        boss.takeDamage(finalDamage);
      }
    }
  }
}
