import 'dart:async';
import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../game/huit_game.dart';
import '../models/weapon_config.dart';
import 'enemy_component.dart';

/// Đạn bắn tái sử dụng qua Object Pool hỗ trợ hoạt ảnh và cơ chế riêng cho từng vũ khí:
/// - Bút bi (penInk): đạn mực 3 frame + vệt xanh ngắn phía sau.
/// - USB (usbShuriken): xoay 4 frame 90 độ, nảy tường đấu trường tối đa 2 lần, gây sát thương mỗi lần nảy.
/// - Trà sữa (bobaPearl): đạn trân châu nảy nhẹ, trúng quái hồi máu nhỏ cho người chơi + nổ bong bóng.
/// - Đạn quái/Boss (standard): lõi sáng + viền cảnh báo rõ nét.
/// Mọi Paint đều tái sử dụng, không quét world.children, không tạo object mới trong update/render.
class BulletComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<HuitDeadlineGame> {
  final Vector2 direction = Vector2(1, 0);
  double speed;
  double damage;
  Color color;
  Color secondaryColor;
  double maxDistance;
  bool isEnemyBullet;
  BulletVisualStyle visualStyle;
  int remainingBounces;
  double healOnHit;
  bool bubbleOnHit;
  double knockback;

  double _traveledDistance = 0;
  double _animTime = 0;
  bool _hasHit = false;
  bool inPool = false;
  EnemyComponent? _lastHitEnemy;

  CircleHitbox? _hitbox;

  // Toàn bộ Paint tái sử dụng, không cấp phát trong render()
  final Paint _outerGlowPaint = Paint();
  final Paint _bodyPaint = Paint();
  final Paint _corePaint = Paint();
  final Paint _trailPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _outlinePaint = Paint()
    ..color = GameConstants.pixelInk
    ..style = PaintingStyle.fill;

  BulletComponent({
    required super.position,
    required Vector2 direction,
    required this.damage,
    this.speed = GameConstants.bulletSpeed,
    this.color = GameConstants.pixelCyan,
    this.secondaryColor = GameConstants.pixelHuitBlue,
    this.maxDistance = GameConstants.bulletMaxDistance,
    this.isEnemyBullet = false,
    double bulletRadius = 8.0,
    this.visualStyle = BulletVisualStyle.standard,
    this.remainingBounces = 0,
    this.healOnHit = 0.0,
    this.bubbleOnHit = false,
    this.knockback = 7.0,
  }) : super(
         size: Vector2.all(bulletRadius * 2),
         anchor: Anchor.center,
         priority: isEnemyBullet ? 15 : 14,
       ) {
    if (direction.length2 > 0) {
      this.direction.setFrom(direction);
      this.direction.normalize();
    }
    _syncPaints();
  }

  bool get isConsumed => _hasHit;

  void _syncPaints() {
    _outerGlowPaint.color = color.withValues(alpha: 0.34);
    _bodyPaint.color = color;
    _corePaint.color = isEnemyBullet
        ? const Color(0xFFFFEBEE)
        : GameConstants.pixelWhite;
    _trailPaint
      ..color = secondaryColor.withValues(alpha: 0.78)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.square;
  }

  /// Thiết lập lại toàn bộ trạng thái khi lấy đạn ra từ Object Pool
  void reset({
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
    position.setValues(x, y);
    direction.setValues(dirX, dirY);
    if (direction.length2 > 0.000001) {
      direction.normalize();
    } else {
      direction.setValues(1, 0);
    }
    this.damage = damage;
    this.speed = speed;
    this.color = color;
    this.secondaryColor = secondaryColor;
    this.maxDistance = maxDistance;
    this.isEnemyBullet = isEnemyBullet;
    this.visualStyle = visualStyle;
    this.remainingBounces = remainingBounces;
    this.healOnHit = healOnHit;
    this.bubbleOnHit = bubbleOnHit;
    this.knockback = knockback;
    priority = isEnemyBullet ? 15 : 14;

    final diameter = bulletRadius * 2;
    size.setValues(diameter, diameter);
    if (_hitbox != null) {
      _hitbox!.radius = diameter * 0.45;
      _hitbox!.position.setValues(bulletRadius, bulletRadius);
      _hitbox!.collisionType = CollisionType.active;
    }

    _traveledDistance = 0;
    _animTime = 0;
    _hasHit = false;
    _lastHitEnemy = null;
    inPool = false;
    _syncPaints();
  }

  void consume() {
    if (_hasHit) {
      return;
    }
    _hasHit = true;
    removeFromParent();
  }

  /// Xử lý trúng mục tiêu (hồi máu trà sữa, bong bóng nổ, hoặc nảy tiếp nếu là USB còn lượt nảy)
  void applyHitFeedbackAndConsumeOrBounce({
    required double hitX,
    required double hitY,
    EnemyComponent? hitEnemy,
  }) {
    if (healOnHit > 0) {
      game.player?.heal(healOnHit);
    }
    if (bubbleOnHit) {
      game.spawnHitParticles(
        x: hitX,
        y: hitY,
        color: secondaryColor,
        count: 5,
        speed: 85.0,
        size: 5.5,
        life: 0.34,
        isBubble: true,
      );
    }

    // USB phi tiêu: nếu còn lượt nảy và vừa trúng quái, nảy sang hướng khác và gây sát thương tiếp
    if (remainingBounces > 0 && hitEnemy != null) {
      remainingBounces--;
      _lastHitEnemy = hitEnemy;
      final nx = position.x - hitEnemy.position.x;
      final ny = position.y - hitEnemy.position.y;
      final nLenSq = nx * nx + ny * ny;
      if (nLenSq > 0.0001) {
        final invN = 1.0 / math.sqrt(nLenSq);
        final ux = nx * invN;
        final uy = ny * invN;
        final dot = direction.x * ux + direction.y * uy;
        direction.setValues(
          direction.x - 2.0 * dot * ux,
          direction.y - 2.0 * dot * uy,
        );
        direction.normalize();
      } else {
        direction.setValues(-direction.x, -direction.y);
      }
      game.spawnHitParticles(
        x: hitX,
        y: hitY,
        color: color,
        count: 4,
        speed: 115.0,
        size: 3.5,
      );
      return;
    }

    consume();
  }

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    _hitbox = CircleHitbox(
      radius: size.x * 0.45,
      anchor: Anchor.center,
      position: Vector2(size.x * 0.5, size.y * 0.5),
    )..collisionType = CollisionType.active;
    add(_hitbox!);
  }

  @override
  void onMount() {
    super.onMount();
    game.registerBullet(this);
  }

  @override
  void onRemove() {
    game.unregisterBullet(this);
    super.onRemove();
    game.recycleBullet(this);
  }

  @override
  void renderTree(Canvas canvas) {
    final half = size.x * 0.85;
    if (!game.isVisibleInCamera(position.x, position.y, half, half)) {
      return;
    }
    super.renderTree(canvas);
  }

  @override
  void render(Canvas canvas) {
    final radius = size.x * 0.5;
    final center = Offset(radius, radius);

    switch (visualStyle) {
      case BulletVisualStyle.penInk:
        // Đạn mực 3 frame + vệt xanh ngắn phía sau
        final frame = (_animTime * 18.0).floor() % 3;
        final tailLen = 9.0 + frame * 3.0;
        final tailEnd = Offset(
          center.dx - direction.x * tailLen,
          center.dy - direction.y * tailLen,
        );
        canvas.drawLine(center, tailEnd, _trailPaint);
        canvas.drawCircle(center, radius * 0.95, _outerGlowPaint);
        canvas.drawCircle(center, radius * (0.62 + frame * 0.06), _bodyPaint);
        canvas.drawCircle(center, radius * 0.32, _corePaint);
        break;

      case BulletVisualStyle.usbShuriken:
        // USB xoay 4 frame (0, 90, 180, 270 độ) sắc nét kiểu pixel shuriken
        final frame = (_animTime * 20.0).floor() % 4;
        final r = radius * 0.85;
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(frame * (math.pi * 0.5));
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: r * 1.9, height: r * 0.75),
          _outlinePaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: r * 0.75, height: r * 1.9),
          _outlinePaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 0.52),
          _bodyPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: r * 0.52, height: r * 1.6),
          _bodyPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: r * 0.45, height: r * 0.45),
          _corePaint,
        );
        canvas.restore();
        break;

      case BulletVisualStyle.bobaPearl:
        // Đạn trân châu nảy nhẹ lên xuống + ánh kem bóng
        final bounceDy = math.sin(_animTime * 22.0) * 2.2;
        final pearlCenter = Offset(center.dx, center.dy + bounceDy);
        canvas.drawCircle(pearlCenter, radius * 0.85, _outlinePaint);
        canvas.drawCircle(pearlCenter, radius * 0.70, _bodyPaint);
        canvas.drawCircle(
          Offset(pearlCenter.dx - radius * 0.22, pearlCenter.dy - radius * 0.22),
          radius * 0.24,
          _corePaint,
        );
        break;

      case BulletVisualStyle.standard:
        canvas.drawCircle(center, radius * 1.15, _outerGlowPaint);
        canvas.drawCircle(center, radius * 0.72, _bodyPaint);
        canvas.drawCircle(center, radius * 0.36, _corePaint);
        break;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hasHit || game.isGameOver || game.isVictory) {
      return;
    }

    _animTime += dt;
    final prevX = position.x;
    final prevY = position.y;
    final stepDist = speed * dt;
    double nextX = prevX + direction.x * stepDist;
    double nextY = prevY + direction.y * stepDist;

    // USB Shuriken: nảy tường đấu trường tối đa 2 lần
    if (remainingBounces > 0) {
      const minWall = GameConstants.arenaPlayableMargin + 8.0;
      const maxWallX =
          GameConstants.arenaWidth - GameConstants.arenaPlayableMargin - 8.0;
      const maxWallY =
          GameConstants.arenaHeight - GameConstants.arenaPlayableMargin - 8.0;
      bool bouncedWall = false;

      if (nextX <= minWall && direction.x < 0) {
        nextX = minWall;
        direction.x = -direction.x;
        bouncedWall = true;
      } else if (nextX >= maxWallX && direction.x > 0) {
        nextX = maxWallX;
        direction.x = -direction.x;
        bouncedWall = true;
      }

      if (nextY <= minWall && direction.y < 0) {
        nextY = minWall;
        direction.y = -direction.y;
        bouncedWall = true;
      } else if (nextY >= maxWallY && direction.y > 0) {
        nextY = maxWallY;
        direction.y = -direction.y;
        bouncedWall = true;
      }

      if (bouncedWall) {
        remainingBounces--;
        _lastHitEnemy = null;
        game.spawnHitParticles(
          x: nextX,
          y: nextY,
          color: color,
          count: 4,
          speed: 105.0,
          size: 3.5,
        );
      }
    }

    position.setValues(nextX, nextY);
    _traveledDistance += stepDist;

    // Đạn người chơi: 1 lần quét đoạn thẳng (swept check) duy nhất trên danh sách enemies + boss đã cache
    if (!isEnemyBullet &&
        _checkSweptPlayerHit(prevX, prevY, nextX, nextY)) {
      return;
    }

    if (_traveledDistance >= maxDistance ||
        nextX < -40 ||
        nextY < -40 ||
        nextX > GameConstants.arenaWidth + 40 ||
        nextY > GameConstants.arenaHeight + 40) {
      consume();
    }
  }

  /// Kiểm tra giao cắt đoạn thẳng AB với hình tròn mục tiêu (không sqrt, không tạo Vector2)
  bool _checkSweptPlayerHit(double ax, double ay, double bx, double by) {
    final bulletRadius = size.x * 0.45;
    final abx = bx - ax;
    final aby = by - ay;
    final abLenSq = abx * abx + aby * aby;

    final enemies = game.enemies;
    for (int i = enemies.length - 1; i >= 0; i--) {
      final enemy = enemies[i];
      if (enemy.isDead ||
          enemy.isVanishing ||
          !enemy.isMounted ||
          identical(enemy, _lastHitEnemy)) {
        continue;
      }
      final hitRadius = enemy.size.x * 0.45 + bulletRadius;
      if (_segmentHitsCircle(
        ax,
        ay,
        abx,
        aby,
        abLenSq,
        enemy.position.x,
        enemy.position.y,
        hitRadius,
      )) {
        enemy.takeDamage(damage, direction, knockbackDistance: knockback);
        applyHitFeedbackAndConsumeOrBounce(
          hitX: enemy.position.x,
          hitY: enemy.position.y,
          hitEnemy: enemy,
        );
        return true;
      }
    }

    final boss = game.boss;
    if (boss != null && boss.isMounted && !boss.isDead) {
      final bossRadius =
          (boss.size.x * GameConstants.bossHitboxRatio) * 0.5 + bulletRadius;
      if (_segmentHitsCircle(
        ax,
        ay,
        abx,
        aby,
        abLenSq,
        boss.position.x,
        boss.position.y,
        bossRadius,
      )) {
        boss.takeDamage(damage);
        applyHitFeedbackAndConsumeOrBounce(
          hitX: boss.position.x,
          hitY: boss.position.y,
        );
        return true;
      }
    }

    return false;
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
