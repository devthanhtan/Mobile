import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../game/huit_game.dart';

class _VfxParticle {
  bool active = false;
  bool isBubble = false;
  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;
  double life = 0;
  double maxLife = 0.25;
  double size = 4.0;
  Color color = GameConstants.pixelWhite;
}

class _DamagePopup {
  bool active = false;
  double x = 0;
  double y = 0;
  double vy = -44.0;
  double life = 0;
  TextPainter? painter;
  double halfWidth = 0;
}

class _MuzzleFlash {
  bool active = false;
  double x = 0;
  double y = 0;
  double radius = 7.0;
  double life = 0;
  static const double maxLife = 0.065;
  Color color = GameConstants.pixelCyan;
}

class _LaserBeamEffect {
  bool active = false;
  double startX = 0;
  double startY = 0;
  double endX = 0;
  double endY = 0;
  double life = 0;
  static const double maxLife = 0.22;
  Color coreColor = GameConstants.pixelWhite;
  Color glowColor = GameConstants.pixelCyan;
}

class _MeleeSlashArc {
  bool active = false;
  double x = 0;
  double y = 0;
  double centerAngle = 0;
  double sweepRadians = 2.2;
  double radius = 92.0;
  double life = 0;
  static const double maxLife = 0.20;
  Color primaryColor = GameConstants.pixelGold;
  Color secondaryColor = GameConstants.pixelWhite;
}

/// Lớp quản lý Object Pool cho toàn bộ hiệu ứng chiến đấu & 5 vũ khí:
/// - Hạt vuông pixel & bong bóng trà sữa (_particles)
/// - Số sát thương bay lên với TextPainter cache (_damagePopups)
/// - Muzzle flash 2 frame ở đầu súng/bút (_muzzleFlashes)
/// - Tia laser Laptop 4 frame + quả cầu tụ lực 0.4s (_laserBeams)
/// - Vệt vung Giáo trình cận chiến 4 frame cung tròn (_meleeSlashes)
/// Tất cả đều dùng mảng cố định & Paint cache, 0 cấp phát đối tượng trong update/render.
class CombatVfxLayerComponent extends PositionComponent
    with HasGameReference<HuitDeadlineGame> {
  final List<_VfxParticle> _particles = List.generate(
    GameConstants.maxActiveParticles,
    (_) => _VfxParticle(),
  );
  final List<_DamagePopup> _damagePopups = List.generate(
    GameConstants.maxActiveDamageNumbers,
    (_) => _DamagePopup(),
  );
  final List<_MuzzleFlash> _muzzleFlashes = List.generate(
    8,
    (_) => _MuzzleFlash(),
  );
  final List<_LaserBeamEffect> _laserBeams = List.generate(
    4,
    (_) => _LaserBeamEffect(),
  );
  final List<_MeleeSlashArc> _meleeSlashes = List.generate(
    4,
    (_) => _MeleeSlashArc(),
  );

  // Quả cầu tụ lực Laptop 0.4s (chỉ 1 người chơi nên tái sử dụng trực tiếp)
  bool _chargeOrbActive = false;
  double _chargeOrbX = 0;
  double _chargeOrbY = 0;
  double _chargeOrbProgress = 0;
  Color _chargeOrbColor = GameConstants.pixelCyan;

  final Map<int, TextPainter> _damagePainterCache = {};
  static const int _maxCachedPainters = 64;

  final math.Random _rng = math.Random();

  // Toàn bộ Paint dùng lại, tuyệt đối không tạo mới trong render()
  final Paint _particlePaint = Paint()..style = PaintingStyle.fill;
  final Paint _particleOutlinePaint = Paint()
    ..color = GameConstants.pixelInk
    ..style = PaintingStyle.fill;
  final Paint _bubbleStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;
  final Paint _muzzleOuterPaint = Paint()..style = PaintingStyle.fill;
  final Paint _muzzleCorePaint = Paint()
    ..color = GameConstants.pixelWhite
    ..style = PaintingStyle.fill;
  final Paint _laserGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _laserMidPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _laserCorePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _slashOuterPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.square;
  final Paint _slashInnerPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.square;

  int _particleCursor = 0;
  int _popupCursor = 0;
  int _muzzleCursor = 0;
  int _laserCursor = 0;
  int _slashCursor = 0;

  int activeParticleCount = 0;
  int activePopupCount = 0;
  int _activeMuzzleCount = 0;
  int _activeLaserCount = 0;
  int _activeSlashCount = 0;

  CombatVfxLayerComponent() : super(priority: 16);

  TextPainter _getOrCreateDamagePainter(int amount, Color color) {
    final key = (amount * 31) ^ color.toARGB32();
    final existing = _damagePainterCache[key];
    if (existing != null) {
      return existing;
    }

    if (_damagePainterCache.length >= _maxCachedPainters) {
      final oldestKey = _damagePainterCache.keys.first;
      _damagePainterCache.remove(oldestKey)?.dispose();
    }

    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      text: TextSpan(
        text: '$amount',
        style: TextStyle(
          fontFamily: GameConstants.pixelFontFamily,
          fontSize: 11.0,
          fontWeight: FontWeight.w900,
          color: color,
          shadows: const [
            Shadow(
              color: GameConstants.pixelInk,
              offset: Offset(1, 1),
              blurRadius: 0,
            ),
          ],
        ),
      ),
    )..layout();

    _damagePainterCache[key] = tp;
    return tp;
  }

  /// Sinh hạt vuông pixel hoặc bong bóng trà sữa (isBubble = true) từ pool
  void spawnParticles({
    required double x,
    required double y,
    required Color color,
    int count = 4,
    double speed = 110.0,
    double size = 4.0,
    double life = 0.24,
    bool isBubble = false,
  }) {
    for (int i = 0; i < count; i++) {
      final p = _particles[_particleCursor];
      _particleCursor = (_particleCursor + 1) % _particles.length;
      if (!p.active) {
        activeParticleCount++;
      }
      final angle = _rng.nextDouble() * math.pi * 2;
      final spd = speed * (0.45 + _rng.nextDouble() * 0.75);
      p.active = true;
      p.isBubble = isBubble;
      p.x = x;
      p.y = y;
      p.vx = math.cos(angle) * spd;
      p.vy = math.sin(angle) * spd - (isBubble ? 24.0 : 0.0);
      p.life = life * (0.75 + _rng.nextDouble() * 0.4);
      p.maxLife = p.life;
      p.size = size;
      p.color = color;
    }
  }

  /// Sinh muzzle flash nhỏ ở đầu vũ khí từ pool
  void spawnMuzzleFlash({
    required double x,
    required double y,
    required Color color,
    double radius = 7.0,
  }) {
    final m = _muzzleFlashes[_muzzleCursor];
    _muzzleCursor = (_muzzleCursor + 1) % _muzzleFlashes.length;
    if (!m.active) {
      _activeMuzzleCount++;
    }
    m.active = true;
    m.x = x;
    m.y = y;
    m.radius = radius;
    m.color = color;
    m.life = _MuzzleFlash.maxLife;
  }

  /// Cập nhật quả cầu năng lượng khi giữ nút nạp Laptop 0.4s
  void updateChargingOrb({
    required double x,
    required double y,
    required double progress,
    required Color color,
  }) {
    _chargeOrbActive = true;
    _chargeOrbX = x;
    _chargeOrbY = y;
    _chargeOrbProgress = progress.clamp(0.0, 1.0);
    _chargeOrbColor = color;
  }

  /// Sinh tia laser Laptop xuyên thấu có animation glow kéo dài từ pool
  void spawnLaserBeam({
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    required Color coreColor,
    required Color glowColor,
  }) {
    _chargeOrbActive = false;
    final b = _laserBeams[_laserCursor];
    _laserCursor = (_laserCursor + 1) % _laserBeams.length;
    if (!b.active) {
      _activeLaserCount++;
    }
    b.active = true;
    b.startX = startX;
    b.startY = startY;
    b.endX = endX;
    b.endY = endY;
    b.coreColor = coreColor;
    b.glowColor = glowColor;
    b.life = _LaserBeamEffect.maxLife;
  }

  /// Sinh hoạt ảnh vung Giáo trình cận chiến 4 frame theo cung tròn từ pool
  void spawnMeleeSlashArc({
    required double x,
    required double y,
    required double centerAngle,
    required double sweepRadians,
    required double radius,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    final s = _meleeSlashes[_slashCursor];
    _slashCursor = (_slashCursor + 1) % _meleeSlashes.length;
    if (!s.active) {
      _activeSlashCount++;
    }
    s.active = true;
    s.x = x;
    s.y = y;
    s.centerAngle = centerAngle;
    s.sweepRadians = sweepRadians;
    s.radius = radius;
    s.primaryColor = primaryColor;
    s.secondaryColor = secondaryColor;
    s.life = _MeleeSlashArc.maxLife;
  }

  /// Sinh số sát thương từ pool dùng lại TextPainter đã cache
  void spawnDamageNumber({
    required double x,
    required double y,
    required int amount,
    Color color = GameConstants.pixelWhite,
  }) {
    final d = _damagePopups[_popupCursor];
    _popupCursor = (_popupCursor + 1) % _damagePopups.length;
    if (!d.active) {
      activePopupCount++;
    }
    final tp = _getOrCreateDamagePainter(amount, color);
    d.active = true;
    d.x = x + (_rng.nextDouble() * 14.0 - 7.0);
    d.y = y - 16.0;
    d.vy = -48.0;
    d.life = 0.42;
    d.painter = tp;
    d.halfWidth = tp.width * 0.5;
  }

  void clearAll() {
    for (int i = 0; i < _particles.length; i++) {
      _particles[i].active = false;
    }
    for (int i = 0; i < _damagePopups.length; i++) {
      _damagePopups[i].active = false;
      _damagePopups[i].painter = null;
    }
    for (int i = 0; i < _muzzleFlashes.length; i++) {
      _muzzleFlashes[i].active = false;
    }
    for (int i = 0; i < _laserBeams.length; i++) {
      _laserBeams[i].active = false;
    }
    for (int i = 0; i < _meleeSlashes.length; i++) {
      _meleeSlashes[i].active = false;
    }
    _chargeOrbActive = false;
    activeParticleCount = 0;
    activePopupCount = 0;
    _activeMuzzleCount = 0;
    _activeLaserCount = 0;
    _activeSlashCount = 0;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isVictory) {
      return;
    }

    // Tự tắt quả cầu tụ lực nếu frame này người chơi không còn giữ nạp
    if (_chargeOrbActive && (game.player?.weaponChargeTimer ?? 0.0) <= 0.0) {
      _chargeOrbActive = false;
    }

    if (activeParticleCount > 0) {
      final drag = math.pow(0.08, dt).toDouble();
      for (int i = 0; i < _particles.length; i++) {
        final p = _particles[i];
        if (!p.active) {
          continue;
        }
        p.life -= dt;
        if (p.life <= 0) {
          p.active = false;
          activeParticleCount--;
          continue;
        }
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.vx *= drag;
        p.vy *= drag;
      }
    }

    if (_activeMuzzleCount > 0) {
      for (int i = 0; i < _muzzleFlashes.length; i++) {
        final m = _muzzleFlashes[i];
        if (!m.active) {
          continue;
        }
        m.life -= dt;
        if (m.life <= 0) {
          m.active = false;
          _activeMuzzleCount--;
        }
      }
    }

    if (_activeLaserCount > 0) {
      for (int i = 0; i < _laserBeams.length; i++) {
        final b = _laserBeams[i];
        if (!b.active) {
          continue;
        }
        b.life -= dt;
        if (b.life <= 0) {
          b.active = false;
          _activeLaserCount--;
        }
      }
    }

    if (_activeSlashCount > 0) {
      for (int i = 0; i < _meleeSlashes.length; i++) {
        final s = _meleeSlashes[i];
        if (!s.active) {
          continue;
        }
        s.life -= dt;
        if (s.life <= 0) {
          s.active = false;
          _activeSlashCount--;
        }
      }
    }

    if (activePopupCount > 0) {
      for (int i = 0; i < _damagePopups.length; i++) {
        final d = _damagePopups[i];
        if (!d.active) {
          continue;
        }
        d.life -= dt;
        if (d.life <= 0) {
          d.active = false;
          d.painter = null;
          activePopupCount--;
          continue;
        }
        d.y += d.vy * dt;
        d.vy *= 0.92;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // 1. Quả cầu nạp năng lượng Laptop 0.4s
    if (_chargeOrbActive) {
      final r = 4.0 + _chargeOrbProgress * 8.0;
      _muzzleOuterPaint.color = _chargeOrbColor.withValues(alpha: 0.42);
      canvas.drawCircle(Offset(_chargeOrbX, _chargeOrbY), r * 1.4, _muzzleOuterPaint);
      _muzzleOuterPaint.color = _chargeOrbColor;
      canvas.drawCircle(Offset(_chargeOrbX, _chargeOrbY), r, _muzzleOuterPaint);
      canvas.drawCircle(Offset(_chargeOrbX, _chargeOrbY), r * 0.45, _muzzleCorePaint);
    }

    // 2. Tia laser Laptop 4 frame (glow ngoài + thân giữa + lõi trắng)
    if (_activeLaserCount > 0) {
      for (int i = 0; i < _laserBeams.length; i++) {
        final b = _laserBeams[i];
        if (!b.active) {
          continue;
        }
        final t = (b.life / _LaserBeamEffect.maxLife).clamp(0.0, 1.0);
        // 4 bước hoạt ảnh bề rộng tia laser
        final frameStep = ((1.0 - t) * 4).floor().clamp(0, 3);
        final pulse = (frameStep == 0 || frameStep == 1) ? 1.2 : 0.85 * t;
        final p1 = Offset(b.startX, b.startY);
        final p2 = Offset(b.endX, b.endY);

        _laserGlowPaint
          ..strokeWidth = 20.0 * pulse
          ..color = b.glowColor.withValues(alpha: 0.28 * t);
        canvas.drawLine(p1, p2, _laserGlowPaint);

        _laserMidPaint
          ..strokeWidth = 10.0 * pulse
          ..color = b.glowColor.withValues(alpha: 0.85 * t);
        canvas.drawLine(p1, p2, _laserMidPaint);

        _laserCorePaint
          ..strokeWidth = 4.5 * pulse
          ..color = b.coreColor.withValues(alpha: t);
        canvas.drawLine(p1, p2, _laserCorePaint);
      }
    }

    // 3. Hoạt ảnh vung Giáo trình cận chiến 4 frame + vệt quét cung tròn
    if (_activeSlashCount > 0) {
      for (int i = 0; i < _meleeSlashes.length; i++) {
        final s = _meleeSlashes[i];
        if (!s.active) {
          continue;
        }
        if (!game.isVisibleInCamera(s.x, s.y, s.radius, s.radius)) {
          continue;
        }
        final progress = (1.0 - s.life / _MeleeSlashArc.maxLife).clamp(0.0, 1.0);
        // Chia rõ 4 frame vung cung tròn
        final frameIdx = (progress * 4).floor().clamp(0, 3);
        final qProgress = (frameIdx + 1) / 4.0;
        final alpha = (1.0 - progress * 0.7).clamp(0.0, 1.0);

        final startAngle =
            s.centerAngle - s.sweepRadians * 0.5 + (qProgress - 0.5) * 0.35;
        final arcSweep = s.sweepRadians * (0.55 + 0.45 * (1.0 - progress * 0.4));
        final rectOuter = Rect.fromCircle(
          center: Offset(s.x, s.y),
          radius: s.radius * 0.86,
        );
        final rectInner = Rect.fromCircle(
          center: Offset(s.x, s.y),
          radius: s.radius * 0.68,
        );

        _slashOuterPaint
          ..strokeWidth = 14.0
          ..color = s.primaryColor.withValues(alpha: 0.78 * alpha);
        canvas.drawArc(rectOuter, startAngle, arcSweep, false, _slashOuterPaint);

        _slashInnerPaint
          ..strokeWidth = 6.0
          ..color = s.secondaryColor.withValues(alpha: 0.92 * alpha);
        canvas.drawArc(rectInner, startAngle + 0.08, arcSweep * 0.85, false, _slashInnerPaint);
      }
    }

    // 4. Muzzle flash 2 frame ở đầu vũ khí
    if (_activeMuzzleCount > 0) {
      for (int i = 0; i < _muzzleFlashes.length; i++) {
        final m = _muzzleFlashes[i];
        if (!m.active) {
          continue;
        }
        if (!game.isVisibleInCamera(m.x, m.y, m.radius * 2, m.radius * 2)) {
          continue;
        }
        final isFirstFrame = m.life > _MuzzleFlash.maxLife * 0.5;
        final r = isFirstFrame ? m.radius : m.radius * 0.65;
        _muzzleOuterPaint.color = m.color.withValues(alpha: 0.85);
        canvas.drawRect(
          Rect.fromCenter(center: Offset(m.x, m.y), width: r * 2.2, height: r * 0.7),
          _muzzleOuterPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset(m.x, m.y), width: r * 0.7, height: r * 2.2),
          _muzzleOuterPaint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset(m.x, m.y), width: r * 0.7, height: r * 0.7),
          _muzzleCorePaint,
        );
      }
    }

    // 5. Hạt vuông pixel & bong bóng trà sữa
    if (activeParticleCount > 0) {
      for (int i = 0; i < _particles.length; i++) {
        final p = _particles[i];
        if (!p.active) {
          continue;
        }
        if (!game.isVisibleInCamera(p.x, p.y, p.size * 2, p.size * 2)) {
          continue;
        }
        final t = (p.life / p.maxLife).clamp(0.0, 1.0);
        if (p.isBubble) {
          final radius = p.size * (1.35 - 0.45 * t);
          _bubbleStrokePaint.color = p.color.withValues(alpha: t);
          canvas.drawCircle(Offset(p.x, p.y), radius, _bubbleStrokePaint);
          canvas.drawRect(
            Rect.fromLTWH(p.x - radius * 0.4, p.y - radius * 0.4, 2.0, 2.0),
            _muzzleCorePaint,
          );
        } else {
          final s = p.size * (0.5 + 0.5 * t);
          final half = s * 0.5;
          canvas.drawRect(
            Rect.fromLTWH(p.x - half - 1, p.y - half - 1, s + 2, s + 2),
            _particleOutlinePaint,
          );
          _particlePaint.color = p.color.withValues(alpha: t);
          canvas.drawRect(
            Rect.fromLTWH(p.x - half, p.y - half, s, s),
            _particlePaint,
          );
        }
      }
    }

    // 6. Số sát thương bay lên
    if (activePopupCount > 0) {
      for (int i = 0; i < _damagePopups.length; i++) {
        final d = _damagePopups[i];
        final tp = d.painter;
        if (!d.active || tp == null) {
          continue;
        }
        if (!game.isVisibleInCamera(d.x, d.y, 24, 16)) {
          continue;
        }
        tp.paint(canvas, Offset(d.x - d.halfWidth, d.y));
      }
    }
  }

  @override
  void onRemove() {
    for (final tp in _damagePainterCache.values) {
      tp.dispose();
    }
    _damagePainterCache.clear();
    super.onRemove();
  }
}
