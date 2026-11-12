import 'dart:async';
import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../game/huit_game.dart';
import '../models/player_class.dart';
import '../models/weapon_info.dart';
import '../services/audio_settings_service.dart';
import 'boss_component.dart';
import 'bullet_component.dart';
import 'enemy_component.dart';
import 'item_component.dart';

/// Bóng mờ sau lưng khi người chơi kích hoạt Dash
class _DashAfterimageComponent extends PositionComponent {
  final Sprite sprite;
  final bool flipX;
  double _life = 0.22;
  static const double _maxLife = 0.22;

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
    final alpha = (_life / _maxLife).clamp(0.0, 1.0) * 0.45;
    canvas.save();
    if (flipX) {
      canvas.translate(size.x / 2, size.y / 2);
      canvas.scale(-1.0, 1.0);
      canvas.translate(-size.x / 2, -size.y / 2);
    }
    sprite.render(
      canvas,
      size: size,
      overridePaint: Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = ColorFilter.mode(
          GameConstants.dashCyanColor.withValues(alpha: alpha),
          BlendMode.srcATop,
        )
        ..color = Colors.white.withValues(alpha: alpha),
    );
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

/// Nhân vật người chơi điều khiển bằng Joystick + nút Bắn + Dash 8s + Đổi vũ khí
class PlayerComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<HuitDeadlineGame> {
  final PlayerClassInfo classInfo;

  SpriteComponent? _bodySprite;
  SpriteComponent? _heldWeapon;
  Sprite? _playerRawSprite;

  final Vector2 _moveDirection = Vector2.zero();
  Vector2 _facingDirection = Vector2(1, 0);
  Vector2? _aimDirection;
  bool _isShooting = false;

  double _fireTimer = 0;
  double currentHp;
  double maxHp;
  int shieldCount = 0;
  static const int maxShieldCount = 2;

  int activeWeaponIndex = 0;
  WeaponInfo get activeWeapon => classInfo.loadout[activeWeaponIndex];

  // Dash state (8s cooldown)
  double dashCooldownRemaining = 0;
  double _dashTimer = 0;
  double _afterimageTimer = 0;
  Vector2 _dashDirection = Vector2(1, 0);

  // Buff & Invincibility timers
  double _invincibleTimer = 0;
  double _coffeeBuffTimer = 0;
  double _blinkTime = 0;

  PlayerComponent({
    required this.classInfo,
    required super.position,
  }) : maxHp = classInfo.maxHp,
       currentHp = classInfo.maxHp,
       super(
         size: Vector2.all(GameConstants.playerSize),
         anchor: Anchor.center,
         priority: 10,
       );

  bool get isDashing => _dashTimer > 0;
  bool get isInvincible => _invincibleTimer > 0 || isDashing;

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    final playerImage = await game.images.load(classInfo.flameSpritePath);
    _playerRawSprite = Sprite(playerImage);
    _bodySprite = SpriteComponent(
      sprite: _playerRawSprite,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
      paint: Paint()..filterQuality = FilterQuality.none,
    );
    add(_bodySprite!);

    final weaponImage = await game.images.load(activeWeapon.flamePath);
    _heldWeapon = SpriteComponent(
      sprite: Sprite(weaponImage),
      size: Vector2.all(GameConstants.weaponSize),
      anchor: Anchor.center,
      position: Vector2(size.x * 0.85, size.y * 0.56),
      paint: Paint()..filterQuality = FilterQuality.none,
      priority: 11,
    );
    add(_heldWeapon!);

    add(
      CircleHitbox(
        radius: (size.x * GameConstants.hitboxRatio) / 2,
        anchor: Anchor.center,
        position: size / 2,
      )..collisionType = CollisionType.active,
    );

    _syncHud();
  }

  void setMoveDirection(Vector2 direction) {
    if (direction.length2 > 1.0) {
      _moveDirection.setFrom(direction.normalized());
    } else {
      _moveDirection.setFrom(direction);
    }

    if (_moveDirection.length2 > 0.01) {
      _facingDirection = _moveDirection.normalized();
    }
  }

  void setShooting(bool active, {Vector2? aimDirection}) {
    _isShooting = active;
    if (aimDirection != null && aimDirection.length2 > 0.01) {
      _aimDirection = aimDirection.normalized();
      _facingDirection = _aimDirection!;
    } else if (!active) {
      _aimDirection = null;
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

    _dashDirection = _moveDirection.length2 > 0.04
        ? _moveDirection.normalized()
        : (_aimDirection ?? _facingDirection).normalized();
    _dashTimer = GameConstants.dashDurationSeconds;
    dashCooldownRemaining = GameConstants.dashCooldownSeconds;
    _afterimageTimer = 0;
    AudioSettingsService.instance.playDash();
    _syncHud();
    return true;
  }

  /// Đổi giữa vũ khí chính (Slot 1) và vũ khí phụ (Slot 2)
  Future<void> switchWeapon() async {
    final loadout = classInfo.loadout;
    if (loadout.length < 2) {
      return;
    }
    activeWeaponIndex = (activeWeaponIndex + 1) % loadout.length;
    game.activeWeaponIndexNotifier.value = activeWeaponIndex;

    final image = await game.images.load(activeWeapon.flamePath);
    if (_heldWeapon != null) {
      _heldWeapon!.sprite = Sprite(image);
    }
    _fireTimer = math.min(_fireTimer, 0.08);
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
      _syncHud();
      return;
    }

    currentHp = math.max(0.0, currentHp - amount);
    _invincibleTimer = 0.9;
    _syncHud();
    game.triggerScreenShake(intensity: 5.5, duration: 0.16);

    if (currentHp <= 0) {
      game.triggerGameOver();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (isInvincible || game.isGameOver || game.isVictory) {
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
    final center = Offset(size.x / 2, size.y / 2);

    // Bóng dưới chân người chơi
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 3),
        width: size.x * 0.65,
        height: 10,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // Vòng aura tăng tốc Cà phê
    if (_coffeeBuffTimer > 0) {
      canvas.drawCircle(
        center,
        size.x * 0.62,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = Colors.amberAccent.withValues(alpha: 0.75),
      );
    }

    // Vòng khiên bảo vệ xanh dương
    if (shieldCount > 0) {
      canvas.drawCircle(
        center,
        size.x * 0.68,
        Paint()..color = Colors.cyanAccent.withValues(alpha: 0.14),
      );
      canvas.drawCircle(
        center,
        size.x * 0.68,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.cyanAccent.withValues(alpha: 0.8),
      );
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
      game.dashCooldownNotifier.value = dashCooldownRemaining;
    }

    if (_invincibleTimer > 0) {
      _invincibleTimer = math.max(0.0, _invincibleTimer - dt);
      final blinkVisible = ((_blinkTime * 16).floor() % 2 == 0);
      _bodySprite?.opacity = blinkVisible ? 1.0 : 0.35;
    } else {
      _bodySprite?.opacity = 1.0;
    }

    if (_coffeeBuffTimer > 0) {
      _coffeeBuffTimer = math.max(0.0, _coffeeBuffTimer - dt);
    }

    // 1. Di chuyển (ưu tiên Dash nếu đang kích hoạt)
    final coffeeSpeedBoost = _coffeeBuffTimer > 0 ? 1.25 : 1.0;
    if (_dashTimer > 0) {
      _dashTimer -= dt;
      final dashVel =
          _dashDirection *
          classInfo.moveSpeed *
          GameConstants.dashSpeedMultiplier *
          coffeeSpeedBoost;
      position.add(dashVel * dt);

      _afterimageTimer -= dt;
      if (_afterimageTimer <= 0 && _playerRawSprite != null) {
        _afterimageTimer = 0.045;
        game.world.add(
          _DashAfterimageComponent(
            position: position.clone(),
            sprite: _playerRawSprite!,
            flipX: (_bodySprite?.scale.x ?? 1.0) < 0,
          ),
        );
      }
    } else if (_moveDirection.length2 > 0.001) {
      position.add(
        _moveDirection * classInfo.moveSpeed * coffeeSpeedBoost * dt,
      );
    }

    _clampWithinArena();

    // 2. Tự động ngắm vào quái/Boss gần nhất trong tầm bắn (nếu có)
    final autoTargetDir = _findNearestTargetDirection();
    final activeDir = (autoTargetDir ?? _aimDirection ?? _facingDirection)
        .normalized();
    if (_bodySprite != null && activeDir.x.abs() > 0.05) {
      final desiredScaleX = activeDir.x < 0 ? -1.0 : 1.0;
      if (_bodySprite!.scale.x != desiredScaleX) {
        _bodySprite!.scale.x = desiredScaleX;
      }
    }

    if (_heldWeapon != null) {
      final aimAngle = math.atan2(activeDir.y, activeDir.x);
      _heldWeapon!.position.setValues(
        size.x / 2 + activeDir.x * 20.0,
        size.y / 2 + activeDir.y * 20.0,
      );
      _heldWeapon!.angle = aimAngle;
      final desiredWeaponFlipY = activeDir.x < 0 ? -1.0 : 1.0;
      if (_heldWeapon!.scale.y != desiredWeaponFlipY) {
        _heldWeapon!.scale.y = desiredWeaponFlipY;
      }
    }

    // 3. Bắn đạn (tự động nhắm vào quái gần nhất nếu trong tầm)
    if (_fireTimer > 0) {
      _fireTimer -= dt;
    }

    if (_isShooting && _fireTimer <= 0) {
      _fireWeaponBullets(activeDir);
      final rateMult = _coffeeBuffTimer > 0 ? 0.72 : 1.0;
      _fireTimer = activeWeapon.fireCooldown * rateMult;
    }
  }

  /// Tìm hướng tới quái thường hoặc Boss gần nhất trong tầm ngắm
  Vector2? _findNearestTargetDirection() {
    const maxAimRange = GameConstants.bulletMaxDistance + 40.0;
    double bestDistSq = maxAimRange * maxAimRange;
    Vector2? bestTargetPos;

    for (final child in game.world.children) {
      if (child is EnemyComponent &&
          child.isMounted &&
          !child.isDead &&
          !child.isVanishing) {
        final dSq = position.distanceToSquared(child.position);
        if (dSq < bestDistSq) {
          bestDistSq = dSq;
          bestTargetPos = child.position;
        }
      } else if (child is BossComponent && child.isMounted && !child.isDead) {
        final dSq = position.distanceToSquared(child.position);
        if (dSq < bestDistSq) {
          bestDistSq = dSq;
          bestTargetPos = child.position;
        }
      }
    }

    if (bestTargetPos == null) {
      return null;
    }
    final delta = bestTargetPos - position;
    if (delta.length2 <= 0.0001) {
      return _facingDirection.clone();
    }
    return delta.normalized();
  }

  void _fireWeaponBullets(Vector2 shootDir) {
    AudioSettingsService.instance.playShoot();
    final weapon = activeWeapon;
    final count = weapon.bulletCount;
    final baseAngle = math.atan2(shootDir.y, shootDir.x);
    final totalSpread = weapon.spreadAngleRadians;
    final step = count > 1 ? totalSpread / (count - 1) : 0.0;
    final startAngle = baseAngle - totalSpread / 2;

    for (int i = 0; i < count; i++) {
      final angle = count > 1 ? startAngle + step * i : baseAngle;
      final dir = Vector2(math.cos(angle), math.sin(angle));
      // Xuất phát sát tâm nhân vật (4px) để quái áp sát ngay cự ly gần vẫn ăn đủ sát thương
      final spawnPos = position + dir * 4.0;
      game.world.add(
        BulletComponent(
          position: spawnPos,
          direction: dir,
          damage: weapon.damage * classInfo.damageMultiplier,
          speed: weapon.bulletSpeed,
          color: weapon.bulletColor,
          maxDistance: GameConstants.bulletMaxDistance,
          isEnemyBullet: false,
        ),
      );
    }
  }

  void _clampWithinArena() {
    final halfSize = size.x / 2;
    final minBound = GameConstants.arenaPlayableMargin + halfSize;
    final maxBoundX =
        GameConstants.arenaWidth - GameConstants.arenaPlayableMargin - halfSize;
    final maxBoundY =
        GameConstants.arenaHeight - GameConstants.arenaPlayableMargin - halfSize;
    position.x = position.x.clamp(minBound, maxBoundX);
    position.y = position.y.clamp(minBound, maxBoundY);
  }

  void _syncHud() {
    game.playerHpNotifier.value = currentHp;
    game.playerMaxHpNotifier.value = maxHp;
    game.shieldCountNotifier.value = shieldCount;
    game.dashCooldownNotifier.value = dashCooldownRemaining;
    game.activeWeaponIndexNotifier.value = activeWeaponIndex;
  }
}
