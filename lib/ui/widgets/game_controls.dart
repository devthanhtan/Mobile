import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../constants.dart';

/// Joystick ảo đa điểm tối giản kiểu Soul Knight (góc dưới bên trái)
class VirtualJoystick extends StatefulWidget {
  final ValueChanged<Vector2> onDirectionChanged;
  final double size;
  final double knobRadius;

  const VirtualJoystick({
    super.key,
    required this.onDirectionChanged,
    this.size = GameConstants.hudJoystickSize,
    this.knobRadius = GameConstants.hudJoystickKnobRadius,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _knobOffset = Offset.zero;
  int? _activePointerId;
  final Vector2 _dirScratch = Vector2.zero();

  double get _baseRadius => widget.size / 2;
  double get _maxTravel => _baseRadius - widget.knobRadius;

  void _updateFromLocalPosition(Offset localPosition) {
    final center = Offset(_baseRadius, _baseRadius);
    final delta = localPosition - center;
    final distance = delta.distance;

    final Offset clampedOffset;
    if (distance > _maxTravel && distance > 0) {
      clampedOffset = delta * (_maxTravel / distance);
    } else {
      clampedOffset = delta;
    }

    setState(() {
      _knobOffset = clampedOffset;
    });

    if (_maxTravel > 0) {
      final normX = (clampedOffset.dx / _maxTravel).clamp(-1.0, 1.0);
      final normY = (clampedOffset.dy / _maxTravel).clamp(-1.0, 1.0);
      _dirScratch.setValues(normX, normY);
      if (_dirScratch.length2 < 0.08 * 0.08) {
        widget.onDirectionChanged(Vector2.zero());
      } else {
        widget.onDirectionChanged(_dirScratch);
      }
    }
  }

  void _resetJoystick() {
    if (!mounted) {
      return;
    }
    setState(() {
      _activePointerId = null;
      _knobOffset = Offset.zero;
    });
    widget.onDirectionChanged(Vector2.zero());
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _activePointerId != null;

    return Semantics(
      label: 'Joystick di chuyển nhân vật',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (_activePointerId == null) {
            _activePointerId = event.pointer;
            _updateFromLocalPosition(event.localPosition);
          }
        },
        onPointerMove: (event) {
          if (_activePointerId == event.pointer) {
            _updateFromLocalPosition(event.localPosition);
          }
        },
        onPointerUp: (event) {
          if (_activePointerId == event.pointer) {
            _resetJoystick();
          }
        },
        onPointerCancel: (event) {
          if (_activePointerId == event.pointer) {
            _resetJoystick();
          }
        },
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GameConstants.pixelInk.withValues(
                    alpha: isActive ? 0.56 : 0.42,
                  ),
                  border: Border.all(
                    color: isActive
                        ? GameConstants.pixelCyan.withValues(alpha: 0.78)
                        : GameConstants.cardBorderColor.withValues(alpha: 0.85),
                    width: GameConstants.hudBorderWidth,
                  ),
                ),
              ),
              Transform.translate(
                offset: _knobOffset,
                child: Container(
                  width: widget.knobRadius * 2,
                  height: widget.knobRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GameConstants.pixelWhite.withValues(
                      alpha: isActive ? 0.92 : 0.78,
                    ),
                    border: Border.all(
                      color: GameConstants.pixelInk,
                      width: GameConstants.hudBorderWidth,
                    ),
                    boxShadow: GameConstants.hudPixelShadow,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút Bắn tâm ngắm tròn lớn (hỗ trợ nhấn giữ bắn và kéo nhẹ để chỉnh hướng)
class ShootButton extends StatefulWidget {
  final ValueChanged<bool> onShootingChanged;
  final ValueChanged<Vector2?> onAimChanged;
  final double size;

  const ShootButton({
    super.key,
    required this.onShootingChanged,
    required this.onAimChanged,
    this.size = GameConstants.hudShootButtonSize,
  });

  @override
  State<ShootButton> createState() => _ShootButtonState();
}

class _ShootButtonState extends State<ShootButton> {
  int? _activePointerId;
  Offset _aimDragOffset = Offset.zero;
  final Vector2 _aimScratch = Vector2.zero();

  double get _radius => widget.size / 2;

  void _updateAim(Offset localPosition) {
    final center = Offset(_radius, _radius);
    final delta = localPosition - center;
    final dist = delta.distance;

    if (dist > 10.0) {
      final maxVisual = _radius * 0.36;
      setState(() {
        _aimDragOffset = dist > maxVisual
            ? delta * (maxVisual / dist)
            : delta;
      });
      _aimScratch.setValues(delta.dx, delta.dy);
      _aimScratch.normalize();
      widget.onAimChanged(_aimScratch);
    } else {
      setState(() {
        _aimDragOffset = Offset.zero;
      });
      widget.onAimChanged(null);
    }
  }

  void _releaseShoot() {
    if (!mounted) {
      return;
    }
    setState(() {
      _activePointerId = null;
      _aimDragOffset = Offset.zero;
    });
    widget.onAimChanged(null);
    widget.onShootingChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final isPressed = _activePointerId != null;

    return Semantics(
      button: true,
      label: 'Nút bắn và ngắm hướng',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (_activePointerId == null) {
            _activePointerId = event.pointer;
            widget.onShootingChanged(true);
            _updateAim(event.localPosition);
          }
        },
        onPointerMove: (event) {
          if (_activePointerId == event.pointer) {
            _updateAim(event.localPosition);
          }
        },
        onPointerUp: (event) {
          if (_activePointerId == event.pointer) {
            _releaseShoot();
          }
        },
        onPointerCancel: (event) {
          if (_activePointerId == event.pointer) {
            _releaseShoot();
          }
        },
        child: AnimatedScale(
          scale: isPressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 70),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPressed
                  ? GameConstants.accentColor.withValues(alpha: 0.34)
                  : GameConstants.pixelInk.withValues(alpha: 0.62),
              border: Border.all(
                color: isPressed
                    ? GameConstants.hudGoldColor
                    : GameConstants.accentColor.withValues(alpha: 0.85),
                width: GameConstants.hudBorderWidth + 0.5,
              ),
              boxShadow: GameConstants.hudPixelShadow,
            ),
            child: Transform.translate(
              offset: _aimDragOffset * 0.45,
              child: CustomPaint(
                painter: _CrosshairReticlePainter(isActive: isPressed),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CrosshairReticlePainter extends CustomPainter {
  final bool isActive;

  static final Paint _activeStrokePaint = Paint()
    ..color = GameConstants.hudGoldColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.square;

  static final Paint _idleStrokePaint = Paint()
    ..color = GameConstants.pixelWhite.withValues(alpha: 0.86)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.square;

  static final Paint _centerDotPaint = Paint()
    ..color = GameConstants.hudGoldColor;

  const _CrosshairReticlePainter({required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final outerR = size.width * 0.25;
    final innerR = size.width * 0.11;
    final strokePaint = isActive ? _activeStrokePaint : _idleStrokePaint;

    canvas.drawCircle(center, outerR, strokePaint);
    canvas.drawCircle(center, innerR, strokePaint);

    final tickInner = outerR - 4.0;
    final tickOuter = outerR + 6.5;
    for (int i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final cosA = math.cos(a);
      final sinA = math.sin(a);
      canvas.drawLine(
        Offset(center.dx + cosA * tickInner, center.dy + sinA * tickInner),
        Offset(center.dx + cosA * tickOuter, center.dy + sinA * tickOuter),
        strokePaint,
      );
    }

    if (isActive) {
      canvas.drawCircle(center, 3.0, _centerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrosshairReticlePainter oldDelegate) =>
      oldDelegate.isActive != isActive;
}

/// Nút Lướt (Dash) tối ưu rebuild thấp:
/// - Khi truyền [cooldownListenable], phần quạt hồi chiêu vẽ bằng CustomPainter lắng nghe
///   trực tiếp Listenable (0 rebuild widget), còn số giây/trạng thái chỉ rebuild khi đổi giây nguyên (1 lần/giây).
/// - Giữ tương thích ngược với [cooldownRemaining] tĩnh cho unit/widget test.
class DashButton extends StatefulWidget {
  final VoidCallback onDash;
  final double cooldownRemaining;
  final ValueListenable<double>? cooldownListenable;
  final double cooldownTotal;
  final double size;

  const DashButton({
    super.key,
    required this.onDash,
    this.cooldownRemaining = 0.0,
    this.cooldownListenable,
    this.cooldownTotal = GameConstants.dashCooldownSeconds,
    this.size = GameConstants.hudDashButtonSize,
  });

  @override
  State<DashButton> createState() => _DashButtonState();
}

class _DashButtonState extends State<DashButton> {
  bool _isPressed = false;
  int _displayedSeconds = 0;

  double get _effectiveCooldown =>
      widget.cooldownListenable?.value ?? widget.cooldownRemaining;

  bool get _isReady => _effectiveCooldown <= 0.01;

  @override
  void initState() {
    super.initState();
    _displayedSeconds = _effectiveCooldown <= 0.01
        ? 0
        : _effectiveCooldown.ceil();
    widget.cooldownListenable?.addListener(_onCooldownTick);
  }

  @override
  void didUpdateWidget(covariant DashButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cooldownListenable != widget.cooldownListenable) {
      oldWidget.cooldownListenable?.removeListener(_onCooldownTick);
      widget.cooldownListenable?.addListener(_onCooldownTick);
    }
    _displayedSeconds = _effectiveCooldown <= 0.01
        ? 0
        : _effectiveCooldown.ceil();
  }

  void _onCooldownTick() {
    final cd = _effectiveCooldown;
    final nextSec = cd <= 0.01 ? 0 : cd.ceil();
    // Chỉ rebuild widget khi đổi giây hiển thị hoặc chuyển trạng thái sẵn sàng (1 lần/giây)
    if (nextSec != _displayedSeconds && mounted) {
      setState(() {
        _displayedSeconds = nextSec;
      });
    }
  }

  @override
  void dispose() {
    widget.cooldownListenable?.removeListener(_onCooldownTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _displayedSeconds == 0 && _isReady;

    return Semantics(
      button: true,
      label: 'Nút lướt Dash né đòn hồi chiêu 8 giây',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          setState(() => _isPressed = true);
          if (_isReady) {
            widget.onDash();
          }
        },
        onPointerUp: (_) {
          if (mounted) {
            setState(() => _isPressed = false);
          }
        },
        onPointerCancel: (_) {
          if (mounted) {
            setState(() => _isPressed = false);
          }
        },
        child: AnimatedScale(
          scale: _isPressed && isReady ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 70),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Nền tròn khung pixel
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isReady
                        ? GameConstants.pixelInk.withValues(alpha: 0.76)
                        : GameConstants.pixelShadowBlack.withValues(
                            alpha: 0.78,
                          ),
                    border: Border.all(
                      color: isReady
                          ? GameConstants.dashCyanColor
                          : GameConstants.pixelSlate.withValues(alpha: 0.65),
                      width: GameConstants.hudBorderWidth,
                    ),
                    boxShadow: GameConstants.hudPixelShadow,
                  ),
                ),
                // Biểu tượng tia sét cyan giống Soul Knight
                Icon(
                  Icons.bolt_rounded,
                  size: widget.size * 0.60,
                  color: isReady
                      ? GameConstants.dashCyanColor
                      : GameConstants.pixelSlate.withValues(alpha: 0.45),
                ),
                // Lớp phủ quạt đếm ngược vẽ trực tiếp bằng CustomPainter (không rebuild widget)
                if (!isReady)
                  Positioned.fill(
                    child: ClipOval(
                      child: CustomPaint(
                        painter: _CooldownSweepPainter(
                          cooldownListenable: widget.cooldownListenable,
                          fallbackRemaining: widget.cooldownRemaining,
                          cooldownTotal: widget.cooldownTotal,
                        ),
                      ),
                    ),
                  ),
                // Số giây đếm ngược rõ nét (chỉ cập nhật 1 lần/giây)
                if (!isReady)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: GameConstants.pixelInk.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(
                        GameConstants.hudBarCornerRadius,
                      ),
                      border: Border.all(
                        color: GameConstants.cardBorderColor,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      '$_displayedSeconds',
                      style: GameConstants.hudTextStyle(
                        fontSize: 17,
                        color: GameConstants.hudTextPrimaryColor,
                        fontWeight: FontWeight.w900,
                        tabularNumbers: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CooldownSweepPainter extends CustomPainter {
  final ValueListenable<double>? cooldownListenable;
  final double fallbackRemaining;
  final double cooldownTotal;

  static final Paint _sweepPaint = Paint()
    ..color = GameConstants.pixelShadowBlack.withValues(alpha: 0.58);

  _CooldownSweepPainter({
    required this.cooldownListenable,
    required this.fallbackRemaining,
    required this.cooldownTotal,
  }) : super(repaint: cooldownListenable);

  @override
  void paint(Canvas canvas, Size size) {
    final remaining = cooldownListenable?.value ?? fallbackRemaining;
    if (remaining <= 0.01 || cooldownTotal <= 0) {
      return;
    }
    final fraction = (remaining / cooldownTotal).clamp(0.0, 1.0);
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final rect = Rect.fromCircle(center: center, radius: size.width * 0.5);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      -math.pi * 2 * fraction,
      true,
      _sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CooldownSweepPainter oldDelegate) =>
      oldDelegate.cooldownListenable != cooldownListenable ||
      (oldDelegate.fallbackRemaining - fallbackRemaining).abs() > 0.01 ||
      oldDelegate.cooldownTotal != cooldownTotal;
}

/// Nút hiển thị & đổi vũ khí (Slot 1 / 2) với mũi tên xoay tròn và badge kim cương xanh
class WeaponSwitchButton extends StatefulWidget {
  final String weaponAssetPath;
  final int activeSlotNumber; // 1 hoặc 2
  final VoidCallback onSwitch;
  final double size;

  const WeaponSwitchButton({
    super.key,
    required this.weaponAssetPath,
    required this.activeSlotNumber,
    required this.onSwitch,
    this.size = GameConstants.hudWeaponSwitchButtonSize,
  });

  @override
  State<WeaponSwitchButton> createState() => _WeaponSwitchButtonState();
}

class _WeaponSwitchButtonState extends State<WeaponSwitchButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Nút đổi vũ khí',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          setState(() => _isPressed = true);
          widget.onSwitch();
        },
        onPointerUp: (_) {
          if (mounted) {
            setState(() => _isPressed = false);
          }
        },
        onPointerCancel: (_) {
          if (mounted) {
            setState(() => _isPressed = false);
          }
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 70),
          child: SizedBox(
            width: widget.size + 6,
            height: widget.size + 6,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isPressed
                        ? GameConstants.pixelPanelDark
                        : GameConstants.pixelInk.withValues(alpha: 0.72),
                    border: Border.all(
                      color: _isPressed
                          ? GameConstants.hudGoldColor
                          : GameConstants.cardBorderColor,
                      width: GameConstants.hudBorderWidth,
                    ),
                    boxShadow: GameConstants.hudPixelShadow,
                  ),
                  child: CustomPaint(
                    painter: const _SwapArrowsPainter(),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Image.asset(
                          widget.weaponAssetPath,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 2,
                  left: 2,
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: GameConstants.primaryColor,
                        borderRadius: BorderRadius.circular(
                          GameConstants.hudBarCornerRadius,
                        ),
                        border: Border.all(
                          color: GameConstants.pixelWhite,
                          width: 1.4,
                        ),
                        boxShadow: GameConstants.hudPixelShadow,
                      ),
                      child: Transform.rotate(
                        angle: -math.pi / 4,
                        child: Text(
                          '${widget.activeSlotNumber}',
                          style: GameConstants.hudTextStyle(
                            fontSize: 11,
                            color: GameConstants.hudTextPrimaryColor,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            tabularNumbers: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwapArrowsPainter extends CustomPainter {
  static final Paint _arrowPaint = Paint()
    ..color = GameConstants.pixelSlate.withValues(alpha: 0.65)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.square;

  const _SwapArrowsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    final radius = size.width * 0.5 - 4.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -0.35, 1.5, false, _arrowPaint);
    canvas.drawArc(rect, math.pi - 0.35, 1.5, false, _arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
