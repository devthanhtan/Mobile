import 'dart:async';
import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../game/huit_game.dart';
import '../utils/pixel_sprite_cache.dart';
import 'bullet_component.dart';

enum _EnemyAnimState {
  move,
  hit,
  death,
}

/// Quái thường sử dụng SpriteAnimationComponent với bộ hoạt ảnh đã cache sẵn 1 lần:
/// - Deadline: chuông báo thức rung lắc đuổi theo.
/// - Email: phong bì vẫy cánh + huy hiệu đỏ bắn tầm xa.
/// - Quiz: tờ đề tím lao nhanh + dấu ! nhấp nháy bắn chùm.
/// Mỗi con có: move 4 frame, hit 1 frame (nháy trắng), death 4 frame.
class EnemyComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<HuitDeadlineGame> {
  static int _nextEnemyId = 0;

  final int _enemyId = _nextEnemyId++;
  final NormalEnemyType type;
  final double maxHp;
  double hp;
  final double speed;
  final double contactDamage;
  final int scoreValue;

  SpriteAnimationComponent? _animComponent;
  ActorAnimationBundle? _anims;
  _EnemyAnimState _animState = _EnemyAnimState.move;
  CircleHitbox? _hitbox;

  double _hitFlashTimer = 0;
  double _deathAnimTimer = 0;
  static const double _deathAnimDuration = 0.24;
  double _rangedTimer = 2.6;
  bool isDead = false;
  bool isVanishing = false;
  double _vanishTimer = 0;
  static const double _vanishDuration = 0.45;

  // Bộ đệm AI giảm tải cho quái ở xa
  int _aiFrameCounter = 0;
  double _cachedDirX = 0;
  double _cachedDirY = 0;

  // Toàn bộ Paint static cache
  static final Paint _spritePaintTemplate = Paint()
    ..filterQuality = FilterQuality.none;
  static final Paint _hpBgPaint = Paint()
    ..color = GameConstants.pixelInk.withValues(alpha: 0.78);
  static final Paint _hpFillPaint = Paint()
    ..color = GameConstants.hudDangerColor;
  final Paint _vanishRingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..color = GameConstants.pixelCyan;

  final Vector2 _shadowPos = Vector2.zero();
  final Vector2 _shadowSize = Vector2.zero();

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
       ) {
    _aiFrameCounter = _enemyId % GameConstants.farEnemyAiFrameInterval;
    _shadowSize.setValues(size.x * 0.72, 12.0);
    _shadowPos.setValues((size.x - _shadowSize.x) * 0.5, size.y - 10.0);
  }

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

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    // Lấy trực tiếp bộ SpriteAnimation đã cache 1 lần trong PixelSpriteCache (không tạo lại khi spawn)
    _anims = game.spriteCache.enemyAnimations[type];
    if (_anims == null) {
      await game.spriteCache.buildAllEnemyAnimations(game.images);
      _anims = game.spriteCache.enemyAnimations[type];
    }

    _animComponent = SpriteAnimationComponent(
      animation: _anims?.walk,
      size: size,
      anchor: Anchor.center,
      position: Vector2(size.x * 0.5, size.y * 0.5),
      paint: Paint()..filterQuality = FilterQuality.none,
    );
    add(_animComponent!);

    _hitbox = CircleHitbox(
      radius: (size.x * GameConstants.hitboxRatio) * 0.5,
      anchor: Anchor.center,
      position: Vector2(size.x * 0.5, size.y * 0.5),
    )..collisionType = CollisionType.passive;
    add(_hitbox!);
  }

  void _setAnimState(_EnemyAnimState next) {
    if (_animState == next || _animComponent == null || _anims == null) {
      return;
    }
    _animState = next;
    switch (next) {
      case _EnemyAnimState.move:
        _animComponent!.animation = _anims!.walk;
        break;
      case _EnemyAnimState.hit:
        _animComponent!.animation = _anims!.hit;
        break;
      case _EnemyAnimState.death:
        _animComponent!.animation = _anims!.death;
        break;
    }
  }

  @override
  void onMount() {
    super.onMount();
    game.registerEnemy(this);
  }

  @override
  void onRemove() {
    game.unregisterEnemy(this);
    super.onRemove();
  }

  /// Hiệu ứng biến mất khi hết 5 phút và Boss chuẩn bị xuất hiện
  void vanishAndDisappear() {
    if (isDead || isVanishing) {
      return;
    }
    isVanishing = true;
    _vanishTimer = 0;
  }

  void takeDamage(
    double amount,
    Vector2 knockbackDir, {
    double knockbackDistance = 7.0,
  }) {
    if (isDead || isVanishing) {
      return;
    }
    hp -= amount;
    _hitFlashTimer = 0.09;
    _setAnimState(_EnemyAnimState.hit);

    final kbLenSq = knockbackDir.length2;
    if (kbLenSq > 0.0001 && knockbackDistance > 0) {
      final invLen = knockbackDistance / math.sqrt(kbLenSq);
      final minBound = GameConstants.arenaPlayableMargin + size.x * 0.5;
      final maxBoundX =
          GameConstants.arenaWidth - GameConstants.arenaPlayableMargin - size.x * 0.5;
      final maxBoundY =
          GameConstants.arenaHeight - GameConstants.arenaPlayableMargin - size.y * 0.5;
      position.x = (position.x + knockbackDir.x * invLen).clamp(minBound, maxBoundX);
      position.y = (position.y + knockbackDir.y * invLen).clamp(minBound, maxBoundY);
    }

    game.spawnHitParticles(
      x: position.x,
      y: position.y,
      color: GameConstants.pixelWhite,
      count: 3,
      speed: 95.0,
      size: 3.5,
    );
    game.spawnDamageNumber(
      x: position.x,
      y: position.y,
      amount: amount.round(),
      color: GameConstants.pixelGold,
    );

    if (hp <= 0) {
      isDead = true;
      _deathAnimTimer = _deathAnimDuration;
      _hitbox?.collisionType = CollisionType.inactive;
      game.unregisterEnemy(this);
      _setAnimState(_EnemyAnimState.death);
      game.spawnHitParticles(
        x: position.x,
        y: position.y,
        color: GameConstants.hudDangerColor,
        count: 6,
        speed: 130.0,
        size: 4.5,
      );
      game.onEnemyKilledAt(position.x, position.y, scoreValue);
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
      takeDamage(
        other.damage,
        other.direction,
        knockbackDistance: other.knockback,
      );
      other.applyHitFeedbackAndConsumeOrBounce(
        hitX: position.x,
        hitY: position.y,
        hitEnemy: this,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    if (isVanishing) {
      final t = (_vanishTimer / _vanishDuration).clamp(0.0, 1.0);
      _vanishRingPaint.color = GameConstants.pixelCyan.withValues(
        alpha: 1.0 - t,
      );
      canvas.drawCircle(
        Offset(size.x * 0.5, size.y * 0.5),
        (size.x * 0.55) * (1.0 + t * 0.7),
        _vanishRingPaint,
      );
      return;
    }

    final shadow = game.sharedShadowSprite;
    if (shadow != null && !isDead) {
      shadow.render(
        canvas,
        position: _shadowPos,
        size: _shadowSize,
        overridePaint: _spritePaintTemplate,
      );
    }
  }

  @override
  void renderTree(Canvas canvas) {
    final half = size.x * 0.7;
    if (!game.isVisibleInCamera(position.x, position.y, half, half)) {
      return;
    }

    super.renderTree(canvas);

    // Thanh máu nhỏ phía trên: chỉ vẽ khi quái đã bị thương, bằng 2 drawRect + Paint cache
    if (!isVanishing && !isDead && hp < maxHp) {
      final ratio = (hp / maxHp).clamp(0.0, 1.0);
      final barW = size.x * 0.78;
      final left = (size.x - barW) * 0.5;
      canvas.drawRect(Rect.fromLTWH(left, -7, barW, 4), _hpBgPaint);
      canvas.drawRect(Rect.fromLTWH(left, -7, barW * ratio, 4), _hpFillPaint);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isVictory) {
      return;
    }

    // Chạy nốt hoạt ảnh death 4 frame rồi xóa khỏi world
    if (isDead) {
      _deathAnimTimer -= dt;
      if (_deathAnimTimer <= 0) {
        removeFromParent();
      }
      return;
    }

    if (isVanishing) {
      _vanishTimer += dt;
      final t = (_vanishTimer / _vanishDuration).clamp(0.0, 1.0);
      final s = math.max(0.05, 1.0 - t);
      scale.setValues(s, s);
      angle += dt * 10.0;
      if (_animComponent != null) {
        _animComponent!.opacity = (1.0 - t).clamp(0.0, 1.0);
      }
      if (_vanishTimer >= _vanishDuration) {
        removeFromParent();
      }
      return;
    }

    if (_hitFlashTimer > 0) {
      _hitFlashTimer -= dt;
      if (_hitFlashTimer <= 0) {
        _setAnimState(_EnemyAnimState.move);
      }
    }

    final player = game.player;
    if (player == null || !player.isMounted) {
      return;
    }

    final dx = player.position.x - position.x;
    final dy = player.position.y - position.y;
    final distSq = dx * dx + dy * dy;

    // Quái ở xa người chơi: chỉ tính lại hướng AI mỗi 3 frame
    final isFar = distSq > GameConstants.farEnemyAiDistanceSq;
    _aiFrameCounter++;
    final shouldRefreshAi =
        !isFar || (_aiFrameCounter % GameConstants.farEnemyAiFrameInterval == 0);

    if (shouldRefreshAi && distSq > 196.0) {
      final invDist = 1.0 / math.sqrt(distSq);
      _cachedDirX = dx * invDist;
      _cachedDirY = dy * invDist;

      // Hướng trái = lật ngang (scale.x = -1.0)
      if (_animComponent != null && _cachedDirX.abs() > 0.05) {
        final desiredScaleX = _cachedDirX < 0 ? -1.0 : 1.0;
        if (_animComponent!.scale.x != desiredScaleX) {
          _animComponent!.scale.x = desiredScaleX;
        }
      }
    }

    if (distSq > 196.0) {
      final step = speed * dt;
      position.x += _cachedDirX * step;
      position.y += _cachedDirY * step;
    }

    if (type == NormalEnemyType.email) {
      _rangedTimer -= dt;
      if (_rangedTimer <= 0 && distSq < 480.0 * 480.0) {
        _rangedTimer = 2.4;
        game.spawnBullet(
          x: position.x,
          y: position.y,
          dirX: dx,
          dirY: dy,
          damage: 12.0,
          speed: GameConstants.enemyBulletSpeed,
          color: GameConstants.hudDangerColor,
          maxDistance: 500.0,
          isEnemyBullet: true,
          bulletRadius: 7.0,
        );
      }
    } else if (type == NormalEnemyType.quiz) {
      _rangedTimer -= dt;
      if (_rangedTimer <= 0 && distSq < 420.0 * 420.0) {
        _rangedTimer = 3.3;
        final baseAngle = math.atan2(dy, dx);
        const spread = 0.24;
        for (int i = -1; i <= 1; i++) {
          final a = baseAngle + i * spread;
          game.spawnBullet(
            x: position.x,
            y: position.y,
            dirX: math.cos(a),
            dirY: math.sin(a),
            damage: 10.0,
            speed: GameConstants.enemyBulletSpeed * 0.9,
            color: GameConstants.accentColor,
            maxDistance: 440.0,
            isEnemyBullet: true,
            bulletRadius: 6.5,
          );
        }
      }
    }
  }
}

/// Phân loại quái thường trong giai đoạn sinh tồn 5 phút
enum NormalEnemyType {
  deadline, // Đồng hồ báo thức rung chuông đuổi theo
  email, // Phong bì vẫy cánh + huy hiệu đỏ bắn xa
  quiz, // Đề thi tím lao nhanh + dấu ! nhấp nháy
}
