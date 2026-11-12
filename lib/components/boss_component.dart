import 'dart:async';
import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../game/huit_game.dart';
import '../models/stage_info.dart';
import 'bullet_component.dart';

enum _BossState {
  intro,
  chase,
  radialTelegraph,
  chargeTelegraph,
  charging,
}

/// Boss khổng lồ xuất hiện sau khi người chơi sống sót 5 phút (kích thước lớn gây áp lực mạnh)
class BossComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<HuitDeadlineGame> {
  final StageInfo stage;
  final double maxHp;
  double hp;

  SpriteComponent? _spriteComponent;
  _BossState _state = _BossState.intro;
  double _stateTimer = 0.7;
  double _attackCooldown = 1.6;
  double _hitFlashTimer = 0;
  double _pulseTime = 0;
  int _attackCycleIndex = 0;
  Vector2 _chargeDir = Vector2(1, 0);
  bool isDead = false;

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
       );

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    final image = await game.images.load(stage.flameBossPath);
    _spriteComponent = SpriteComponent(
      sprite: Sprite(image),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
      paint: Paint()..filterQuality = FilterQuality.none,
    );
    add(_spriteComponent!);

    add(
      CircleHitbox(
        radius: (size.x * GameConstants.bossHitboxRatio) / 2,
        anchor: Anchor.center,
        position: size / 2,
      )..collisionType = CollisionType.active,
    );

    // Bắt đầu từ tỷ lệ nhỏ rồi đập xuống tạo cảm giác áp lực cực lớn
    scale = Vector2.all(0.35);
    game.updateBossHud(hp, maxHp);
  }

  void takeDamage(double amount) {
    if (isDead || _state == _BossState.intro) {
      return;
    }
    hp = math.max(0.0, hp - amount);
    _hitFlashTimer = 0.08;
    game.updateBossHud(hp, maxHp);

    if (hp <= 0) {
      isDead = true;
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
      other.consume();
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final auraRadius = size.x * (0.52 + math.sin(_pulseTime * 4.5) * 0.04);
    final auraColor = isEnraged
        ? const Color(0xFFFF1744)
        : stage.themeColor;

    // Vòng hào quang áp lực lớn dưới chân Boss
    canvas.drawCircle(
      center,
      auraRadius,
      Paint()..color = auraColor.withValues(alpha: isEnraged ? 0.28 : 0.20),
    );
    canvas.drawCircle(
      center,
      auraRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isEnraged ? 4.5 : 3.0
        ..color = auraColor.withValues(alpha: 0.78),
    );

    // Bóng đổ lớn tạo trọng lượng cho Boss
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 10),
        width: size.x * 0.78,
        height: 26,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );

    // Cảnh báo đòn đánh đang tụ lực
    if (_state == _BossState.radialTelegraph) {
      final t = (1.0 - (_stateTimer / 0.6)).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        size.x * (0.55 + t * 0.35),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..color = Colors.orangeAccent.withValues(alpha: 0.85),
      );
    } else if (_state == _BossState.chargeTelegraph) {
      final end = Offset(
        center.dx + _chargeDir.x * 320.0,
        center.dy + _chargeDir.y * 320.0,
      );
      canvas.drawLine(
        center,
        end,
        Paint()
          ..color = Colors.redAccent.withValues(alpha: 0.75)
          ..strokeWidth = 10.0
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isVictory || isDead) {
      return;
    }

    _pulseTime += dt;

    if (_hitFlashTimer > 0) {
      _hitFlashTimer -= dt;
      _spriteComponent?.paint.colorFilter = const ColorFilter.mode(
        Colors.white,
        BlendMode.srcATop,
      );
    } else if (_state == _BossState.chargeTelegraph) {
      _spriteComponent?.paint.colorFilter = ColorFilter.mode(
        Colors.redAccent.withValues(alpha: 0.45),
        BlendMode.srcATop,
      );
    } else {
      _spriteComponent?.paint.colorFilter = null;
    }

    final player = game.player;
    if (player == null || !player.isMounted) {
      return;
    }

    final toPlayer = player.position - position;
    final dist = toPlayer.length;

    switch (_state) {
      case _BossState.intro:
        _stateTimer -= dt;
        final t = (1.0 - (_stateTimer / 0.7)).clamp(0.0, 1.0);
        // Phóng to nhanh tạo cảm giác giáng lâm uy lực
        final eased = Curves.easeOutBack.transform(t);
        scale = Vector2.all(0.35 + 0.65 * eased);
        if (_stateTimer <= 0) {
          scale = Vector2.all(1.0);
          _state = _BossState.chase;
          game.triggerScreenShake(intensity: 10.0, duration: 0.3);
        }
        return;

      case _BossState.chase:
        if (dist > 4.0) {
          final dir = toPlayer / dist;
          final chaseSpeed = isEnraged ? 132.0 : 102.0;
          position.add(dir * chaseSpeed * dt);

          if (_spriteComponent != null && dir.x.abs() > 0.05) {
            final desiredScaleX = dir.x < 0 ? -1.0 : 1.0;
            if (_spriteComponent!.scale.x != desiredScaleX) {
              _spriteComponent!.scale.x = desiredScaleX;
            }
          }
        }

        _attackCooldown -= dt;
        if (_attackCooldown <= 0) {
          _triggerNextAttack(toPlayer);
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
        position.add(_chargeDir * chargeSpeed * dt);
        if (_stateTimer <= 0) {
          _fireRadialBarrage(bulletCountOverride: 8);
          _state = _BossState.chase;
          _attackCooldown = isEnraged ? 1.45 : 2.0;
        }
        break;
    }

    _clampWithinArena();
  }

  void _triggerNextAttack(Vector2 toPlayer) {
    final pattern = _attackCycleIndex % 3;
    _attackCycleIndex++;

    if (pattern == 0) {
      // Bắn chùm hướng vào người chơi
      _fireAimedSpread(toPlayer);
      _attackCooldown = isEnraged ? 1.4 : 1.9;
    } else if (pattern == 1) {
      // Tụ lực nổ vòng tròn 360 độ
      _state = _BossState.radialTelegraph;
      _stateTimer = 0.58;
    } else {
      // Tụ lực húc thẳng áp sát (khuyến khích người chơi bấm nút Dash!)
      _chargeDir = toPlayer.length2 > 0
          ? toPlayer.normalized()
          : Vector2(1, 0);
      _state = _BossState.chargeTelegraph;
      _stateTimer = 0.62;
    }
  }

  void _fireRadialBarrage({int? bulletCountOverride}) {
    final count = bulletCountOverride ?? (isEnraged ? 16 : 12);
    final step = (math.pi * 2) / count;
    final baseOffset = isEnraged ? 0.15 : 0.0;
    for (int i = 0; i < count; i++) {
      final angle = step * i + baseOffset;
      final dir = Vector2(math.cos(angle), math.sin(angle));
      game.world.add(
        BulletComponent(
          position: position.clone(),
          direction: dir,
          damage: 16.0,
          speed: isEnraged ? 280.0 : 235.0,
          color: isEnraged ? const Color(0xFFFF1744) : stage.themeColor,
          maxDistance: 720.0,
          isEnemyBullet: true,
          bulletRadius: 10.0,
        ),
      );
    }
  }

  void _fireAimedSpread(Vector2 toPlayer) {
    final baseAngle = math.atan2(toPlayer.y, toPlayer.x);
    final count = isEnraged ? 5 : 3;
    const spreadStep = 0.24;
    final startAngle = baseAngle - spreadStep * (count - 1) / 2;

    for (int i = 0; i < count; i++) {
      final a = startAngle + spreadStep * i;
      final dir = Vector2(math.cos(a), math.sin(a));
      game.world.add(
        BulletComponent(
          position: position.clone(),
          direction: dir,
          damage: 18.0,
          speed: isEnraged ? 340.0 : 290.0,
          color: Colors.deepOrangeAccent,
          maxDistance: 740.0,
          isEnemyBullet: true,
          bulletRadius: 10.5,
        ),
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

