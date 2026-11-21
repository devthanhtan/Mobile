import 'dart:async';
import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../game/huit_game.dart';

/// Phân loại vật phẩm rơi từ quái
enum DropItemType {
  noodle, // Mì ly: hồi máu +24 HP
  coffee, // Cà phê: tăng tốc chạy & tốc bắn 6s
  shield, // Khiên bảo vệ: +1 lớp khiên (tối đa 2)
  coin, // Xu sinh viên: +10 xu, +50 điểm
}

/// Vật phẩm rơi trên bản đồ sử dụng SpriteAnimationComponent 4 frame (nhấp nhô + lấp lánh)
/// đã được tạo MỘT LẦN và cache trong PixelSpriteCache (không tạo lại khi spawn).
class ItemComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<HuitDeadlineGame> {
  final DropItemType type;
  SpriteAnimationComponent? _animComponent;
  double _age = 0;
  bool isCollected = false;
  static const double _maxLifetime = 18.0;
  static const double _magnetRangeSq = 88.0 * 88.0;
  static const double _pickupRangeSq = 30.0 * 30.0;

  static final Map<DropItemType, Paint> _auraPaints = {
    DropItemType.noodle: Paint()
      ..color = GameConstants.hudHpHealthyColor.withValues(alpha: 0.24),
    DropItemType.coffee: Paint()
      ..color = GameConstants.accentColor.withValues(alpha: 0.24),
    DropItemType.shield: Paint()
      ..color = GameConstants.pixelCyan.withValues(alpha: 0.24),
    DropItemType.coin: Paint()
      ..color = GameConstants.hudGoldColor.withValues(alpha: 0.24),
  };

  ItemComponent({
    required super.position,
    required this.type,
  }) : super(
         size: Vector2.all(GameConstants.itemSize),
         anchor: Anchor.center,
         priority: 6,
       );

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    var anim = game.spriteCache.itemAnimations[type];
    if (anim == null) {
      await game.spriteCache.buildAllItemAnimations(game.images);
      anim = game.spriteCache.itemAnimations[type];
    }

    _animComponent = SpriteAnimationComponent(
      animation: anim,
      size: size,
      anchor: Anchor.center,
      position: Vector2(size.x * 0.5, size.y * 0.5),
      paint: Paint()..filterQuality = FilterQuality.none,
    );
    add(_animComponent!);

    add(
      CircleHitbox(
        radius: size.x * 0.45,
        anchor: Anchor.center,
        position: Vector2(size.x * 0.5, size.y * 0.5),
      )..collisionType = CollisionType.passive,
    );
  }

  @override
  void onMount() {
    super.onMount();
    game.registerItem(this);
  }

  @override
  void onRemove() {
    game.unregisterItem(this);
    super.onRemove();
  }

  void markCollected() {
    if (isCollected) {
      return;
    }
    isCollected = true;
    removeFromParent();
  }

  @override
  void renderTree(Canvas canvas) {
    final half = size.x * 0.7;
    if (!game.isVisibleInCamera(position.x, position.y, half, half)) {
      return;
    }
    super.renderTree(canvas);
  }

  @override
  void render(Canvas canvas) {
    final half = size.x * 0.5;
    canvas.drawCircle(
      Offset(half, half),
      size.x * 0.56,
      _auraPaints[type]!,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isCollected || game.isGameOver || game.isVictory) {
      return;
    }

    _age += dt;
    if (_age >= _maxLifetime) {
      removeFromParent();
      return;
    }

    if (_animComponent != null && _age > _maxLifetime - 3.0) {
      final visible = ((_age * 8).floor() % 2 == 0);
      _animComponent!.opacity = visible ? 1.0 : 0.25;
    }

    final player = game.player;
    if (player == null || !player.isMounted) {
      return;
    }

    final dx = player.position.x - position.x;
    final dy = player.position.y - position.y;
    final distSq = dx * dx + dy * dy;

    if (distSq > 16.0 && distSq < _magnetRangeSq) {
      final invDist = (210.0 * dt) / math.sqrt(distSq);
      position.x += dx * invDist;
      position.y += dy * invDist;
    }

    if (distSq <= _pickupRangeSq) {
      player.collectItem(type);
      markCollected();
    }
  }
}
