import 'dart:async';
import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../game/huit_game.dart';
import '../models/player_class.dart';
import '../models/weapon_config.dart';
import '../services/audio_settings_service.dart';
import '../utils/pixel_sprite_cache.dart';
import 'boss_component.dart';
import 'bullet_component.dart';
import 'enemy_component.dart';
import 'item_component.dart';

/// Bóng mờ sau lưng khi người chơi kích hoạt Dash:
/// Dùng sprite phủ xanh cyan dựng sẵn + 1 Paint tái sử dụng.
class _DashAfterimageComponent extends PositionComponent {
  final Sprite sprite;
  final bool flipX;
  double _life = 0.22;
  static const double _maxLife = 0.22;

  final Paint _ghostPaint = Paint()..filterQuality = FilterQuality.none;

  _DashAfterimageComponent({
    required super.position,
    required this.sprite,
    required this.flipX,
  }) : super(
         size: Vector2.all(GameConstants.playerSize),
         anchor: Anchor.center,
         priority: 8,
       );

  @override
  void render(Canvas canvas) {
    final alpha = ((_life / _maxLife).clamp(0.0, 1.0) * 0.45 * 255).round();
    _ghostPaint.color = Color.fromARGB(alpha, 255, 255, 255);
    canvas.save();
    if (flipX) {
      canvas.translate(size.x * 0.5, size.y * 0.5);
      canvas.scale(-1.0, 1.0);
      canvas.translate(-size.x * 0.5, -size.y * 0.5);
    }
    sprite.render(canvas, size: size, overridePaint: _ghostPaint);
    canvas.restore();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _life -= dt;
    if (_life <= 0) {
      removeFromParent();
    }
  }
}

enum _PlayerAnimState {
  idle,
  walk,
  hit,
  death,
}

/// Nhân vật người chơi sử dụng SpriteAnimationComponent đã cache (idle 4f, walk 4f, hit 1f, death 4f)
/// và hệ thống 5 vũ khí Strategy riêng (Bút bi, Laptop laser 0.4s, USB nảy tường, Trà sữa hồi máu, Giáo trình cận chiến).
class PlayerComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<HuitDeadlineGame> {
  final PlayerClassInfo classInfo;

  SpriteAnimationComponent? _bodyAnim;
  ActorAnimationBundle? _anims;
  _PlayerAnimState _currentAnimState = _PlayerAnimState.idle;
  SpriteComponent? _heldWeapon;
  Sprite? _playerRawSprite;
  final List<Sprite> _weaponSprites = [];

  final Vector2 _moveDirection = Vector2.zero();
  final Vector2 _facingDirection = Vector2(1, 0);
  final Vector2 _aimDirection = Vector2.zero();
  bool _hasManualAim = false;
  bool _isShooting = false;

  // Vector tạm tái sử dụng cho auto-aim & di chuyển (0 allocation mỗi frame)
  final Vector2 _activeDir = Vector2(1, 0);
  final Vector2 _dashDirection = Vector2(1, 0);

  // Bộ đệm mục tiêu auto-aim làm mới mỗi 0.15s
  double _autoAimTimer = 0.0;
  EnemyComponent? _cachedEnemyTarget;
  BossComponent? _cachedBossTarget;

  double _fireTimer = 0;
  double weaponChargeTimer = 0.0; // Dùng cho Laptop giữ nạp 0.4s
  double currentHp;
  double maxHp;
  int shieldCount = 0;
  static const int maxShieldCount = 2;

  int activeWeaponIndex = 0;
  WeaponConfig get activeWeapon => classInfo.weaponConfigs[activeWeaponIndex];

  // Dash state (8s cooldown)
  double dashCooldownRemaining = 0;
  double _lastPublishedDashCooldown = -1.0;
  double _dashTimer = 0;
  double _afterimageTimer = 0;

  // Buff & Invincibility & Hit animation timers
  double _invincibleTimer = 0;
  double _hitAnimTimer = 0;
  double _coffeeBuffTimer = 0;
  double _blinkTime = 0;

  // Paint & tọa độ bóng chân tái sử dụng
  static final Paint _spritePaintTemplate = Paint()
    ..filterQuality = FilterQuality.none;
  static final Paint _coffeeAuraPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..color = GameConstants.hudGoldColor.withValues(alpha: 0.78);
  static final Paint _shieldFillPaint = Paint()
    ..color = GameConstants.pixelCyan.withValues(alpha: 0.15);
  static final Paint _shieldStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..color = GameConstants.pixelCyan.withValues(alpha: 0.82);

  final Vector2 _shadowPos = Vector2.zero();
  final Vector2 _shadowSize = Vector2.zero();

  PlayerComponent({
    required this.classInfo,
    required super.position,
  }) : maxHp = classInfo.maxHp,
       currentHp = classInfo.maxHp,
       super(
         size: Vector2.all(GameConstants.playerSize),
         anchor: Anchor.center,
         priority: 10,
       ) {
    _shadowSize.setValues(size.x * 0.72, 12.0);
    _shadowPos.setValues((size.x - _shadowSize.x) * 0.5, size.y - 9.0);
  }

  bool get isDashing => _dashTimer > 0;
  bool get isInvincible => _invincibleTimer > 0 || isDashing;

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    final playerImage = await game.images.load(classInfo.flameSpritePath);
    _playerRawSprite = Sprite(playerImage);
    _anims = await game.spriteCache.buildPlayerAnimations(
      images: game.images,
      baseFlamePath: classInfo.flameSpritePath,
    );

    _bodyAnim = SpriteAnimationComponent(
      animation: _anims!.idle,
      size: size,
      anchor: Anchor.center,
      position: Vector2(size.x * 0.5, size.y * 0.5),
      paint: Paint()..filterQuality = FilterQuality.none,
    );
    add(_bodyAnim!);

    // Nạp sẵn sprite toàn bộ vũ khí trong loadout để đổi vũ khí tức thời
    _weaponSprites.clear();
    for (final weapon in classInfo.weaponConfigs) {
      try {
        final wImg = await game.images.load(weapon.flamePath);
        _weaponSprites.add(Sprite(wImg));
      } catch (_) {
        game.images.clear(weapon.flamePath);
        final fallbackImg = await game.images.load(
          GameConstants.weaponPenPath,
        );
        _weaponSprites.add(Sprite(fallbackImg));
      }
    }

    _heldWeapon = SpriteComponent(
      sprite: _weaponSprites.isNotEmpty ? _weaponSprites.first : null,
      size: Vector2.all(GameConstants.weaponSize),
      anchor: Anchor.center,
      position: Vector2(size.x * 0.85, size.y * 0.56),
      paint: Paint()..filterQuality = FilterQuality.none,
      priority: 11,
    );
    add(_heldWeapon!);

    add(
      CircleHitbox(
        radius: (size.x * GameConstants.hitboxRatio) * 0.5,
        anchor: Anchor.center,
        position: Vector2(size.x * 0.5, size.y * 0.5),
      )..collisionType = CollisionType.active,
    );

    _syncHud();
  }

  void _setAnimState(_PlayerAnimState next) {
    if (_currentAnimState == next || _bodyAnim == null || _anims == null) {
      return;
    }
    _currentAnimState = next;
    switch (next) {
      case _PlayerAnimState.idle:
        _bodyAnim!.animation = _anims!.idle;
        break;
      case _PlayerAnimState.walk:
        _bodyAnim!.animation = _anims!.walk;
        break;
      case _PlayerAnimState.hit:
        _bodyAnim!.animation = _anims!.hit;
        break;
      case _PlayerAnimState.death:
        _bodyAnim!.animation = _anims!.death;
        break;
    }
  }

  void setMoveDirection(Vector2 direction) {
    _moveDirection.setFrom(direction);
    final lenSq = _moveDirection.length2;
    if (lenSq > 1.0) {
      _moveDirection.normalize();
    }
    if (lenSq > 0.01) {
      _facingDirection.setFrom(_moveDirection);
      _facingDirection.normalize();
    }
  }

  void setShooting(bool active, {Vector2? aimDirection}) {
    final justStarted = active && !_isShooting;
    _isShooting = active;
    if (!active) {
      weaponChargeTimer = 0.0;
    }
    if (justStarted) {
      _autoAimTimer = 0.0;
    }
    if (aimDirection != null && aimDirection.length2 > 0.01) {
      _aimDirection.setFrom(aimDirection);
      _aimDirection.normalize();
      _hasManualAim = true;
      _facingDirection.setFrom(_aimDirection);
    } else if (!active) {
      _hasManualAim = false;
    }
  }

  /// Kích hoạt kỹ năng Dash (lướt nhanh + miễn nhiễm sát thương thoáng qua, hồi chiêu 8s)
  bool triggerDash() {
    if (!isMounted ||
        game.isGameOver ||
        game.isVictory ||
        dashCooldownRemaining > 0 ||
        _dashTimer > 0) {
      return false;
    }

    if (_moveDirection.length2 > 0.04) {
      _dashDirection.setFrom(_moveDirection);
    } else if (_hasManualAim) {
      _dashDirection.setFrom(_aimDirection);
    } else {
      _dashDirection.setFrom(_facingDirection);
    }
    if (_dashDirection.length2 > 0.0001) {
      _dashDirection.normalize();
    } else {
      _dashDirection.setValues(1, 0);
    }

    _dashTimer = GameConstants.dashDurationSeconds;
    dashCooldownRemaining = GameConstants.dashCooldownSeconds;
    _afterimageTimer = 0;
    AudioSettingsService.instance.playDash();
    _publishDashCooldown(force: true);
    return true;
  }

  /// Đổi giữa vũ khí chính (Slot 1) và vũ khí phụ (Slot 2)
  Future<void> switchWeapon() async {
    final loadout = classInfo.weaponConfigs;
    if (loadout.length < 2) {
      return;
    }
    activeWeaponIndex = (activeWeaponIndex + 1) % loadout.length;
    weaponChargeTimer = 0.0;
    game.activeWeaponIndexNotifier.value = activeWeaponIndex;

    if (_heldWeapon != null) {
      if (activeWeaponIndex < _weaponSprites.length) {
        _heldWeapon!.sprite = _weaponSprites[activeWeaponIndex];
      } else {
        final image = await game.images.load(activeWeapon.flamePath);
        _heldWeapon!.sprite = Sprite(image);
      }
    }
    _fireTimer = math.min(_fireTimer, 0.08);
  }

  /// Hồi máu cho người chơi (dùng khi nhặt Mì gói hoặc bắn trúng bằng Trà sữa)
  void heal(double amount) {
    if (amount <= 0 || game.isGameOver || currentHp >= maxHp) {
      return;
    }
    currentHp = math.min(maxHp, currentHp + amount);
    game.playerHpNotifier.value = currentHp;
  }

  void collectItem(DropItemType type) {
    switch (type) {
      case DropItemType.noodle:
        currentHp = math.min(maxHp, currentHp + 24.0);
        break;
      case DropItemType.coffee:
        _coffeeBuffTimer = 6.0;
        break;
      case DropItemType.shield:
        shieldCount = math.min(maxShieldCount, shieldCount + 1);
        break;
      case DropItemType.coin:
        game.addCoinsAndScore(coins: 10, scoreBonus: 50);
        break;
    }
    _syncHud();
  }

  void takeDamage(double amount) {
    if (isInvincible || game.isGameOver || game.isVictory) {
      return;
    }

    if (shieldCount > 0) {
      shieldCount--;
      _invincibleTimer = 0.75;
      _hitAnimTimer = 0.10;
      _setAnimState(_PlayerAnimState.hit);
      _syncHud();
      return;
    }

    currentHp = math.max(0.0, currentHp - amount);
    _invincibleTimer = 0.9;
    _hitAnimTimer = 0.12;
    _setAnimState(currentHp <= 0 ? _PlayerAnimState.death : _PlayerAnimState.hit);
    _syncHud();
    game.triggerScreenShake(intensity: 5.5, duration: 0.16);

    if (currentHp <= 0) {
      game.triggerGameOver();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (game.isGameOver || game.isVictory) {
      return;
    }

    if (other is ItemComponent && !other.isCollected) {
      collectItem(other.type);
      other.markCollected();
      return;
    }

    if (isInvincible) {
      return;
    }

    if (other is EnemyComponent && !other.isDead && !other.isVanishing) {
      takeDamage(other.contactDamage);
    } else if (other is BossComponent && !other.isDead) {
      takeDamage(other.contactDamage);
    } else if (other is BulletComponent &&
        other.isEnemyBullet &&
        !other.isConsumed) {
      takeDamage(other.damage);
      other.consume();
    }
  }

  @override
  void render(Canvas canvas) {
    final half = size.x * 0.5;
    final center = Offset(half, half);

    final shadow = game.sharedShadowSprite;
    if (shadow != null) {
      shadow.render(
        canvas,
        position: _shadowPos,
        size: _shadowSize,
        overridePaint: _spritePaintTemplate,
      );
    }

    if (_coffeeBuffTimer > 0) {
      canvas.drawCircle(center, size.x * 0.62, _coffeeAuraPaint);
    }

    if (shieldCount > 0) {
      canvas.drawCircle(center, size.x * 0.68, _shieldFillPaint);
      canvas.drawCircle(center, size.x * 0.68, _shieldStrokePaint);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isVictory) {
      return;
    }

    _blinkTime += dt;

    if (dashCooldownRemaining > 0) {
      dashCooldownRemaining = math.max(0.0, dashCooldownRemaining - dt);
      _publishDashCooldown();
    }

    if (_hitAnimTimer > 0) {
      _hitAnimTimer = math.max(0.0, _hitAnimTimer - dt);
    }

    if (_invincibleTimer > 0) {
      _invincibleTimer = math.max(0.0, _invincibleTimer - dt);
      final blinkVisible = ((_blinkTime * 16).floor() % 2 == 0);
      _bodyAnim?.opacity = blinkVisible ? 1.0 : 0.35;
    } else if (_bodyAnim != null && _bodyAnim!.opacity != 1.0) {
      _bodyAnim!.opacity = 1.0;
    }

    if (_coffeeBuffTimer > 0) {
      _coffeeBuffTimer = math.max(0.0, _coffeeBuffTimer - dt);
    }

    // 1. Di chuyển tại chỗ & cập nhật hoạt ảnh idle/walk/hit
    final coffeeSpeedBoost = _coffeeBuffTimer > 0 ? 1.25 : 1.0;
    final isMoving = _dashTimer > 0 || _moveDirection.length2 > 0.001;
    if (_hitAnimTimer <= 0) {
      _setAnimState(isMoving ? _PlayerAnimState.walk : _PlayerAnimState.idle);
    }

    if (_dashTimer > 0) {
      _dashTimer -= dt;
      final dashStep =
          classInfo.moveSpeed *
          GameConstants.dashSpeedMultiplier *
          coffeeSpeedBoost *
          dt;
      position.x += _dashDirection.x * dashStep;
      position.y += _dashDirection.y * dashStep;

      _afterimageTimer -= dt;
      final ghostSprite = game.playerDashGhostSprite ?? _playerRawSprite;
      if (_afterimageTimer <= 0 && ghostSprite != null) {
        _afterimageTimer = 0.045;
        game.world.add(
          _DashAfterimageComponent(
            position: position.clone(),
            sprite: ghostSprite,
            flipX: (_bodyAnim?.scale.x ?? 1.0) < 0,
          ),
        );
      }
    } else if (_moveDirection.length2 > 0.001) {
      final moveStep = classInfo.moveSpeed * coffeeSpeedBoost * dt;
      position.x += _moveDirection.x * moveStep;
      position.y += _moveDirection.y * moveStep;
    }

    _clampWithinArena();

    // 2. Auto-aim làm mới mỗi 0.15s trên danh sách game.enemies đã cache
    _updateActiveAimDirection(dt);

    // Hướng trái = lật ngang (scale.x = -1.0)
    if (_bodyAnim != null && _activeDir.x.abs() > 0.05) {
      final desiredScaleX = _activeDir.x < 0 ? -1.0 : 1.0;
      if (_bodyAnim!.scale.x != desiredScaleX) {
        _bodyAnim!.scale.x = desiredScaleX;
      }
    }

    if (_heldWeapon != null) {
      final aimAngle = math.atan2(_activeDir.y, _activeDir.x);
      _heldWeapon!.position.setValues(
        size.x * 0.5 + _activeDir.x * 20.0,
        size.y * 0.5 + _activeDir.y * 20.0,
      );
      _heldWeapon!.angle = aimAngle;
      final desiredWeaponFlipY = _activeDir.x < 0 ? -1.0 : 1.0;
      if (_heldWeapon!.scale.y != desiredWeaponFlipY) {
        _heldWeapon!.scale.y = desiredWeaponFlipY;
      }
    }

    // 3. Khai hỏa theo Strategy của vũ khí đang cầm (Bút bi / Laptop / USB / Trà sữa / Giáo trình)
    if (_fireTimer > 0) {
      _fireTimer -= dt;
    }

    final weapon = activeWeapon;
    final fired = weapon.strategy.updateAndTryFire(
      player: this,
      game: game,
      config: weapon,
      aimDir: _activeDir,
      isShooting: _isShooting,
      canFireNow: _fireTimer <= 0,
      dt: dt,
    );
    if (fired) {
      final rateMult = _coffeeBuffTimer > 0 ? 0.72 : 1.0;
      _fireTimer = weapon.fireCooldown * rateMult;
    }
  }

  /// Làm mới mục tiêu gần nhất mỗi 0.15s bằng khoảng cách bình phương
  void _updateActiveAimDirection(double dt) {
    const maxAimRange = GameConstants.bulletMaxDistance + 40.0;
    const maxAimRangeSq = maxAimRange * maxAimRange;

    final enemyInvalid =
        _cachedEnemyTarget != null &&
        (_cachedEnemyTarget!.isDead ||
            _cachedEnemyTarget!.isVanishing ||
            !_cachedEnemyTarget!.isMounted);
    final bossInvalid =
        _cachedBossTarget != null &&
        (_cachedBossTarget!.isDead || !_cachedBossTarget!.isMounted);
    if (enemyInvalid) {
      _cachedEnemyTarget = null;
    }
    if (bossInvalid) {
      _cachedBossTarget = null;
    }

    _autoAimTimer -= dt;
    if (_autoAimTimer <= 0.0 ||
        (_cachedEnemyTarget == null && _cachedBossTarget == null && _isShooting)) {
      _autoAimTimer = GameConstants.autoAimRefreshInterval;
      _selectNearestCachedTarget(maxAimRangeSq);
    }

    double? targetX;
    double? targetY;
    final lockedEnemy = _cachedEnemyTarget;
    final lockedBoss = _cachedBossTarget;
    if (lockedEnemy != null) {
      final dx = lockedEnemy.position.x - position.x;
      final dy = lockedEnemy.position.y - position.y;
      if (dx * dx + dy * dy <= maxAimRangeSq) {
        targetX = lockedEnemy.position.x;
        targetY = lockedEnemy.position.y;
      } else {
        _cachedEnemyTarget = null;
      }
    } else if (lockedBoss != null) {
      final dx = lockedBoss.position.x - position.x;
      final dy = lockedBoss.position.y - position.y;
      if (dx * dx + dy * dy <= maxAimRangeSq) {
        targetX = lockedBoss.position.x;
        targetY = lockedBoss.position.y;
      } else {
        _cachedBossTarget = null;
      }
    }

    if (targetX != null && targetY != null) {
      _activeDir.setValues(targetX - position.x, targetY - position.y);
      if (_activeDir.length2 > 0.0001) {
        _activeDir.normalize();
        return;
      }
    }

    if (_hasManualAim) {
      _activeDir.setFrom(_aimDirection);
    } else {
      _activeDir.setFrom(_facingDirection);
    }
    if (_activeDir.length2 > 0.0001) {
      _activeDir.normalize();
    } else {
      _activeDir.setValues(1, 0);
    }
  }

  void _selectNearestCachedTarget(double maxAimRangeSq) {
    double bestDistSq = maxAimRangeSq;
    EnemyComponent? bestEnemy;
    BossComponent? bestBoss;

    final px = position.x;
    final py = position.y;
    final enemies = game.enemies;
    for (int i = 0; i < enemies.length; i++) {
      final enemy = enemies[i];
      if (!enemy.isMounted || enemy.isDead || enemy.isVanishing) {
        continue;
      }
      final dx = enemy.position.x - px;
      final dy = enemy.position.y - py;
      final dSq = dx * dx + dy * dy;
      if (dSq < bestDistSq) {
        bestDistSq = dSq;
        bestEnemy = enemy;
      }
    }

    final boss = game.boss;
    if (boss != null && boss.isMounted && !boss.isDead) {
      final dx = boss.position.x - px;
      final dy = boss.position.y - py;
      final dSq = dx * dx + dy * dy;
      if (dSq < bestDistSq) {
        bestEnemy = null;
        bestBoss = boss;
      }
    }

    _cachedEnemyTarget = bestEnemy;
    _cachedBossTarget = bestBoss;
  }

  void _clampWithinArena() {
    final halfSize = size.x * 0.5;
    final minBound = GameConstants.arenaPlayableMargin + halfSize;
    final maxBoundX =
        GameConstants.arenaWidth - GameConstants.arenaPlayableMargin - halfSize;
    final maxBoundY =
        GameConstants.arenaHeight - GameConstants.arenaPlayableMargin - halfSize;
    position.x = position.x.clamp(minBound, maxBoundX);
    position.y = position.y.clamp(minBound, maxBoundY);
  }

  void _publishDashCooldown({bool force = false}) {
    final double quantized = dashCooldownRemaining <= 0.001
        ? 0.0
        : ((dashCooldownRemaining * 10.0).ceil() / 10.0);
    if (force || quantized != _lastPublishedDashCooldown) {
      _lastPublishedDashCooldown = quantized;
      game.dashCooldownNotifier.value = quantized;
    }
  }

  void _syncHud() {
    game.playerHpNotifier.value = currentHp;
    game.playerMaxHpNotifier.value = maxHp;
    game.shieldCountNotifier.value = shieldCount;
    _publishDashCooldown(force: true);
    game.activeWeaponIndexNotifier.value = activeWeaponIndex;
  }
}
