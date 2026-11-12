import 'dart:async';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../game/huit_game.dart';

/// Vẽ nền bản đồ chiến trường HUIT từ sprite pixel art theo từng màn
class ArenaBackgroundComponent extends PositionComponent
    with HasGameReference<HuitDeadlineGame> {
  Sprite? _mapSprite;
  final Paint _spritePaint = Paint()..filterQuality = FilterQuality.none;
  final Paint _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4.0;
  final Paint _outerDarkPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.35);

  ArenaBackgroundComponent()
    : super(
        size: Vector2(GameConstants.arenaWidth, GameConstants.arenaHeight),
        priority: -10,
      );

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    final image = await game.images.load(game.selectedStage.flameMapPath);
    _mapSprite = Sprite(image);
  }

  @override
  void render(Canvas canvas) {
    final fullRect = size.toRect();
    final sprite = _mapSprite;
    if (sprite != null) {
      sprite.render(
        canvas,
        size: size,
        overridePaint: _spritePaint,
      );
    } else {
      canvas.drawRect(
        fullRect,
        Paint()..color = const Color(0xFF1A1C2C),
      );
    }

    // Vùng tối nhẹ ngoài biên playable margin để người chơi nhận biết giới hạn di chuyển
    const margin = GameConstants.arenaPlayableMargin;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, margin), _outerDarkPaint);
    canvas.drawRect(
      Rect.fromLTWH(0, size.y - margin, size.x, margin),
      _outerDarkPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, margin, margin, size.y - margin * 2),
      _outerDarkPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x - margin, margin, margin, size.y - margin * 2),
      _outerDarkPaint,
    );

    // Viền sáng đánh dấu ranh giới khu vực chiến đấu an toàn
    _borderPaint.color = game.selectedStage.themeColor.withValues(alpha: 0.72);
    canvas.drawRect(
      Rect.fromLTRB(margin, margin, size.x - margin, size.y - margin),
      _borderPaint,
    );
  }
}
