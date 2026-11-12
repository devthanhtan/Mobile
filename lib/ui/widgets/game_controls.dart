import 'dart:math' as math;
import 'package:flame/components.dart';
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
    this.size = 124.0,
    this.knobRadius = 21.0,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _knobOffset = Offset.zero;
  int? _activePointerId;

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
      final dir = Vector2(normX, normY);
      if (dir.length < 0.08) {
        widget.onDirectionChanged(Vector2.zero());
      } else {
        widget.onDirectionChanged(dir);
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
              // Vòng tròn nền bán trong suốt
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: isActive ? 0.22 : 0.14),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: isActive ? 0.42 : 0.24,
                    ),
                    width: 1.8,
                  ),
                ),
              ),
              // Núm tròn trắng xám bên trong di chuyển mượt
              Transform.translate(
                offset: _knobOffset,
                child: Container(
                  width: widget.knobRadius * 2,
                  height: widget.knobRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(
                      alpha: isActive ? 0.90 : 0.72,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                      ),
                    ],
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
    this.size = 104.0,
  });

  @override
  State<ShootButton> createState() => _ShootButtonState();
}

class _ShootButtonState extends State<ShootButton> {
  int? _activePointerId;
  Offset _aimDragOffset = Offset.zero;

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
      widget.onAimChanged(Vector2(delta.dx, delta.dy).normalized());
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
              color: Colors.white.withValues(alpha: isPressed ? 0.32 : 0.18),
              border: Border.all(
                color: Colors.white.withValues(alpha: isPressed ? 0.55 : 0.28),
                width: 2.0,
              ),
              boxShadow: isPressed
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.18),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
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

  _CrosshairReticlePainter({required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width * 0.25;
    final innerR = size.width * 0.11;
    final color = Colors.white.withValues(alpha: isActive ? 0.92 : 0.72);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    // Hai vòng tròn đồng tâm
    canvas.drawCircle(center, outerR, strokePaint);
    canvas.drawCircle(center, innerR, strokePaint);

    // 4 vạch ngắm trên/dưới/trái/phải
    final tickInner = outerR - 4.0;
    final tickOuter = outerR + 6.5;
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      canvas.drawLine(
        Offset(center.dx + cosA * tickInner, center.dy + sinA * tickInner),
        Offset(center.dx + cosA * tickOuter, center.dy + sinA * tickOuter),
        strokePaint,
      );
    }

    if (isActive) {
      canvas.drawCircle(center, 3.0, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _CrosshairReticlePainter oldDelegate) =>
      oldDelegate.isActive != isActive;
}

/// Nút Lướt (Dash) với biểu tượng tia sét xanh dương và hồi chiêu 8 giây
class DashButton extends StatefulWidget {
  final VoidCallback onDash;
  final double cooldownRemaining;
  final double cooldownTotal;
  final double size;

  const DashButton({
    super.key,
    required this.onDash,
    required this.cooldownRemaining,
    this.cooldownTotal = GameConstants.dashCooldownSeconds,
    this.size = 74.0,
  });

  @override
  State<DashButton> createState() => _DashButtonState();
}

class _DashButtonState extends State<DashButton> {
  bool _isPressed = false;

  bool get _isReady => widget.cooldownRemaining <= 0.01;

  @override
  Widget build(BuildContext context) {
    final fraction = widget.cooldownTotal > 0
        ? (widget.cooldownRemaining / widget.cooldownTotal).clamp(0.0, 1.0)
        : 0.0;

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
          scale: _isPressed && _isReady ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 70),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Nền tròn
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isReady
                        ? Colors.white.withValues(alpha: 0.20)
                        : Colors.black.withValues(alpha: 0.48),
                    border: Border.all(
                      color: _isReady
                          ? GameConstants.dashCyanColor.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.22),
                      width: _isReady ? 2.0 : 1.4,
                    ),
                    boxShadow: _isReady
                        ? [
                            BoxShadow(
                              color: GameConstants.dashCyanColor.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                ),
                // Biểu tượng tia sét cyan giống Soul Knight
                Icon(
                  Icons.bolt_rounded,
                  size: widget.size * 0.62,
                  color: _isReady
                      ? GameConstants.dashCyanColor
                      : GameConstants.dashCyanColor.withValues(alpha: 0.30),
                ),
                // Lớp phủ đồng hồ đếm ngược 8s hình quạt
                if (!_isReady)
                  Positioned.fill(
                    child: ClipOval(
                      child: CustomPaint(
                        painter: _CooldownSweepPainter(fraction: fraction),
                      ),
                    ),
                  ),
                // Số giây đếm ngược rõ nét
                if (!_isReady)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.cooldownRemaining.ceil()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
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
  final double fraction;

  _CooldownSweepPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      -math.pi * 2 * fraction,
      true,
      Paint()..color = Colors.black.withValues(alpha: 0.52),
    );
  }

  @override
  bool shouldRepaint(covariant _CooldownSweepPainter oldDelegate) =>
      (oldDelegate.fraction - fraction).abs() > 0.005;
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
    this.size = 68.0,
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
                    color: Colors.white.withValues(
                      alpha: _isPressed ? 0.30 : 0.18,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.26),
                      width: 1.6,
                    ),
                  ),
                  child: CustomPaint(
                    painter: _SwapArrowsPainter(),
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
                // Badge số slot màu xanh hình thoi giống góc trên trái nút vũ khí Soul Knight
                Positioned(
                  top: 2,
                  left: 2,
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 19,
                      height: 19,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0288D1),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.white70, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Transform.rotate(
                        angle: -math.pi / 4,
                        child: Text(
                          '${widget.activeSlotNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
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
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    // Hai cung tròn đối xứng
    canvas.drawArc(rect, -0.35, 1.5, false, paint);
    canvas.drawArc(rect, math.pi - 0.35, 1.5, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
