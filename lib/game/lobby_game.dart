import 'dart:async';
import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../models/player_class.dart';
import '../services/audio_settings_service.dart';

/// Mục tiêu tương tác gần người chơi trong sảnh chờ
class LobbyInteractionTarget {
  final bool isPortal;
  final PlayerClassInfo? hero;

  const LobbyInteractionTarget._({
    this.isPortal = false,
    this.hero,
  });

  static const LobbyInteractionTarget none = LobbyInteractionTarget._();
  static const LobbyInteractionTarget portal = LobbyInteractionTarget._(
    isPortal: true,
  );
  factory LobbyInteractionTarget.hero(PlayerClassInfo hero) =>
      LobbyInteractionTarget._(hero: hero);

  bool get hasTarget => isPortal || hero != null;
}

/// Nền phòng chờ HUIT Safe Room (1280 x 690)
class _LobbyBackgroundComponent extends PositionComponent
    with HasGameReference<LobbyGame> {
  Sprite? _bgSprite;
  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  _LobbyBackgroundComponent()
    : super(
        size: Vector2(LobbyGame.roomWidth, LobbyGame.roomHeight),
        priority: -10,
      );

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    final image = await game.images.load(GameConstants.lobbyFlameBgPath);
    _bgSprite = Sprite(image);
  }

  @override
  void render(Canvas canvas) {
    final sprite = _bgSprite;
    if (sprite != null) {
      sprite.render(canvas, size: size, overridePaint: _paint);
    } else {
      canvas.drawRect(size.toRect(), Paint()..color = GameConstants.cardColor);
    }
  }
}

/// Cổng dịch chuyển trên cùng chính giữa phòng chờ để mở bản đồ chọn màn (1-1, 1-2, 1-3...)
class _PortalGateComponent extends PositionComponent {
  double _time = 0;

  _PortalGateComponent({required super.position})
    : super(
        size: Vector2(120, 70),
        anchor: Anchor.center,
        priority: 4,
      );

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final pulse = 1.0 + math.sin(_time * 4.0) * 0.08;

    // Vòng phát sáng dưới chân cổng
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: 86 * pulse,
        height: 44 * pulse,
      ),
      Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.24),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: 86 * pulse,
        height: 44 * pulse,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..color = const Color(0xFF64FFDA).withValues(alpha: 0.9),
    );

    // Nhãn chỉ dẫn cổng
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'CỔNG VÀO MÀN',
        style: TextStyle(
          color: Color(0xFF80FFE8),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, -16),
    );
  }
}

/// Bục đồng đội đứng sẵn trong sảnh để người chơi đi tới và đổi nhân vật
class _HeroSpotComponent extends PositionComponent
    with HasGameReference<LobbyGame> {
  final PlayerClassInfo heroInfo;
  SpriteComponent? _spriteComponent;
  double _time = 0;
  bool isHighlighted = false;

  _HeroSpotComponent({
    required this.heroInfo,
    required super.position,
  }) : super(
         size: Vector2.all(52),
         anchor: Anchor.center,
         priority: 8,
       );

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    final image = await game.images.load(heroInfo.flameSpritePath);
    _spriteComponent = SpriteComponent(
      sprite: Sprite(image),
      size: Vector2.all(GameConstants.playerSize),
      anchor: Anchor.center,
      position: size / 2,
      paint: Paint()..filterQuality = FilterQuality.none,
    );
    add(_spriteComponent!);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    final isCurrentlyPlayed = game.selectedClass.type == heroInfo.type;
    if (_spriteComponent != null) {
      // Ẩn sprite ở bục nếu người chơi đang điều khiển chính nhân vật đó
      _spriteComponent!.opacity = isCurrentlyPlayed ? 0.0 : 1.0;
      _spriteComponent!.position.y = (size.y / 2) + math.sin(_time * 3.0) * 2.0;
    }
  }

  @override
  void render(Canvas canvas) {
    final isCurrentlyPlayed = game.selectedClass.type == heroInfo.type;
    final center = Offset(size.x / 2, size.y / 2);

    // Vòng tròn vị trí trên sàn
    canvas.drawCircle(
      Offset(center.dx, center.dy + 12),
      26,
      Paint()
        ..color = isHighlighted
            ? heroInfo.themeColor.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.30),
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy + 12),
      26,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 2.6 : 1.5
        ..color = isCurrentlyPlayed
            ? Colors.white24
            : heroInfo.themeColor.withValues(alpha: isHighlighted ? 0.95 : 0.6),
    );

    if (!isCurrentlyPlayed) {
      final labelText = isHighlighted
          ? 'ĐỔI: ${heroInfo.name}'
          : heroInfo.name;
      final tp = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            color: isHighlighted ? heroInfo.themeColor : Colors.white70,
            fontSize: isHighlighted ? 11.5 : 10,
            fontWeight: FontWeight.w800,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(center.dx - tp.width / 2, -14));
    }
  }
}

/// Nhân vật người chơi tự do di chuyển trong sảnh chờ
class LobbyPlayerComponent extends PositionComponent
    with HasGameReference<LobbyGame> {
  SpriteComponent? _bodySprite;
  SpriteComponent? _weaponSprite;
  final Vector2 _moveDir = Vector2.zero();
  Vector2 _facingDir = Vector2(1, 0);
  double _dashTimer = 0;

  LobbyPlayerComponent({required super.position})
    : super(
        size: Vector2.all(GameConstants.playerSize),
        anchor: Anchor.center,
        priority: 10,
      );

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();
    await reloadAppearance(game.selectedClass);
  }

  Future<void> reloadAppearance(PlayerClassInfo hero) async {
    final playerImage = await game.images.load(hero.flameSpritePath);
    final weaponImage = await game.images.load(hero.primaryWeapon.flamePath);

    if (_bodySprite == null) {
      _bodySprite = SpriteComponent(
        sprite: Sprite(playerImage),
        size: size,
        anchor: Anchor.center,
        position: size / 2,
        paint: Paint()..filterQuality = FilterQuality.none,
      );
      add(_bodySprite!);
    } else {
      _bodySprite!.sprite = Sprite(playerImage);
    }

    if (_weaponSprite == null) {
      _weaponSprite = SpriteComponent(
        sprite: Sprite(weaponImage),
        size: Vector2.all(GameConstants.weaponSize),
        anchor: Anchor.center,
        position: Vector2(size.x * 0.85, size.y * 0.56),
        paint: Paint()..filterQuality = FilterQuality.none,
        priority: 11,
      );
      add(_weaponSprite!);
    } else {
      _weaponSprite!.sprite = Sprite(weaponImage);
    }
  }

  void setMoveDirection(Vector2 dir) {
    if (dir.length2 > 1.0) {
      _moveDir.setFrom(dir.normalized());
    } else {
      _moveDir.setFrom(dir);
    }
    if (_moveDir.length2 > 0.02) {
      _facingDir = _moveDir.normalized();
    }
  }

  void triggerQuickStepDash() {
    if (_dashTimer <= 0) {
      _dashTimer = 0.18;
      AudioSettingsService.instance.playDash();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 3),
        width: size.x * 0.65,
        height: 10,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    final speed = game.selectedClass.moveSpeed * 1.15;
    if (_dashTimer > 0) {
      _dashTimer -= dt;
      position.add(_facingDir * speed * 2.6 * dt);
    } else if (_moveDir.length2 > 0.001) {
      position.add(_moveDir * speed * dt);
    }

    // Giới hạn đi trong sàn phòng chờ an toàn
    position.x = position.x.clamp(95.0, LobbyGame.roomWidth - 95.0);
    position.y = position.y.clamp(210.0, LobbyGame.roomHeight - 64.0);

    if (_bodySprite != null && _facingDir.x.abs() > 0.05) {
      final flipX = _facingDir.x < 0 ? -1.0 : 1.0;
      if (_bodySprite!.scale.x != flipX) {
        _bodySprite!.scale.x = flipX;
      }
    }
    if (_weaponSprite != null) {
      final aimAngle = math.atan2(_facingDir.y, _facingDir.x);
      _weaponSprite!.position.setValues(
        size.x / 2 + _facingDir.x * 19.0,
        size.y / 2 + _facingDir.y * 19.0,
      );
      _weaponSprite!.angle = aimAngle;
      final weaponFlipY = _facingDir.x < 0 ? -1.0 : 1.0;
      if (_weaponSprite!.scale.y != weaponFlipY) {
        _weaponSprite!.scale.y = weaponFlipY;
      }
    }
  }
}

/// Thế giới Sảnh chờ tương tác (di chuyển tới chỗ đổi nhân vật & đi vào cổng chọn màn)
class LobbyGame extends FlameGame with KeyboardEvents {
  static const double roomWidth = 1280.0;
  static const double roomHeight = 690.0;

  static final Vector2 portalPosition = Vector2(640.0, 222.0);
  static final Map<PlayerClassType, Vector2> heroSpotPositions = {
    PlayerClassType.it: Vector2(465.0, 415.0),
    PlayerClassType.food: Vector2(285.0, 515.0),
    PlayerClassType.eco: Vector2(965.0, 455.0),
  };

  PlayerClassInfo selectedClass;
  final VoidCallback? onPortalEntered;

  final ValueNotifier<LobbyInteractionTarget> nearbyInteractionNotifier =
      ValueNotifier(LobbyInteractionTarget.none);
  late final ValueNotifier<PlayerClassInfo> selectedClassNotifier;

  LobbyPlayerComponent? _player;
  LobbyPlayerComponent? get lobbyPlayer => _player;

  final List<_HeroSpotComponent> _heroSpots = [];
  bool _portalLockUntilExit = false;

  final Set<LogicalKeyboardKey> _pressedKeys = {};
  final Vector2 _keyboardDir = Vector2.zero();

  LobbyGame({
    PlayerClassInfo? initialClass,
    this.onPortalEntered,
  }) : selectedClass = initialClass ?? PlayerClassInfo.availableClasses.first {
    selectedClassNotifier = ValueNotifier(selectedClass);
  }

  @override
  Color backgroundColor() => GameConstants.backgroundColor;

  @override
  FutureOr<void> onLoad() async {
    await super.onLoad();

    await images.loadAll([
      GameConstants.lobbyFlameBgPath,
      for (final h in PlayerClassInfo.availableClasses) h.flameSpritePath,
      for (final h in PlayerClassInfo.availableClasses)
        h.primaryWeapon.flamePath,
    ]);

    world.add(_LobbyBackgroundComponent());
    world.add(_PortalGateComponent(position: portalPosition));

    for (final hero in PlayerClassInfo.availableClasses) {
      final pos = heroSpotPositions[hero.type] ?? Vector2(400, 450);
      final spot = _HeroSpotComponent(heroInfo: hero, position: pos);
      _heroSpots.add(spot);
      world.add(spot);
    }

    final playerComp = LobbyPlayerComponent(position: Vector2(640.0, 440.0));
    _player = playerComp;
    world.add(playerComp);

    camera.viewfinder.anchor = Anchor.center;
    _updateCameraFit();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _updateCameraFit();
  }

  void _updateCameraFit() {
    if (size.x <= 0 || size.y <= 0) {
      return;
    }
    // Zoom vừa đủ để không bao giờ lộ viền đen ngoài ảnh sảnh chờ
    final zoomX = size.x / roomWidth;
    final zoomY = size.y / roomHeight;
    final desiredZoom = math.max(math.max(zoomX, zoomY), 1.05);
    camera.viewfinder.zoom = desiredZoom;
    _clampCameraToPlayer();
  }

  void _clampCameraToPlayer() {
    final activePlayer = _player;
    final target = activePlayer?.position ?? Vector2(640, 380);
    final zoom = camera.viewfinder.zoom;
    if (size.x <= 0 || size.y <= 0 || zoom <= 0) {
      camera.viewfinder.position = target;
      return;
    }
    final halfViewW = (size.x / zoom) / 2;
    final halfViewH = (size.y / zoom) / 2;
    final minX = math.min(halfViewW, roomWidth / 2);
    final maxX = math.max(roomWidth - halfViewW, roomWidth / 2);
    final minY = math.min(halfViewH, roomHeight / 2);
    final maxY = math.max(roomHeight - halfViewH, roomHeight / 2);

    camera.viewfinder.position = Vector2(
      target.x.clamp(minX, maxX),
      target.y.clamp(minY, maxY),
    );
  }

  void setMoveDirection(Vector2 direction) {
    _player?.setMoveDirection(direction);
  }

  /// Tương tác với đối tượng gần nhất (Đổi nhân vật hoặc Vào cổng; nếu không đứng cạnh ai thì lướt nhẹ)
  void interactOrStep() {
    final target = nearbyInteractionNotifier.value;
    if (target.isPortal) {
      AudioSettingsService.instance.playUiClick();
      onPortalEntered?.call();
    } else if (target.hero != null) {
      selectHero(target.hero!);
    } else {
      _player?.triggerQuickStepDash();
    }
  }

  Future<void> selectHero(PlayerClassInfo hero) async {
    if (selectedClass.type == hero.type) {
      return;
    }
    selectedClass = hero;
    selectedClassNotifier.value = hero;
    AudioSettingsService.instance.playUiClick();
    await _player?.reloadAppearance(hero);
  }

  /// Đặt lại khóa kích hoạt cổng sau khi người chơi đóng bản đồ chọn màn
  void clearPortalTriggerCooldown() {
    _portalLockUntilExit = true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final activePlayer = _player;
    if (activePlayer == null || !activePlayer.isMounted) {
      return;
    }

    _clampCameraToPlayer();

    // Kiểm tra khoảng cách tới cổng dịch chuyển
    final distToPortal = activePlayer.position.distanceTo(portalPosition);
    if (distToPortal > 68.0) {
      _portalLockUntilExit = false;
    }

    LobbyInteractionTarget nextTarget = LobbyInteractionTarget.none;

    if (distToPortal <= 88.0) {
      nextTarget = LobbyInteractionTarget.portal;
      // Bước thẳng vào lõi cổng sẽ tự động mở bản đồ chọn màn 1-1, 1-2, 1-3...
      if (distToPortal <= 44.0 && !_portalLockUntilExit) {
        _portalLockUntilExit = true;
        onPortalEntered?.call();
      }
    }

    // Kiểm tra đồng đội gần nhất để đổi nhân vật
    for (final spot in _heroSpots) {
      final isOtherHero = spot.heroInfo.type != selectedClass.type;
      final near =
          isOtherHero && activePlayer.position.distanceTo(spot.position) <= 78.0;
      spot.isHighlighted = near;
      if (near && !nextTarget.isPortal) {
        nextTarget = LobbyInteractionTarget.hero(spot.heroInfo);
      }
    }

    final current = nearbyInteractionNotifier.value;
    if (current.isPortal != nextTarget.isPortal ||
        current.hero?.type != nextTarget.hero?.type) {
      nearbyInteractionNotifier.value = nextTarget;
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final key = event.logicalKey;
    final isMove =
        key == LogicalKeyboardKey.keyW ||
        key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;

    if (isMove) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _pressedKeys.add(key);
      } else if (event is KeyUpEvent) {
        _pressedKeys.remove(key);
      }
      double dx = 0;
      double dy = 0;
      if (_pressedKeys.contains(LogicalKeyboardKey.keyA) ||
          _pressedKeys.contains(LogicalKeyboardKey.arrowLeft)) {
        dx -= 1;
      }
      if (_pressedKeys.contains(LogicalKeyboardKey.keyD) ||
          _pressedKeys.contains(LogicalKeyboardKey.arrowRight)) {
        dx += 1;
      }
      if (_pressedKeys.contains(LogicalKeyboardKey.keyW) ||
          _pressedKeys.contains(LogicalKeyboardKey.arrowUp)) {
        dy -= 1;
      }
      if (_pressedKeys.contains(LogicalKeyboardKey.keyS) ||
          _pressedKeys.contains(LogicalKeyboardKey.arrowDown)) {
        dy += 1;
      }
      _keyboardDir.setValues(dx, dy);
      setMoveDirection(_keyboardDir);
    }

    if ((key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyE) &&
        event is KeyDownEvent) {
      interactOrStep();
    }
    return KeyEventResult.handled;
  }

  @override
  void onRemove() {
    nearbyInteractionNotifier.dispose();
    selectedClassNotifier.dispose();
    super.onRemove();
  }
}
