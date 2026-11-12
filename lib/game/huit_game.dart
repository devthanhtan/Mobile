import 'dart:async';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/arena_background.dart';
import '../components/boss_component.dart';
import '../components/bullet_component.dart';
import '../components/enemy_component.dart';
import '../components/item_component.dart';
import '../components/player_component.dart';
import '../constants.dart';
import '../models/player_class.dart';
import '../models/stage_info.dart';
import '../services/stage_progress_service.dart';

/// Trạng thái kết quả ván chơi
enum GameMatchResult {
  playing,
  victory,
  gameOver,
}

/// Core FlameGame class quản lý chế độ sinh tồn 5 phút -> Quái biến mất -> Boss xuất hiện
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
  bool isBossPhase = false;
  bool _bossSpawned = false;
  double _bossIntroDelayTimer = 0.0;
  double _enemySpawnTimer = 0.8;

  bool isGameOver = false;
  bool isVictory = false;
  bool isPausedByUi = false;

  // Screen shake
  double _shakeTimer = 0.0;
  double _shakeIntensity = 0.0;

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

  @override
  Color backgroundColor() => GameConstants.backgroundColor;

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    try {
      final prefs = await SharedPreferences.getInstance();
      highScore = prefs.getInt(GameConstants.highScoreKey) ?? 0;
    } catch (_) {
      // Bỏ qua nếu môi trường test không mock SharedPreferences
    }

    // Nạp sẵn các sprite nhỏ dùng thường xuyên để spawn mượt, không chặn map nền
    await images.loadAll([
      selectedClass.flameSpritePath,
      selectedClass.primaryWeapon.flamePath,
      selectedClass.secondaryWeapon.flamePath,
      GameConstants.enemyDeadlinePath,
      GameConstants.enemyEmailPath,
      GameConstants.enemyQuizPath,
      GameConstants.itemCoffeePath,
      GameConstants.itemNoodlePath,
      GameConstants.itemShieldPath,
      GameConstants.itemCoinPath,
    ]);

    _setupWorldEntities();
  }

  void _setupWorldEntities() {
    // QUAN TRỌNG: Không await world.add(...) trong onLoad() để tránh deadlock mounted
    world.add(ArenaBackgroundComponent());

    final spawnPosition = Vector2(
      GameConstants.arenaWidth / 2,
      GameConstants.arenaHeight / 2,
    );

    final playerComp = PlayerComponent(
      classInfo: selectedClass,
      position: spawnPosition,
    );
    _player = playerComp;
    world.add(playerComp);

    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = spawnPosition.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isPausedByUi || isGameOver || isVictory) {
      return;
    }

    // 1. Theo dõi người chơi & rung màn hình nhẹ
    final activePlayer = _player;
    if (activePlayer != null && activePlayer.isMounted) {
      final targetCam = activePlayer.position.clone();
      if (_shakeTimer > 0) {
        _shakeTimer = math.max(0.0, _shakeTimer - dt);
        targetCam.x += (_rng.nextDouble() * 2 - 1) * _shakeIntensity;
        targetCam.y += (_rng.nextDouble() * 2 - 1) * _shakeIntensity;
      }
      camera.viewfinder.position = targetCam;
    }

    // 2. Cơ chế đồng hồ Sinh tồn 5 phút -> Quái biến mất -> Boss xuất hiện
    if (!isBossPhase) {
      elapsedSurvivalSeconds += dt;
      final remaining = math.max(
        0.0,
        survivalDurationSeconds - elapsedSurvivalSeconds,
      );
      remainingSurvivalSecondsNotifier.value = remaining;

      if (elapsedSurvivalSeconds >= survivalDurationSeconds) {
        _transitionToBossPhase();
        return;
      }

      // Sinh quái thường xung quanh người chơi
      _enemySpawnTimer -= dt;
      if (_enemySpawnTimer <= 0) {
        _spawnNormalEnemyWave();
        final progress = (elapsedSurvivalSeconds / survivalDurationSeconds)
            .clamp(0.0, 1.0);
        // Nhịp spawn tăng dần từ ~1.45s xuống ~0.58s theo thời gian 5 phút
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

    final currentEnemies = world.children.whereType<EnemyComponent>().length;
    if (currentEnemies >= 34) {
      return;
    }

    final progress = (elapsedSurvivalSeconds / survivalDurationSeconds).clamp(
      0.0,
      1.0,
    );
    final batchSize = progress > 0.65 ? 2 : 1;
    final difficultyScale = 1.0 + progress * 0.65;

    for (int i = 0; i < batchSize; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final distance = 390.0 + _rng.nextDouble() * 140.0;
      final spawnPos =
          activePlayer.position +
          Vector2(math.cos(angle) * distance, math.sin(angle) * distance);

      const margin = GameConstants.arenaPlayableMargin + 24.0;
      spawnPos.x = spawnPos.x.clamp(margin, GameConstants.arenaWidth - margin);
      spawnPos.y = spawnPos.y.clamp(margin, GameConstants.arenaHeight - margin);

      // Tránh spawn đè sát ngay trên đầu người chơi nếu bị kẹt góc bản đồ
      if (spawnPos.distanceTo(activePlayer.position) < 220.0) {
        final fallbackAngle = angle + math.pi;
        spawnPos.setValues(
          (activePlayer.position.x + math.cos(fallbackAngle) * 360.0).clamp(
            margin,
            GameConstants.arenaWidth - margin,
          ),
          (activePlayer.position.y + math.sin(fallbackAngle) * 360.0).clamp(
            margin,
            GameConstants.arenaHeight - margin,
          ),
        );
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
          position: spawnPos,
          type: enemyType,
          difficultyScale: difficultyScale,
        ),
      );
    }
  }

  /// Hết 5 phút sinh tồn: Xóa toàn bộ quái thường và gọi Boss màn đó xuất hiện
  void _transitionToBossPhase() {
    if (isBossPhase) {
      return;
    }
    isBossPhase = true;
    remainingSurvivalSecondsNotifier.value = 0.0;
    isBossPhaseNotifier.value = true;
    showBossWarningNotifier.value = true;
    _bossIntroDelayTimer = 1.6;
    triggerScreenShake(intensity: 6.0, duration: 0.4);

    // Làm biến mất toàn bộ quái thường đang còn sống trên bản đồ
    for (final enemy in world.children.whereType<EnemyComponent>().toList()) {
      enemy.vanishAndDisappear();
    }
    // Dọn bớt đạn quái cũ
    for (final bullet in world.children.whereType<BulletComponent>().toList()) {
      if (bullet.isEnemyBullet) {
        bullet.removeFromParent();
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
    final center = Vector2(
      GameConstants.arenaWidth / 2,
      GameConstants.arenaHeight / 2,
    );
    // Đặt Boss đối diện cách người chơi một khoảng an toàn để người chơi kịp nhìn thấy áp lực
    Vector2 bossPos = center.clone();
    if (activePlayer != null) {
      final offset = activePlayer.position - center;
      if (offset.length < 240.0) {
        bossPos = Vector2(
          (activePlayer.position.x + 280.0).clamp(
            GameConstants.arenaPlayableMargin + 100.0,
            GameConstants.arenaWidth - GameConstants.arenaPlayableMargin - 100.0,
          ),
          activePlayer.position.y,
        );
      }
    }

    final bossComp = BossComponent(
      position: bossPos,
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

  void onEnemyKilled(Vector2 dropPosition, int points) {
    killCount++;
    killCountNotifier.value = killCount;
    addScore(points);

    // Tỷ lệ rơi vật phẩm hỗ trợ sinh tồn (Cà phê, Mì ly, Khiên, Xu)
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
      world.add(ItemComponent(position: dropPosition, type: dropType));
    }
  }

  void onBossDefeated(Vector2 position) {
    bossHpNotifier.value = 0.0;
    addCoinsAndScore(coins: 150, scoreBonus: 1500);
    // Rơi nhiều xu thưởng quanh vị trí Boss ngã xuống
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi * 2 / 6) * i;
      world.add(
        ItemComponent(
          position:
              position + Vector2(math.cos(angle) * 48, math.sin(angle) * 48),
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
    isGameOver = false;
    isVictory = false;
    isPausedByUi = false;
    isBossPhase = false;
    _bossSpawned = false;
    _bossIntroDelayTimer = 0.0;
    _enemySpawnTimer = 0.8;
    elapsedSurvivalSeconds = 0.0;
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

    world.removeAll(world.children.toList());
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
