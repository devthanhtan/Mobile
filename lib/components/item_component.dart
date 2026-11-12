import 'dart:async';
import 'dart:math' as math;
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

/// Vật phẩm rơi trên bản đồ với hiệu ứng nhấp nhô & hút nhẹ khi lại gần
class ItemComponent extends PositionComponent
    with HasGameReference<HuitDeadlineGame> {
  final DropItemType type;
  SpriteComponent? _sprite;
  double _age = 0;
  static const double _maxLifetime = 18.0;

  ItemComponent({
    required super.position,
    required this.type,
  }) : super(
         size: Vector2.all(GameConstants.itemSize),
         anchor: Anchor.center,
         priority: 6,
       );

  String get _flamePath {
    switch (type) {
      case DropItemType.noodle:
        return GameConstants.itemNoodlePath;
      case DropItemType.coffee:
        return GameConstants.itemCoffeePath;
      case DropItemType.shield:
        return GameConstants.itemShieldPath;
      case DropItemType.coin:
        return GameConstants.itemCoinPath;
    }
  }

  Color get _auraColor {
    switch (type) {
      case DropItemType.noodle:
        return Colors.greenAccent;
      case DropItemType.coffee:
        return Colors.amberAccent;
      case DropItemType.shield:
        return Colors.cyanAccent;
      case DropItemType.coin:
        return Colors.yellowAccent;
    }
  }

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    final image = await game.images.load(_flamePath);
    _sprite = SpriteComponent(
      sprite: Sprite(image),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
      paint: Paint()..filterQuality = FilterQuality.none,
    );
    add(_sprite!);
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(
      center,
      size.x * 0.56,
      Paint()..color = _auraColor.withValues(alpha: 0.22),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isVictory) {
      return;
    }

    _age += dt;
    if (_age >= _maxLifetime) {
      removeFromParent();
      return;
    }

    // Hiệu ứng nhấp nhô nhẹ
    if (_sprite != null) {
      _sprite!.position.y = (size.y / 2) + math.sin(_age * 5.0) * 3.0;
      if (_age > _maxLifetime - 3.0) {
        final visible = ((_age * 8).floor() % 2 == 0);
        _sprite!.opacity = visible ? 1.0 : 0.25;
      }
    }

    final player = game.player;
    if (player == null || !player.isMounted) {
      return;
    }

    final toPlayer = player.position - position;
    final dist = toPlayer.length;

    // Hút nhẹ về người chơi khi lại gần
    if (dist > 4.0 && dist < 88.0) {
      position.add(toPlayer.normalized() * 210.0 * dt);
    }

    // Nhặt vật phẩm
    if (dist <= 30.0) {
      player.collectItem(type);
      removeFromParent();
    }
  }
}

