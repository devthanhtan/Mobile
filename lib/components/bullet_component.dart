import 'dart:async';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../game/huit_game.dart';
import 'boss_component.dart';
import 'enemy_component.dart';

/// Đạn bắn của Người chơi hoặc Quái/Boss với hitbox va chạm tự động & chống trượt cự ly gần
class BulletComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<HuitDeadlineGame> {
  final Vector2 direction;
  final double speed;
  final double damage;
  final Color color;
  final double maxDistance;
  final bool isEnemyBullet;

  double _traveledDistance = 0;
  bool _hasHit = false;

  late final Paint _outerGlowPaint;
  late final Paint _bodyPaint;
  late final Paint _corePaint;

  BulletComponent({
    required super.position,
    required Vector2 direction,
    required this.damage,
    this.speed = GameConstants.bulletSpeed,
    this.color = Colors.cyanAccent,
    this.maxDistance = GameConstants.bulletMaxDistance,
    this.isEnemyBullet = false,
    double bulletRadius = 8.0,
  }) : direction = direction.length2 > 0
           ? direction.normalized()
           : Vector2(1, 0),
       super(
         size: Vector2.all(bulletRadius * 2),
         anchor: Anchor.center,
         priority: isEnemyBullet ? 15 : 14,
       ) {
    _outerGlowPaint = Paint()..color = color.withValues(alpha: 0.32);
    _bodyPaint = Paint()..color = color;
    _corePaint = Paint()
      ..color = isEnemyBullet ? const Color(0xFFFFEBEE) : Colors.white;
  }

  bool get isConsumed => _hasHit;

  void consume() {
    if (_hasHit) {
      return;
    }
    _hasHit = true;
    removeFromParent();
  }

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    add(
      CircleHitbox(
        radius: size.x * 0.45,
        anchor: Anchor.center,
        position: size / 2,
      )..collisionType = CollisionType.active,
    );
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final radius = size.x / 2;
    canvas.drawCircle(center, radius * 1.15, _outerGlowPaint);
    canvas.drawCircle(center, radius * 0.72, _bodyPaint);
    canvas.drawCircle(center, radius * 0.36, _corePaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_hasHit || game.isGameOver || game.isVictory) {
      return;
    }

    // Kiểm tra va chạm trực tiếp cự ly cực gần (khi quái áp sát ngay trên người chơi)
    if (!isEnemyBullet && _checkPointBlankPlayerBulletHit()) {
      return;
    }

    final delta = direction * speed * dt;
    position.add(delta);
    _traveledDistance += delta.length;

    if (!isEnemyBullet && _checkPointBlankPlayerBulletHit()) {
      return;
    }

    if (_traveledDistance >= maxDistance ||
        position.x < -40 ||
        position.y < -40 ||
        position.x > GameConstants.arenaWidth + 40 ||
        position.y > GameConstants.arenaHeight + 40) {
      removeFromParent();
    }
  }

  bool _checkPointBlankPlayerBulletHit() {
    final bulletRadius = size.x * 0.45;
    for (final child in game.world.children) {
      if (child is EnemyComponent && !child.isDead && !child.isVanishing) {
        final enemyRadius = (child.size.x * 0.45) + bulletRadius;
        if (position.distanceTo(child.position) <= enemyRadius) {
          child.takeDamage(damage, direction);
          consume();
          return true;
        }
      } else if (child is BossComponent && !child.isDead) {
        final bossRadius =
            (child.size.x * GameConstants.bossHitboxRatio) / 2 + bulletRadius;
        if (position.distanceTo(child.position) <= bossRadius) {
          child.takeDamage(damage);
          consume();
          return true;
        }
      }
    }
    return false;
  }
}
