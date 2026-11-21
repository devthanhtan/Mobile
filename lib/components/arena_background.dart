import 'dart:async';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../game/huit_game.dart';

/// Vẽ nền bản đồ chiến trường HUIT:
/// Ghi (record) toàn bộ nền + 4 dải biên tối + khung sáng MỘT LẦN ra ui.Picture
/// trong onLoad() (tiết kiệm ~10 MB VRAM so với nhân bản bitmap 1600x1600),
/// rồi mỗi frame chỉ replay đúng 1 lệnh drawPicture.
class ArenaBackgroundComponent extends PositionComponent
    with HasGameReference<HuitDeadlineGame> {
  ui.Picture? _bakedArenaPicture;

  static final Paint _spritePaint = Paint()..filterQuality = FilterQuality.none;
  static final Paint _fallbackPaint = Paint()..color = GameConstants.pixelInk;

  ArenaBackgroundComponent()
    : super(
        size: Vector2(GameConstants.arenaWidth, GameConstants.arenaHeight),
        priority: -10,
      );

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    final mapImage = await game.images.load(game.selectedStage.flameMapPath);
    _recordArenaPicture(mapImage);
  }

  /// Ghi sẵn toàn bộ lệnh vẽ nền đấu trường MỘT LẦN ra ui.Picture
  void _recordArenaPicture(ui.Image mapImage) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 1. Nền bản đồ pixel art (FilterQuality.none)
    canvas.drawImageRect(
      mapImage,
      Rect.fromLTWH(
        0,
        0,
        mapImage.width.toDouble(),
        mapImage.height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, size.x, size.y),
      _spritePaint,
    );

    // 2. Vùng tối nhẹ ngoài biên playable margin
    const margin = GameConstants.arenaPlayableMargin;
    final outerDarkPaint = Paint()
      ..color = GameConstants.pixelShadowBlack.withValues(alpha: 0.36);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, margin), outerDarkPaint);
    canvas.drawRect(
      Rect.fromLTWH(0, size.y - margin, size.x, margin),
      outerDarkPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, margin, margin, size.y - margin * 2),
      outerDarkPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x - margin, margin, margin, size.y - margin * 2),
      outerDarkPaint,
    );

    // 3. Viền sáng đánh dấu ranh giới khu vực chiến đấu an toàn
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = game.selectedStage.themeColor.withValues(alpha: 0.72);
    canvas.drawRect(
      Rect.fromLTRB(margin, margin, size.x - margin, size.y - margin),
      borderPaint,
    );

    _bakedArenaPicture?.dispose();
    _bakedArenaPicture = recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    final picture = _bakedArenaPicture;
    if (picture == null) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _fallbackPaint);
      return;
    }
    canvas.drawPicture(picture);
  }

  @override
  void onRemove() {
    _bakedArenaPicture?.dispose();
    _bakedArenaPicture = null;
    super.onRemove();
  }
}
