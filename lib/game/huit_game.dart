import 'dart:async';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/arena_background.dart';
import '../components/boss_component.dart';
import '../components/bullet_component.dart';
import '../components/combat_vfx_layer.dart';
import '../components/enemy_component.dart';
import '../components/item_component.dart';
import '../components/player_component.dart';
import '../constants.dart';
import '../models/player_class.dart';
import '../models/stage_info.dart';
import '../models/weapon_config.dart';
import '../services/stage_progress_service.dart';
import '../utils/pixel_sprite_cache.dart';

/// Trạng thái kết quả ván chơi
enum GameMatchResult {
  playing,
  victory,
  gameOver,
}

/// Core FlameGame class tối ưu 60 FPS với bộ SpriteAnimation cache 1 lần
/// và hệ thống 5 vũ khí Strategy riêng (Bút bi, Laptop laser, USB nảy, Trà sữa hồi máu, Giáo trình cận chiến).
class HuitDeadlineGame extends FlameGame
    with HasCollisionDetection, TapCallbacks, KeyboardEvents {
  final PlayerClassInfo selectedClass;
  final StageInfo selectedStage;
  final double survivalDurationSeconds;
  final math.Random _rng = math.Random();

  int score = 0;
  int highScore = 0;
  int coinCount = 0;
  int killCount = 0;

  double elapsedSurvivalSeconds = 0.0;
  int _lastDisplayedSurvivalSeconds = -1;
  bool isBossPhase = false;
  bool _bossSpawned = false;
  double _bossIntroDelayTimer = 0.0;
  double _enemySpawnTimer = 0.8;

  bool isGameOver = false;
  bool isVictory = false;
  bool isPausedByUi = false;

  // Screen shake & reusable camera target vector (dùng setter camera.viewfinder.position = _cameraTarget)
  double _shakeTimer = 0.0;
  double _shakeIntensity = 0.0;
  final Vector2 _cameraTarget = Vector2(
    GameConstants.arenaWidth * 0.5,
    GameConstants.arenaHeight * 0.5,
  );

  // Bộ đệm biên khung nhìn camera cho viewport culling (cập nhật 1 lần/frame)
  double camLeft = 0.0;
  double camTop = 0.0;
  double camRight = GameConstants.arenaWidth;
  double camBottom = GameConstants.arenaHeight;

  // Registry quản lý thực thể (thêm ở onMount, xóa ở onRemove — không quét world.children)
  final List<EnemyComponent> enemies = [];
  final List<ItemComponent> items = [];
  final List<BulletComponent> activeBullets = [];

  // Object Pool cho đạn để tái sử dụng thay vì new/GC liên tục
  final List<BulletComponent> _bulletPool = [];
  bool _isResettingOrDisposing = false;

  // Lớp VFX dùng pool (hạt hiệu ứng, bong bóng, laser, vệt chém, số sát thương)
  CombatVfxLayerComponent? _vfxLayer;

  // Cache sprite & SpriteAnimation tạo MỘT LẦN trong onLoad
  final PixelSpriteCache spriteCache = PixelSpriteCache();

  // Đo thời gian update (chỉ chạy trong debug/profile/SHOW_FPS)
  final Stopwatch? _updateStopwatch =
      (kDebugMode || kProfileMode || GameConstants.showFpsOverlayEnv)
      ? Stopwatch()
      : null;
  double lastAvgUpdateMs = 0.0;

  // Reactive HUD Notifiers
  late final ValueNotifier<double> playerHpNotifier = ValueNotifier(
    selectedClass.maxHp,
  );
  late final ValueNotifier<double> playerMaxHpNotifier = ValueNotifier(
    selectedClass.maxHp,
  );
  final ValueNotifier<int> shieldCountNotifier = ValueNotifier(0);
  late final ValueNotifier<double> remainingSurvivalSecondsNotifier =
      ValueNotifier(survivalDurationSeconds);
  final ValueNotifier<double> dashCooldownNotifier = ValueNotifier(0.0);
  final ValueNotifier<int> activeWeaponIndexNotifier = ValueNotifier(0);
  final ValueNotifier<int> scoreNotifier = ValueNotifier(0);
  final ValueNotifier<int> coinCountNotifier = ValueNotifier(0);
  final ValueNotifier<int> killCountNotifier = ValueNotifier(0);
  final ValueNotifier<bool> isBossPhaseNotifier = ValueNotifier(false);
  late final ValueNotifier<double> bossHpNotifier = ValueNotifier(
    selectedStage.bossMaxHp,
  );
  late final ValueNotifier<double> bossMaxHpNotifier = ValueNotifier(
    selectedStage.bossMaxHp,
  );
  final ValueNotifier<bool> showBossWarningNotifier = ValueNotifier(false);
  final ValueNotifier<GameMatchResult> matchResultNotifier = ValueNotifier(
    GameMatchResult.playing,
  );

  PlayerComponent? _player;
  PlayerComponent? get player => _player;

  BossComponent? _boss;
  BossComponent? get boss => _boss;

  final Set<LogicalKeyboardKey> _pressedMoveKeys = {};
  final Vector2 _keyboardMoveDir = Vector2.zero();

  HuitDeadlineGame({
    required this.selectedClass,
    StageInfo? selectedStage,
    this.survivalDurationSeconds = GameConstants.survivalDurationSeconds,
  }) : selectedStage = selectedStage ?? StageInfo.defaultStage;

  // --- Sprite Cache Getters ---
  Sprite? get sharedShadowSprite => spriteCache.groundShadowSprite;
  Sprite? get playerDashGhostSprite => spriteCache.playerDashGhostSprite;
  Sprite? getEnemyHitFlashSprite(String flamePath) =>
      spriteCache.getHitFlashSprite(flamePath);
  Sprite? get bossHitFlashSprite => spriteCache.bossHitFlashSprite;
  Sprite? get bossChargeTintSprite => spriteCache.bossChargeTintSprite;
  int get activeParticleCount => _vfxLayer?.activeParticleCount ?? 0;

  @override
  Color backgroundColor() => GameConstants.backgroundColor;

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    // Đặt tâm camera vào giữa đấu trường ngay lập tức trước mọi lệnh async
    camera.viewfinder.anchor = Anchor.center;
    _cameraTarget.setValues(
      GameConstants.arenaWidth * 0.5,
      GameConstants.arenaHeight * 0.5,
    );
    camera.viewfinder.position = _cameraTarget;

    try {
      final prefs = await SharedPreferences.getInstance();
      highScore = prefs.getInt(GameConstants.highScoreKey) ?? 0;
    } catch (_) {}

    // Nạp trước TOÀN BỘ ảnh cơ sở trong onLoad bằng images.loadAll
    await images.loadAll([
      selectedStage.flameMapPath,
      selectedStage.flameBossPath,
      selectedClass.flameSpritePath,
      GameConstants.weaponPenPath,
      GameConstants.weaponLaptopPath,
      GameConstants.weaponUsbPath,
      GameConstants.weaponBobaPath,
      GameConstants.enemyDeadlinePath,
      GameConstants.enemyEmailPath,
      GameConstants.enemyQuizPath,
      GameConstants.itemCoffeePath,
      GameConstants.itemNoodlePath,
      GameConstants.itemShieldPath,
      GameConstants.itemCoinPath,
    ]);

    // Tạo MỘT LẦN và cache toàn bộ SpriteAnimation + bóng chân + bản nháy trắng
    await _bakeSharedSpritesAndAnimations();

    _lastDisplayedSurvivalSeconds = survivalDurationSeconds.ceil();
    _setupWorldEntities();
  }

  @override
  void onMount() {
    super.onMount();
    _syncCameraToPlayer(0.0);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _syncCameraToPlayer(0.0);
  }

  Future<void> _bakeSharedSpritesAndAnimations() async {
    await spriteCache.bakeGroundShadowSprite();

    final playerImg = images.fromCache(selectedClass.flameSpritePath);
    spriteCache.playerDashGhostSprite = await spriteCache.bakeTintedSprite(
      source: playerImg,
      tintColor: GameConstants.dashCyanColor,
      blendMode: BlendMode.srcATop,
    );

    await spriteCache.buildPlayerAnimations(
      images: images,
      baseFlamePath: selectedClass.flameSpritePath,
    );
    await spriteCache.buildAllEnemyAnimations(images);
    await spriteCache.buildBossAnimations(
      images: images,
      baseFlamePath: selectedStage.flameBossPath,
    );
    await spriteCache.buildAllItemAnimations(images);
  }

  void _setupWorldEntities() {
    world.add(ArenaBackgroundComponent());

    final vfxLayer = CombatVfxLayerComponent();
    _vfxLayer = vfxLayer;
    world.add(vfxLayer);

    final spawnPosition = Vector2(
      GameConstants.arenaWidth * 0.5,
      GameConstants.arenaHeight * 0.5,
    );

    final playerComp = PlayerComponent(
      classInfo: selectedClass,
      position: spawnPosition,
    );
    _player = playerComp;
    world.add(playerComp);

    camera.viewfinder.anchor = Anchor.center;
    _syncCameraToPlayer(0.0);
  }

  /// Đồng bộ camera bám đúng vị trí nhân vật (dùng setter camera.viewfinder.position = _cameraTarget
  /// để Flame cập nhật ma trận Viewfinder ngay cả khi nhân vật đang mount).
  void _syncCameraToPlayer(double dt) {
    camera.viewfinder.anchor = Anchor.center;
    final activePlayer = _player;
    double tx = activePlayer?.position.x ?? (GameConstants.arenaWidth * 0.5);
    double ty = activePlayer?.position.y ?? (GameConstants.arenaHeight * 0.5);

    if (_shakeTimer > 0 && dt > 0) {
      _shakeTimer = math.max(0.0, _shakeTimer - dt);
      tx += (_rng.nextDouble() * 2 - 1) * _shakeIntensity;
      ty += (_rng.nextDouble() * 2 - 1) * _shakeIntensity;
    }

    _cameraTarget.setValues(tx, ty);
    // BẮT BUỘC gọi setter `camera.viewfinder.position = ...` để cập nhật Transform2D của Viewfinder
    camera.viewfinder.position = _cameraTarget;
    _updateCameraCullBounds(tx, ty);
  }

  // --- Registry & Object Pool Helpers ---

  void registerEnemy(EnemyComponent enemy) {
    if (!enemies.contains(enemy)) {
      enemies.add(enemy);
    }
  }

  void unregisterEnemy(EnemyComponent enemy) {
    enemies.remove(enemy);
  }

  void registerItem(ItemComponent item) {
    items.add(item);
  }

  void unregisterItem(ItemComponent item) {
    items.remove(item);
  }

  void registerBullet(BulletComponent bullet) {
    activeBullets.add(bullet);
  }

  void unregisterBullet(BulletComponent bullet) {
    activeBullets.remove(bullet);
  }

  /// Lấy đạn từ Object Pool (hoặc tạo mới nếu pool trống) và gắn vào world
  BulletComponent? spawnBullet({
    required double x,
    required double y,
    required double dirX,
    required double dirY,
    required double damage,
    required double speed,
    required Color color,
    required double maxDistance,
    required bool isEnemyBullet,
    double bulletRadius = 8.0,
    BulletVisualStyle visualStyle = BulletVisualStyle.standard,
    int remainingBounces = 0,
    double healOnHit = 0.0,
    bool bubbleOnHit = false,
    double knockback = 7.0,
    Color secondaryColor = GameConstants.pixelHuitBlue,
  }) {
    if (activeBullets.length >= GameConstants.maxActiveBullets) {
      return null;
    }

    BulletComponent? recycled;
    for (int i = _bulletPool.length - 1; i >= 0; i--) {
      final candidate = _bulletPool[i];
      if (!candidate.isMounted && candidate.parent == null) {
        _bulletPool.removeAt(i);
        recycled = candidate;
        break;
      }
    }

    final BulletComponent bullet;
    if (recycled != null) {
      bullet = recycled;
      bullet.reset(
        x: x,
        y: y,
        dirX: dirX,
        dirY: dirY,
        damage: damage,
        speed: speed,
        color: color,
        maxDistance: maxDistance,
        isEnemyBullet: isEnemyBullet,
        bulletRadius: bulletRadius,
        visualStyle: visualStyle,
        remainingBounces: remainingBounces,
        healOnHit: healOnHit,
        bubbleOnHit: bubbleOnHit,
        knockback: knockback,
        secondaryColor: secondaryColor,
      );
    } else {
      bullet = BulletComponent(
        position: Vector2(x, y),
        direction: Vector2(dirX, dirY),
        damage: damage,
        speed: speed,
        color: color,
        secondaryColor: secondaryColor,
        maxDistance: maxDistance,
        isEnemyBullet: isEnemyBullet,
        bulletRadius: bulletRadius,
        visualStyle: visualStyle,
        remainingBounces: remainingBounces,
        healOnHit: healOnHit,
        bubbleOnHit: bubbleOnHit,
        knockback: knockback,
      );
    }

    world.add(bullet);
    return bullet;
  }

  /// Trả đạn về Object Pool ngay trong onRemove()
  void recycleBullet(BulletComponent bullet) {
    if (_isResettingOrDisposing ||
        bullet.inPool ||
        _bulletPool.length >= GameConstants.maxActiveBullets) {
      return;
    }
    bullet.inPool = true;
    _bulletPool.add(bullet);
  }

  void spawnHitParticles({
    required double x,
    required double y,
    required Color color,
    int count = 4,
    double speed = 110.0,
    double size = 4.0,
    double life = 0.24,
    bool isBubble = false,
  }) {
    _vfxLayer?.spawnParticles(
      x: x,
      y: y,
      color: color,
      count: count,
      speed: speed,
      size: size,
      life: life,
      isBubble: isBubble,
    );
  }

  void spawnMuzzleFlash({
    required double x,
    required double y,
    required Color color,
    double radius = 7.0,
  }) {
    _vfxLayer?.spawnMuzzleFlash(
      x: x,
      y: y,
      color: color,
      radius: radius,
    );
  }

  void updateChargingOrb({
    required double x,
    required double y,
    required double progress,
    required Color color,
  }) {
    _vfxLayer?.updateChargingOrb(
      x: x,
      y: y,
      progress: progress,
      color: color,
    );
  }

  void spawnLaserBeam({
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    required Color coreColor,
    required Color glowColor,
  }) {
    _vfxLayer?.spawnLaserBeam(
      startX: startX,
      startY: startY,
      endX: endX,
      endY: endY,
      coreColor: coreColor,
      glowColor: glowColor,
    );
  }

  void spawnMeleeSlashArc({
    required double x,
    required double y,
    required double centerAngle,
    required double sweepRadians,
    required double radius,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    _vfxLayer?.spawnMeleeSlashArc(
      x: x,
      y: y,
      centerAngle: centerAngle,
      sweepRadians: sweepRadians,
      radius: radius,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
    );
  }

  void spawnDamageNumber({
    required double x,
    required double y,
    required int amount,
    Color color = GameConstants.pixelWhite,
  }) {
    _vfxLayer?.spawnDamageNumber(x: x, y: y, amount: amount, color: color);
  }

  bool isVisibleInCamera(double x, double y, double halfW, double halfH) {
    if (size.x <= 0 || size.y <= 0) {
      return true;
    }
    return x + halfW >= camLeft &&
        x - halfW <= camRight &&
        y + halfH >= camTop &&
        y - halfH <= camBottom;
  }

  void _updateCameraCullBounds(double camX, double camY) {
    final viewW = size.x > 0 ? size.x : 960.0;
    final viewH = size.y > 0 ? size.y : 540.0;
    final halfW = viewW * 0.5 + GameConstants.cameraCullMargin;
    final halfH = viewH * 0.5 + GameConstants.cameraCullMargin;
    camLeft = camX - halfW;
    camRight = camX + halfW;
    camTop = camY - halfH;
    camBottom = camY + halfH;
  }

  @override
  void update(double dt) {
    final sw = _updateStopwatch;
    if (sw != null) {
      sw
        ..reset()
        ..start();
    }

    // Kẹp dt mỗi bước mô phỏng tối đa 1/30s
    if (dt > GameConstants.maxDeltaTime * 2.0) {
      const clampedDt = GameConstants.maxDeltaTime;
      super.update(clampedDt);
      _updateGameLogic(clampedDt);
    } else if (dt > GameConstants.maxDeltaTime) {
      final halfDt = dt * 0.5;
      super.update(halfDt);
      _updateGameLogic(halfDt);
      super.update(halfDt);
      _updateGameLogic(halfDt);
    } else {
      super.update(dt);
      _updateGameLogic(dt);
    }

    if (sw != null) {
      sw.stop();
      final ms = sw.elapsedMicroseconds / 1000.0;
      lastAvgUpdateMs = lastAvgUpdateMs == 0.0
          ? ms
          : (lastAvgUpdateMs * 0.9 + ms * 0.1);
    }
  }

  void _updateGameLogic(double dt) {
    // 1. Luôn đồng bộ camera bám vào nhân vật ở mọi frame (kể cả frame đầu vừa vào màn)
    _syncCameraToPlayer(dt);

    if (isPausedByUi || isGameOver || isVictory) {
      return;
    }

    // 2. Cơ chế đồng hồ Sinh tồn 5 phút -> Quái biến mất -> Boss xuất hiện
    if (!isBossPhase) {
      elapsedSurvivalSeconds += dt;
      final remaining = math.max(
        0.0,
        survivalDurationSeconds - elapsedSurvivalSeconds,
      );

      final displayedSeconds = remaining.ceil();
      if (displayedSeconds != _lastDisplayedSurvivalSeconds) {
        _lastDisplayedSurvivalSeconds = displayedSeconds;
        remainingSurvivalSecondsNotifier.value = displayedSeconds.toDouble();
      }

      if (elapsedSurvivalSeconds >= survivalDurationSeconds) {
        _transitionToBossPhase();
        return;
      }

      _enemySpawnTimer -= dt;
      if (_enemySpawnTimer <= 0) {
        _spawnNormalEnemyWave();
        final progress = (elapsedSurvivalSeconds / survivalDurationSeconds)
            .clamp(0.0, 1.0);
        _enemySpawnTimer = 1.45 - progress * 0.87;
      }
    } else if (!_bossSpawned) {
      _bossIntroDelayTimer -= dt;
      if (_bossIntroDelayTimer <= 0) {
        _spawnStageBoss();
      }
    }
  }

  void _spawnNormalEnemyWave() {
    final activePlayer = _player;
    if (activePlayer == null || !activePlayer.isMounted) {
      return;
    }

    if (enemies.length >= GameConstants.maxEnemies) {
      return;
    }

    final progress = (elapsedSurvivalSeconds / survivalDurationSeconds).clamp(
      0.0,
      1.0,
    );
    final batchSize = progress > 0.65 ? 2 : 1;
    final difficultyScale = 1.0 + progress * 0.65;
    final px = activePlayer.position.x;
    final py = activePlayer.position.y;
    const margin = GameConstants.arenaPlayableMargin + 24.0;
    const maxX = GameConstants.arenaWidth - margin;
    const maxY = GameConstants.arenaHeight - margin;

    for (int i = 0; i < batchSize; i++) {
      if (enemies.length + i >= GameConstants.maxEnemies) {
        break;
      }

      final angle = _rng.nextDouble() * math.pi * 2;
      final distance = 390.0 + _rng.nextDouble() * 140.0;
      double sx = (px + math.cos(angle) * distance).clamp(margin, maxX);
      double sy = (py + math.sin(angle) * distance).clamp(margin, maxY);

      final dx = sx - px;
      final dy = sy - py;
      if (dx * dx + dy * dy < 220.0 * 220.0) {
        final fallbackAngle = angle + math.pi;
        sx = (px + math.cos(fallbackAngle) * 360.0).clamp(margin, maxX);
        sy = (py + math.sin(fallbackAngle) * 360.0).clamp(margin, maxY);
      }

      final typeRoll = _rng.nextDouble();
      final NormalEnemyType enemyType;
      if (typeRoll < 0.50) {
        enemyType = NormalEnemyType.deadline;
      } else if (typeRoll < 0.82) {
        enemyType = NormalEnemyType.email;
      } else {
        enemyType = NormalEnemyType.quiz;
      }

      world.add(
        EnemyComponent(
          position: Vector2(sx, sy),
          type: enemyType,
          difficultyScale: difficultyScale,
        ),
      );
    }
  }

  void _transitionToBossPhase() {
    if (isBossPhase) {
      return;
    }
    isBossPhase = true;
    _lastDisplayedSurvivalSeconds = 0;
    remainingSurvivalSecondsNotifier.value = 0.0;
    isBossPhaseNotifier.value = true;
    showBossWarningNotifier.value = true;
    _bossIntroDelayTimer = 1.6;
    triggerScreenShake(intensity: 6.0, duration: 0.4);

    for (int i = enemies.length - 1; i >= 0; i--) {
      enemies[i].vanishAndDisappear();
    }
    for (int i = activeBullets.length - 1; i >= 0; i--) {
      final bullet = activeBullets[i];
      if (bullet.isEnemyBullet) {
        bullet.consume();
      }
    }
  }

  void _spawnStageBoss() {
    if (_bossSpawned) {
      return;
    }
    _bossSpawned = true;
    showBossWarningNotifier.value = false;

    final activePlayer = _player;
    const centerX = GameConstants.arenaWidth * 0.5;
    const centerY = GameConstants.arenaHeight * 0.5;
    double bx = centerX;
    double by = centerY;

    if (activePlayer != null) {
      final dx = activePlayer.position.x - centerX;
      final dy = activePlayer.position.y - centerY;
      if (dx * dx + dy * dy < 240.0 * 240.0) {
        bx = (activePlayer.position.x + 280.0).clamp(
          GameConstants.arenaPlayableMargin + 100.0,
          GameConstants.arenaWidth - GameConstants.arenaPlayableMargin - 100.0,
        );
        by = activePlayer.position.y;
      }
    }

    final bossComp = BossComponent(
      position: Vector2(bx, by),
      stage: selectedStage,
    );
    _boss = bossComp;
    bossMaxHpNotifier.value = bossComp.maxHp;
    bossHpNotifier.value = bossComp.hp;
    world.add(bossComp);
    triggerScreenShake(intensity: 11.0, duration: 0.35);
  }

  void setMoveDirection(Vector2 direction) {
    _player?.setMoveDirection(direction);
  }

  void setShooting(bool active, {Vector2? aimDirection}) {
    _player?.setShooting(active, aimDirection: aimDirection);
  }

  bool triggerDash() {
    return _player?.triggerDash() ?? false;
  }

  void switchWeapon() {
    _player?.switchWeapon();
  }

  void triggerScreenShake({double intensity = 6.0, double duration = 0.2}) {
    _shakeIntensity = math.max(_shakeIntensity, intensity);
    _shakeTimer = math.max(_shakeTimer, duration);
  }

  void onEnemyKilledAt(double x, double y, int points) {
    killCount++;
    killCountNotifier.value = killCount;
    addScore(points);

    final roll = _rng.nextDouble();
    if (roll < 0.26) {
      final itemRoll = _rng.nextDouble();
      final DropItemType dropType;
      if (itemRoll < 0.38) {
        dropType = DropItemType.coin;
      } else if (itemRoll < 0.65) {
        dropType = DropItemType.noodle;
      } else if (itemRoll < 0.85) {
        dropType = DropItemType.coffee;
      } else {
        dropType = DropItemType.shield;
      }
      world.add(ItemComponent(position: Vector2(x, y), type: dropType));
    }
  }

  void onEnemyKilled(Vector2 dropPosition, int points) {
    onEnemyKilledAt(dropPosition.x, dropPosition.y, points);
  }

  void onBossDefeated(Vector2 position) {
    bossHpNotifier.value = 0.0;
    addCoinsAndScore(coins: 150, scoreBonus: 1500);
    for (int i = 0; i < 6; i++) {
      final a = (math.pi * 2 / 6) * i;
      world.add(
        ItemComponent(
          position: Vector2(
            position.x + math.cos(a) * 48.0,
            position.y + math.sin(a) * 48.0,
          ),
          type: DropItemType.coin,
        ),
      );
    }
    triggerVictory();
  }

  void updateBossHud(double currentHp, double maxHp) {
    bossMaxHpNotifier.value = maxHp;
    bossHpNotifier.value = currentHp;
  }

  void addCoinsAndScore({required int coins, required int scoreBonus}) {
    coinCount += coins;
    coinCountNotifier.value = coinCount;
    addScore(scoreBonus);
  }

  void addScore(int points) {
    score += points;
    scoreNotifier.value = score;
  }

  Future<void> checkAndSaveHighScore() async {
    if (score > highScore) {
      highScore = score;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(GameConstants.highScoreKey, highScore);
      } catch (_) {}
    }
  }

  void triggerGameOver() {
    if (isGameOver || isVictory) {
      return;
    }
    isGameOver = true;
    matchResultNotifier.value = GameMatchResult.gameOver;
    checkAndSaveHighScore();
  }

  void triggerVictory() {
    if (isGameOver || isVictory) {
      return;
    }
    isVictory = true;
    addScore(500);
    matchResultNotifier.value = GameMatchResult.victory;
    checkAndSaveHighScore();
    StageProgressService.instance.markStageCompleted(selectedStage);
  }

  void resetGame() {
    _isResettingOrDisposing = true;
    isGameOver = false;
    isVictory = false;
    isPausedByUi = false;
    isBossPhase = false;
    _bossSpawned = false;
    _bossIntroDelayTimer = 0.0;
    _enemySpawnTimer = 0.8;
    elapsedSurvivalSeconds = 0.0;
    _lastDisplayedSurvivalSeconds = survivalDurationSeconds.ceil();
    score = 0;
    coinCount = 0;
    killCount = 0;
    _boss = null;

    playerHpNotifier.value = selectedClass.maxHp;
    playerMaxHpNotifier.value = selectedClass.maxHp;
    shieldCountNotifier.value = 0;
    remainingSurvivalSecondsNotifier.value = survivalDurationSeconds;
    dashCooldownNotifier.value = 0.0;
    activeWeaponIndexNotifier.value = 0;
    scoreNotifier.value = 0;
    coinCountNotifier.value = 0;
    killCountNotifier.value = 0;
    isBossPhaseNotifier.value = false;
    showBossWarningNotifier.value = false;
    bossMaxHpNotifier.value = selectedStage.bossMaxHp;
    bossHpNotifier.value = selectedStage.bossMaxHp;
    matchResultNotifier.value = GameMatchResult.playing;

    _vfxLayer?.clearAll();
    enemies.clear();
    items.clear();
    activeBullets.clear();
    _bulletPool.clear();
    world.removeAll(world.children.toList());
    _isResettingOrDisposing = false;
    _setupWorldEntities();
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final key = event.logicalKey;
    final isMoveKey =
        key == LogicalKeyboardKey.keyW ||
        key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;

    if (isMoveKey) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _pressedMoveKeys.add(key);
      } else if (event is KeyUpEvent) {
        _pressedMoveKeys.remove(key);
      }

      double dx = 0;
      double dy = 0;
      if (_pressedMoveKeys.contains(LogicalKeyboardKey.keyA) ||
          _pressedMoveKeys.contains(LogicalKeyboardKey.arrowLeft)) {
        dx -= 1;
      }
      if (_pressedMoveKeys.contains(LogicalKeyboardKey.keyD) ||
          _pressedMoveKeys.contains(LogicalKeyboardKey.arrowRight)) {
        dx += 1;
      }
      if (_pressedMoveKeys.contains(LogicalKeyboardKey.keyW) ||
          _pressedMoveKeys.contains(LogicalKeyboardKey.arrowUp)) {
        dy -= 1;
      }
      if (_pressedMoveKeys.contains(LogicalKeyboardKey.keyS) ||
          _pressedMoveKeys.contains(LogicalKeyboardKey.arrowDown)) {
        dy += 1;
      }
      _keyboardMoveDir.setValues(dx, dy);
      setMoveDirection(_keyboardMoveDir);
    }

    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyJ) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        setShooting(true);
      } else if (event is KeyUpEvent) {
        setShooting(false);
      }
    }

    if ((key == LogicalKeyboardKey.shiftLeft ||
            key == LogicalKeyboardKey.keyK) &&
        event is KeyDownEvent) {
      triggerDash();
    }

    if ((key == LogicalKeyboardKey.keyQ || key == LogicalKeyboardKey.keyE) &&
        event is KeyDownEvent) {
      switchWeapon();
    }

    return KeyEventResult.handled;
  }

  @override
  void onRemove() {
    _isResettingOrDisposing = true;
    enemies.clear();
    items.clear();
    activeBullets.clear();
    _bulletPool.clear();
    spriteCache.dispose();

    playerHpNotifier.dispose();
    playerMaxHpNotifier.dispose();
    shieldCountNotifier.dispose();
    remainingSurvivalSecondsNotifier.dispose();
    dashCooldownNotifier.dispose();
    activeWeaponIndexNotifier.dispose();
    scoreNotifier.dispose();
    coinCountNotifier.dispose();
    killCountNotifier.dispose();
    isBossPhaseNotifier.dispose();
    bossHpNotifier.dispose();
    bossMaxHpNotifier.dispose();
    showBossWarningNotifier.dispose();
    matchResultNotifier.dispose();
    super.onRemove();
  }
}
