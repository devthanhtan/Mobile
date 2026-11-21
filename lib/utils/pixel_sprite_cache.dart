import 'dart:ui' as ui;
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../components/enemy_component.dart';
import '../components/item_component.dart';
import '../constants.dart';

/// Bộ hoạt ảnh đã cache sẵn cho Nhân vật & Quái (idle 4f, walk 4f, hit 1f, death 4f)
class ActorAnimationBundle {
  final SpriteAnimation idle;
  final SpriteAnimation walk;
  final SpriteAnimation hit;
  final SpriteAnimation death;

  const ActorAnimationBundle({
    required this.idle,
    required this.walk,
    required this.hit,
    required this.death,
  });
}

/// Bộ hoạt ảnh đã cache sẵn cho Boss (idle 4f, attack 4f, phase2 4f, death 6f, hit 1f)
class BossAnimationBundle {
  final SpriteAnimation idle;
  final SpriteAnimation attack;
  final SpriteAnimation phase2;
  final SpriteAnimation death;
  final SpriteAnimation hit;

  const BossAnimationBundle({
    required this.idle,
    required this.attack,
    required this.phase2,
    required this.death,
    required this.hit,
  });
}

/// Quản lý tạo MỘT LẦN và cache toàn bộ SpriteAnimation & Sprite dùng chung:
/// - Cắt trực tiếp từ các strip PNG (*_sheet.png) bằng srcPosition/srcSize (0 cấp phát ui.Image thừa).
/// - Tất cả animation chỉ tạo 1 lần duy nhất trong onLoad(), tuyệt đối không tạo lại khi spawn.
class PixelSpriteCache {
  final List<ui.Image> _ownedImages = [];

  Sprite? groundShadowSprite;
  Sprite? playerDashGhostSprite;
  Sprite? bossHitFlashSprite;
  Sprite? bossChargeTintSprite;
  final Map<String, Sprite> _hitFlashSprites = {};

  ActorAnimationBundle? playerAnimations;
  final Map<NormalEnemyType, ActorAnimationBundle> enemyAnimations = {};
  BossAnimationBundle? bossAnimations;
  final Map<DropItemType, SpriteAnimation> itemAnimations = {};

  Sprite? getHitFlashSprite(String key) => _hitFlashSprites[key];

  /// Vẽ sẵn bóng chân hình elip dẹt pixel một lần duy nhất
  Future<Sprite> bakeGroundShadowSprite() async {
    if (groundShadowSprite != null) {
      return groundShadowSprite!;
    }
    const width = 48;
    const height = 16;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = GameConstants.pixelShadowBlack.withValues(alpha: 0.36)
      ..isAntiAlias = false;

    canvas.drawOval(const Rect.fromLTWH(4, 2, 40, 12), paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    _ownedImages.add(image);
    final sprite = Sprite(image);
    groundShadowSprite = sprite;
    return sprite;
  }

  /// Tạo sẵn bản sprite phủ màu đơn sắc (nháy trắng hoặc bóng Dash cyan)
  Future<Sprite> bakeTintedSprite({
    required ui.Image source,
    required Color tintColor,
    required BlendMode blendMode,
    String? cacheKey,
  }) async {
    if (cacheKey != null && _hitFlashSprites.containsKey(cacheKey)) {
      return _hitFlashSprites[cacheKey]!;
    }

    final width = source.width;
    final height = source.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..colorFilter = ColorFilter.mode(tintColor, blendMode);

    canvas.drawImage(source, Offset.zero, paint);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    _ownedImages.add(image);

    final sprite = Sprite(image);
    if (cacheKey != null) {
      _hitFlashSprites[cacheKey] = sprite;
    }
    return sprite;
  }

  /// Cắt strip ngang thành SpriteAnimation đồng bộ (0 tạo ui.Image mới)
  SpriteAnimation _sliceStrip(
    ui.Image sheet, {
    required int start,
    required int count,
    required double cell,
    required double stepTime,
    required bool loop,
  }) {
    final totalCols = (sheet.width ~/ cell.round()).clamp(1, 256);
    final sprites = List<Sprite>.generate(count, (i) {
      final col = (start + i) % totalCols;
      return Sprite(
        sheet,
        srcPosition: Vector2(col * cell, 0),
        srcSize: Vector2(cell, cell),
      );
    });
    return SpriteAnimation.spriteList(sprites, stepTime: stepTime, loop: loop);
  }

  /// Nạp file *_sheet.png nếu đã đóng gói trong APK; nếu chưa (ví dụ chỉ mới Hot Restart)
  /// thì tự động xóa cache lỗi và dùng ảnh gốc *.png để không bao giờ kẹt onLoad().
  Future<ui.Image> _loadSheetOrFallbackBase(
    Images images,
    String baseFlamePath,
  ) async {
    final sheetPath = baseFlamePath.replaceFirst('.png', '_sheet.png');
    try {
      return await images.load(sheetPath);
    } catch (_) {
      images.clear(sheetPath);
      return await images.load(baseFlamePath);
    }
  }

  /// Xây dựng & cache bộ hoạt ảnh Nhân vật (idle 4f, walk 4f, hit 1f, death 4f)
  Future<ActorAnimationBundle> buildPlayerAnimations({
    required Images images,
    required String baseFlamePath,
  }) async {
    if (playerAnimations != null) {
      return playerAnimations!;
    }
    final sheetImg = await _loadSheetOrFallbackBase(images, baseFlamePath);
    final cell = sheetImg.height.toDouble();

    playerAnimations = ActorAnimationBundle(
      idle: _sliceStrip(sheetImg, start: 0, count: 4, cell: cell, stepTime: 0.16, loop: true),
      walk: _sliceStrip(sheetImg, start: 4, count: 4, cell: cell, stepTime: 0.10, loop: true),
      hit: _sliceStrip(sheetImg, start: 8, count: 1, cell: cell, stepTime: 0.08, loop: false),
      death: _sliceStrip(sheetImg, start: 9, count: 4, cell: cell, stepTime: 0.08, loop: false),
    );
    return playerAnimations!;
  }

  /// Xây dựng & cache bộ hoạt ảnh cho 3 loại Quái thường (idle/move 4f, hit 1f, death 4f)
  Future<void> buildAllEnemyAnimations(Images images) async {
    const configs = <NormalEnemyType, String>{
      NormalEnemyType.deadline: GameConstants.enemyDeadlinePath,
      NormalEnemyType.email: GameConstants.enemyEmailPath,
      NormalEnemyType.quiz: GameConstants.enemyQuizPath,
    };

    for (final entry in configs.entries) {
      final type = entry.key;
      if (enemyAnimations.containsKey(type)) {
        continue;
      }
      final sheetImg = await _loadSheetOrFallbackBase(images, entry.value);
      final cell = sheetImg.height.toDouble();
      final moveAnim = _sliceStrip(
        sheetImg,
        start: 0,
        count: 4,
        cell: cell,
        stepTime: 0.10,
        loop: true,
      );

      enemyAnimations[type] = ActorAnimationBundle(
        idle: moveAnim,
        walk: moveAnim,
        hit: _sliceStrip(sheetImg, start: 4, count: 1, cell: cell, stepTime: 0.08, loop: false),
        death: _sliceStrip(sheetImg, start: 5, count: 4, cell: cell, stepTime: 0.07, loop: false),
      );
    }
  }

  /// Xây dựng & cache bộ hoạt ảnh cho Boss (idle 4f, attack 4f, phase2 4f, death 6f, hit 1f)
  Future<BossAnimationBundle> buildBossAnimations({
    required Images images,
    required String baseFlamePath,
  }) async {
    if (bossAnimations != null) {
      return bossAnimations!;
    }
    final sheetImg = await _loadSheetOrFallbackBase(images, baseFlamePath);
    final cell = sheetImg.height.toDouble();

    bossAnimations = BossAnimationBundle(
      idle: _sliceStrip(sheetImg, start: 0, count: 4, cell: cell, stepTime: 0.15, loop: true),
      attack: _sliceStrip(sheetImg, start: 4, count: 4, cell: cell, stepTime: 0.12, loop: true),
      phase2: _sliceStrip(sheetImg, start: 8, count: 4, cell: cell, stepTime: 0.10, loop: true),
      death: _sliceStrip(sheetImg, start: 12, count: 6, cell: cell, stepTime: 0.09, loop: false),
      hit: _sliceStrip(sheetImg, start: 18, count: 1, cell: cell, stepTime: 0.08, loop: false),
    );
    return bossAnimations!;
  }

  /// Xây dựng & cache hoạt ảnh 4 frame nhấp nhô + lấp lánh cho 4 loại Vật phẩm
  Future<void> buildAllItemAnimations(Images images) async {
    const configs = <DropItemType, String>{
      DropItemType.coffee: GameConstants.itemCoffeePath,
      DropItemType.noodle: GameConstants.itemNoodlePath,
      DropItemType.shield: GameConstants.itemShieldPath,
      DropItemType.coin: GameConstants.itemCoinPath,
    };

    for (final entry in configs.entries) {
      final type = entry.key;
      if (itemAnimations.containsKey(type)) {
        continue;
      }
      final sheetImg = await _loadSheetOrFallbackBase(images, entry.value);
      final cell = sheetImg.height.toDouble();

      itemAnimations[type] = _sliceStrip(
        sheetImg,
        start: 0,
        count: 4,
        cell: cell,
        stepTime: 0.15,
        loop: true,
      );
    }
  }

  /// Giải phóng toàn bộ ui.Image đã dựng sẵn khi game bị hủy
  void dispose() {
    for (final img in _ownedImages) {
      img.dispose();
    }
    _ownedImages.clear();
    _hitFlashSprites.clear();
    enemyAnimations.clear();
    itemAnimations.clear();
    playerAnimations = null;
    bossAnimations = null;
    groundShadowSprite = null;
    playerDashGhostSprite = null;
    bossHitFlashSprite = null;
    bossChargeTintSprite = null;
  }
}
