import 'dart:async';
import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../game/huit_game.dart';
import 'bullet_component.dart';

/// Phân loại quái thường trong giai đoạn sinh tồn 5 phút
enum NormalEnemyType {
  deadline, // Tốc độ & máu cân bằng
  email, // Nhanh, từ giữa trận có thể bắn đạn đỏ
  quiz, // Máu trâu, kích thước nhỉnh hơn
}

/// Quái thường săn đuổi người chơi trong 5 phút sinh tồn
class EnemyComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<HuitDeadlineGame> {
  final NormalEnemyType type;
  final double maxHp;
  double hp;
  final double speed;
  final double contactDamage;
  final int scoreValue;

  SpriteComponent? _spriteComponent;
  double _hitFlashTimer = 0;
  double _rangedTimer = 2.6;
  bool isDead = false;
  bool isVanishing = false;
  double _vanishTimer = 0;
  static const double _vanishDuration = 0.45;

  EnemyComponent({
    required super.position,
    required this.type,
    double difficultyScale = 1.0,
  }) : maxHp = _baseHp(type) * difficultyScale,
       hp = _baseHp(type) * difficultyScale,
       speed = _baseSpeed(type) * (1.0 + (difficultyScale - 1.0) * 0.25),
       contactDamage = _baseDamage(type),
       scoreValue = _baseScore(type),
       super(
         size: Vector2.all(
           type == NormalEnemyType.quiz
               ? GameConstants.enemySize + 6
               : GameConstants.enemySize,
         ),
         anchor: Anchor.center,
         priority: 9,
       );

  static double _baseHp(NormalEnemyType type) {
    switch (type) {
      case NormalEnemyType.deadline:
        return 52.0;
      case NormalEnemyType.email:
        return 36.0;
      case NormalEnemyType.quiz:
        return 95.0;
    }
  }

  static double _baseSpeed(NormalEnemyType type) {
    switch (type) {
      case NormalEnemyType.deadline:
        return 96.0;
      case NormalEnemyType.email:
        return 128.0;
      case NormalEnemyType.quiz:
        return 76.0;
    }
  }

  static double _baseDamage(NormalEnemyType type) {
    switch (type) {
      case NormalEnemyType.deadline:
        return 14.0;
      case NormalEnemyType.email:
        return 12.0;
      case NormalEnemyType.quiz:
        return 20.0;
    }
  }

  static int _baseScore(NormalEnemyType type) {
    switch (type) {
      case NormalEnemyType.deadline:
        return 20;
      case NormalEnemyType.email:
        return 25;
      case NormalEnemyType.quiz:
        return 35;
    }
  }

  String get _flamePath {
    switch (type) {
      case NormalEnemyType.deadline:
        return GameConstants.enemyDeadlinePath;
      case NormalEnemyType.email:
        return GameConstants.enemyEmailPath;
      case NormalEnemyType.quiz:
        return GameConstants.enemyQuizPath;
    }
  }

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    final image = await game.images.load(_flamePath);
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
        radius: (size.x * GameConstants.hitboxRatio) / 2,
        anchor: Anchor.center,
        position: size / 2,
      )..collisionType = CollisionType.active,
    );
  }

  /// Hiệu ứng biến mất khi hết 5 phút và Boss chuẩn bị xuất hiện
  void vanishAndDisappear() {
    if (isDead || isVanishing) {
      return;
    }
    isVanishing = true;
    _vanishTimer = 0;
  }

  void takeDamage(double amount, Vector2 knockbackDir) {
    if (isDead || isVanishing) {
      return;
    }
    hp -= amount;
    _hitFlashTimer = 0.1;
    if (knockbackDir.length2 > 0) {
      position.add(knockbackDir.normalized() * 7.0);
    }

    if (hp <= 0) {
      isDead = true;
      game.onEnemyKilled(position.clone(), scoreValue);
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (isDead || isVanishing) {
      return;
    }
    if (other is BulletComponent && !other.isEnemyBullet && !other.isConsumed) {
      takeDamage(other.damage, other.direction);
      other.consume();
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    if (isVanishing) {
      final t = (_vanishTimer / _vanishDuration).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        (size.x * 0.55) * (1.0 + t * 0.7),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.cyanAccent.withValues(alpha: 1.0 - t),
      );
      return;
    }

    // Bóng chân dưới quái
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 4),
        width: size.x * 0.65,
        height: 10,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
  }

  @override
  void renderTree(Canvas canvas) {
    super.renderTree(canvas);
    // Thanh máu nhỏ phía trên khi quái bị thương
    if (!isVanishing && !isDead && hp < maxHp) {
      final ratio = (hp / maxHp).clamp(0.0, 1.0);
      final barW = size.x * 0.78;
      final left = (size.x - barW) / 2;
      canvas.drawRect(
        Rect.fromLTWH(left, -7, barW, 4),
        Paint()..color = Colors.black.withValues(alpha: 0.65),
      );
      canvas.drawRect(
        Rect.fromLTWH(left, -7, barW * ratio, 4),
        Paint()..color = Colors.redAccent,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isVictory || isDead) {
      return;
    }

    if (isVanishing) {
      _vanishTimer += dt;
      final t = (_vanishTimer / _vanishDuration).clamp(0.0, 1.0);
      scale = Vector2.all(math.max(0.05, 1.0 - t));
      angle += dt * 10.0;
      if (_spriteComponent != null) {
        _spriteComponent!.opacity = (1.0 - t).clamp(0.0, 1.0);
      }
      if (_vanishTimer >= _vanishDuration) {
        removeFromParent();
      }
      return;
    }

    if (_hitFlashTimer > 0) {
      _hitFlashTimer -= dt;
      _spriteComponent?.paint.colorFilter = const ColorFilter.mode(
        Colors.white,
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
    if (dist > 14.0) {
      final dir = toPlayer / dist;
      position.add(dir * speed * dt);

      if (_spriteComponent != null && dir.x.abs() > 0.05) {
        final desiredScaleX = dir.x < 0 ? -1.0 : 1.0;
        if (_spriteComponent!.scale.x != desiredScaleX) {
          _spriteComponent!.scale.x = desiredScaleX;
        }
      }
    }

    // Quái Email bắn đạn đơn định hướng & Quái Quiz bắn chùm 3 viên
    if (type == NormalEnemyType.email) {
      _rangedTimer -= dt;
      if (_rangedTimer <= 0 && dist < 480.0) {
        _rangedTimer = 2.4;
        game.world.add(
          BulletComponent(
            position: position.clone(),
            direction: toPlayer,
            damage: 12.0,
            speed: GameConstants.enemyBulletSpeed,
            color: Colors.redAccent,
            maxDistance: 500.0,
            isEnemyBullet: true,
            bulletRadius: 7.0,
          ),
        );
      }
    } else if (type == NormalEnemyType.quiz) {
      _rangedTimer -= dt;
      if (_rangedTimer <= 0 && dist < 420.0) {
        _rangedTimer = 3.3;
        final baseAngle = math.atan2(toPlayer.y, toPlayer.x);
        const spread = 0.24;
        for (int i = -1; i <= 1; i++) {
          final angle = baseAngle + i * spread;
          game.world.add(
            BulletComponent(
              position: position.clone(),
              direction: Vector2(math.cos(angle), math.sin(angle)),
              damage: 10.0,
              speed: GameConstants.enemyBulletSpeed * 0.9,
              color: Colors.orangeAccent,
              maxDistance: 440.0,
              isEnemyBullet: true,
              bulletRadius: 6.5,
            ),
          );
        }
      }
    }
  }
}

