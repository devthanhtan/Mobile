import 'dart:async';
import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../game/huit_game.dart';
import '../models/stage_info.dart';
import '../utils/pixel_sprite_cache.dart';
import 'bullet_component.dart';

enum _BossState {
  intro,
  chase,
  radialTelegraph,
  chargeTelegraph,
  charging,
}

enum _BossAnimKey {
  idle,
  attack,
  phase2,
  hit,
  death,
}

/// Boss Thi Cuối Kỳ sử dụng SpriteAnimationComponent với bộ hoạt ảnh đã cache sẵn 1 lần:
/// - idle: 4 frame
/// - attack: 4 frame (báo trước tụ lực rồi tung chiêu)
/// - phase 2: 4 frame (nổi giận, sừng đỏ sáng)
/// - death: 6 frame
/// - hit: 1 frame (nháy trắng)
class BossComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<HuitDeadlineGame> {
  final StageInfo stage;
  final double maxHp;
  double hp;

  SpriteAnimationComponent? _animComponent;
  BossAnimationBundle? _anims;
  _BossAnimKey _currentAnimKey = _BossAnimKey.idle;

  _BossState _state = _BossState.intro;
  double _stateTimer = 0.7;
  double _attackCooldown = 1.6;
  double _hitFlashTimer = 0;
  double _pulseTime = 0;
  int _attackCycleIndex = 0;
  final Vector2 _chargeDir = Vector2(1, 0);
  bool isDead = false;

  // Toàn bộ Paint tái sử dụng
  static final Paint _spritePaintTemplate = Paint()
    ..filterQuality = FilterQuality.none;
  final Paint _auraFillPaint = Paint();
  final Paint _auraStrokePaint = Paint()..style = PaintingStyle.stroke;
  final Paint _radialTelegraphPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0
    ..color = GameConstants.accentColor.withValues(alpha: 0.85);
  final Paint _chargeTelegraphPaint = Paint()
    ..color = GameConstants.hudDangerColor.withValues(alpha: 0.75)
    ..strokeWidth = 10.0
    ..strokeCap = StrokeCap.round;

  final Vector2 _shadowPos = Vector2.zero();
  final Vector2 _shadowSize = Vector2.zero();

  bool get isEnraged => hp <= maxHp * 0.55;
  double get contactDamage => isEnraged ? 30.0 : 24.0;

  BossComponent({
    required super.position,
    required this.stage,
  }) : maxHp = stage.bossMaxHp,
       hp = stage.bossMaxHp,
       super(
         size: Vector2.all(GameConstants.bossSize),
         anchor: Anchor.center,
         priority: 12,
       ) {
    _shadowSize.setValues(size.x * 0.82, 28.0);
    _shadowPos.setValues((size.x - _shadowSize.x) * 0.5, size.y - 24.0);
  }

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    _anims = await game.spriteCache.buildBossAnimations(
      images: game.images,
      baseFlamePath: stage.flameBossPath,
    );

    _animComponent = SpriteAnimationComponent(
      animation: _anims!.idle,
      size: size,
      anchor: Anchor.center,
      position: Vector2(size.x * 0.5, size.y * 0.5),
      paint: Paint()..filterQuality = FilterQuality.none,
    );
    add(_animComponent!);

    add(
      CircleHitbox(
        radius: (size.x * GameConstants.bossHitboxRatio) * 0.5,
        anchor: Anchor.center,
        position: Vector2(size.x * 0.5, size.y * 0.5),
      )..collisionType = CollisionType.passive,
    );

    scale.setValues(0.35, 0.35);
    game.updateBossHud(hp, maxHp);
  }

  void _setAnimKey(_BossAnimKey key) {
    if (_currentAnimKey == key || _animComponent == null || _anims == null) {
      return;
    }
    _currentAnimKey = key;
    switch (key) {
      case _BossAnimKey.idle:
        _animComponent!.animation = _anims!.idle;
        break;
      case _BossAnimKey.attack:
        _animComponent!.animation = _anims!.attack;
        break;
      case _BossAnimKey.phase2:
        _animComponent!.animation = _anims!.phase2;
        break;
      case _BossAnimKey.hit:
        _animComponent!.animation = _anims!.hit;
        break;
      case _BossAnimKey.death:
        _animComponent!.animation = _anims!.death;
        break;
    }
  }

  void takeDamage(double amount) {
    if (isDead || _state == _BossState.intro) {
      return;
    }
    hp = math.max(0.0, hp - amount);
    _hitFlashTimer = 0.08;
    game.updateBossHud(hp, maxHp);

    game.spawnHitParticles(
      x: position.x,
      y: position.y,
      color: GameConstants.pixelWhite,
      count: 4,
      speed: 120.0,
      size: 4.0,
    );
    game.spawnDamageNumber(
      x: position.x,
      y: position.y - 36.0,
      amount: amount.round(),
      color: GameConstants.pixelGold,
    );

    if (hp <= 0) {
      isDead = true;
      _setAnimKey(_BossAnimKey.death);
      game.spawnHitParticles(
        x: position.x,
        y: position.y,
        color: GameConstants.hudDangerColor,
        count: 14,
        speed: 190.0,
        size: 6.0,
        life: 0.38,
      );
      game.onBossDefeated(position.clone());
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (isDead) {
      return;
    }
    if (other is BulletComponent && !other.isEnemyBullet && !other.isConsumed) {
      takeDamage(other.damage);
      other.applyHitFeedbackAndConsumeOrBounce(
        hitX: position.x,
        hitY: position.y,
      );
    }
  }

  @override
  void renderTree(Canvas canvas) {
    final half = size.x * 1.1;
    if (!game.isVisibleInCamera(position.x, position.y, half, half)) {
      return;
    }
    super.renderTree(canvas);
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x * 0.5, size.y * 0.5);
    final auraRadius = size.x * (0.52 + math.sin(_pulseTime * 4.5) * 0.04);
    final auraColor = isEnraged
        ? GameConstants.hudDangerColor
        : stage.themeColor;

    _auraFillPaint.color = auraColor.withValues(alpha: isEnraged ? 0.28 : 0.20);
    canvas.drawCircle(center, auraRadius, _auraFillPaint);

    _auraStrokePaint
      ..strokeWidth = isEnraged ? 4.5 : 3.0
      ..color = auraColor.withValues(alpha: 0.78);
    canvas.drawCircle(center, auraRadius, _auraStrokePaint);

    final shadow = game.sharedShadowSprite;
    if (shadow != null) {
      shadow.render(
        canvas,
        position: _shadowPos,
        size: _shadowSize,
        overridePaint: _spritePaintTemplate,
      );
    }

    if (_state == _BossState.radialTelegraph) {
      final t = (1.0 - (_stateTimer / 0.6)).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        size.x * (0.55 + t * 0.35),
        _radialTelegraphPaint,
      );
    } else if (_state == _BossState.chargeTelegraph) {
      final end = Offset(
        center.dx + _chargeDir.x * 320.0,
        center.dy + _chargeDir.y * 320.0,
      );
      canvas.drawLine(center, end, _chargeTelegraphPaint);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isVictory || isDead) {
      return;
    }

    _pulseTime += dt;

    final isAttackingState =
        _state == _BossState.radialTelegraph ||
        _state == _BossState.chargeTelegraph ||
        _state == _BossState.charging;

    if (_hitFlashTimer > 0) {
      _hitFlashTimer -= dt;
      _setAnimKey(_BossAnimKey.hit);
    } else if (isAttackingState) {
      _setAnimKey(_BossAnimKey.attack);
    } else if (isEnraged) {
      _setAnimKey(_BossAnimKey.phase2);
    } else {
      _setAnimKey(_BossAnimKey.idle);
    }

    final player = game.player;
    if (player == null || !player.isMounted) {
      return;
    }

    final dx = player.position.x - position.x;
    final dy = player.position.y - position.y;
    final distSq = dx * dx + dy * dy;

    switch (_state) {
      case _BossState.intro:
        _stateTimer -= dt;
        final t = (1.0 - (_stateTimer / 0.7)).clamp(0.0, 1.0);
        final eased = Curves.easeOutBack.transform(t);
        final s = 0.35 + 0.65 * eased;
        scale.setValues(s, s);
        if (_stateTimer <= 0) {
          scale.setValues(1.0, 1.0);
          _state = _BossState.chase;
          game.triggerScreenShake(intensity: 10.0, duration: 0.3);
        }
        return;

      case _BossState.chase:
        if (distSq > 16.0) {
          final invDist = 1.0 / math.sqrt(distSq);
          final dirX = dx * invDist;
          final dirY = dy * invDist;
          final chaseSpeed = isEnraged ? 132.0 : 102.0;
          position.x += dirX * chaseSpeed * dt;
          position.y += dirY * chaseSpeed * dt;

          // Hướng trái = lật ngang
          if (_animComponent != null && dirX.abs() > 0.05) {
            final desiredScaleX = dirX < 0 ? -1.0 : 1.0;
            if (_animComponent!.scale.x != desiredScaleX) {
              _animComponent!.scale.x = desiredScaleX;
            }
          }
        }

        _attackCooldown -= dt;
        if (_attackCooldown <= 0) {
          _triggerNextAttack(dx, dy, distSq);
        }
        break;

      case _BossState.radialTelegraph:
        _stateTimer -= dt;
        if (_stateTimer <= 0) {
          _fireRadialBarrage();
          _state = _BossState.chase;
          _attackCooldown = isEnraged ? 1.55 : 2.15;
        }
        break;

      case _BossState.chargeTelegraph:
        _stateTimer -= dt;
        if (_stateTimer <= 0) {
          _state = _BossState.charging;
          _stateTimer = 0.44;
        }
        break;

      case _BossState.charging:
        _stateTimer -= dt;
        final chargeSpeed = isEnraged ? 450.0 : 380.0;
        position.x += _chargeDir.x * chargeSpeed * dt;
        position.y += _chargeDir.y * chargeSpeed * dt;
        if (_stateTimer <= 0) {
          _fireRadialBarrage(bulletCountOverride: 8);
          _state = _BossState.chase;
          _attackCooldown = isEnraged ? 1.45 : 2.0;
        }
        break;
    }

    _clampWithinArena();
  }

  void _triggerNextAttack(double dx, double dy, double distSq) {
    final pattern = _attackCycleIndex % 3;
    _attackCycleIndex++;

    if (pattern == 0) {
      _fireAimedSpread(dx, dy);
      _attackCooldown = isEnraged ? 1.4 : 1.9;
    } else if (pattern == 1) {
      _state = _BossState.radialTelegraph;
      _stateTimer = 0.58;
    } else {
      if (distSq > 0.0001) {
        final invDist = 1.0 / math.sqrt(distSq);
        _chargeDir.setValues(dx * invDist, dy * invDist);
      } else {
        _chargeDir.setValues(1, 0);
      }
      _state = _BossState.chargeTelegraph;
      _stateTimer = 0.62;
    }
  }

  void _fireRadialBarrage({int? bulletCountOverride}) {
    final count = bulletCountOverride ?? (isEnraged ? 16 : 12);
    final step = (math.pi * 2) / count;
    final baseOffset = isEnraged ? 0.15 : 0.0;
    final bulletColor = isEnraged
        ? GameConstants.hudDangerColor
        : stage.themeColor;
    final bulletSpeed = isEnraged ? 280.0 : 235.0;

    for (int i = 0; i < count; i++) {
      final a = step * i + baseOffset;
      game.spawnBullet(
        x: position.x,
        y: position.y,
        dirX: math.cos(a),
        dirY: math.sin(a),
        damage: 16.0,
        speed: bulletSpeed,
        color: bulletColor,
        maxDistance: 720.0,
        isEnemyBullet: true,
        bulletRadius: 10.0,
      );
    }
  }

  void _fireAimedSpread(double dx, double dy) {
    final baseAngle = math.atan2(dy, dx);
    final count = isEnraged ? 5 : 3;
    const spreadStep = 0.24;
    final startAngle = baseAngle - spreadStep * (count - 1) / 2;
    final bulletSpeed = isEnraged ? 340.0 : 290.0;

    for (int i = 0; i < count; i++) {
      final a = startAngle + spreadStep * i;
      game.spawnBullet(
        x: position.x,
        y: position.y,
        dirX: math.cos(a),
        dirY: math.sin(a),
        damage: 18.0,
        speed: bulletSpeed,
        color: GameConstants.accentColor,
        maxDistance: 740.0,
        isEnemyBullet: true,
        bulletRadius: 10.5,
      );
    }
  }

  void _clampWithinArena() {
    final halfSize = size.x * 0.42;
    final minBound = GameConstants.arenaPlayableMargin + halfSize;
    final maxBoundX =
        GameConstants.arenaWidth - GameConstants.arenaPlayableMargin - halfSize;
    final maxBoundY =
        GameConstants.arenaHeight - GameConstants.arenaPlayableMargin - halfSize;
    position.x = position.x.clamp(minBound, maxBoundX);
    position.y = position.y.clamp(minBound, maxBoundY);
  }
}
