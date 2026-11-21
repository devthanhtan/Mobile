import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../constants.dart';
import '../game/huit_game.dart';

/// Ảnh chụp số liệu hiệu năng cập nhật chậm (2 Hz) để không làm nặng UI
class FpsSnapshot {
  final double fps;
  final double frameTimeMs;
  final double buildTimeMs;
  final double rasterTimeMs;
  final double gameUpdateMs;
  final int enemyCount;
  final int bulletCount;
  final int particleCount;

  const FpsSnapshot({
    this.fps = 60.0,
    this.frameTimeMs = 16.6,
    this.buildTimeMs = 0.0,
    this.rasterTimeMs = 0.0,
    this.gameUpdateMs = 0.0,
    this.enemyCount = 0,
    this.bulletCount = 0,
    this.particleCount = 0,
  });
}

/// Overlay đo FPS & frame time — CHỈ hoạt động khi kDebugMode, kProfileMode
/// hoặc truyền cờ --dart-define=SHOW_FPS=true (tắt hoàn toàn ở bản release).
class FpsOverlayWidget extends StatefulWidget {
  final HuitDeadlineGame game;

  const FpsOverlayWidget({super.key, required this.game});

  static bool get isEnabled =>
      kDebugMode || kProfileMode || GameConstants.showFpsOverlayEnv;

  @override
  State<FpsOverlayWidget> createState() => _FpsOverlayWidgetState();
}

class _FpsOverlayWidgetState extends State<FpsOverlayWidget> {
  final ValueNotifier<FpsSnapshot> _snapshotNotifier = ValueNotifier(
    const FpsSnapshot(),
  );

  // Bộ đệm vòng trung bình trượt 30 khung hình gần nhất
  static const int _sampleCapacity = 30;
  final List<double> _totalMsSamples = List<double>.filled(_sampleCapacity, 16.6);
  final List<double> _buildMsSamples = List<double>.filled(_sampleCapacity, 0.0);
  final List<double> _rasterMsSamples = List<double>.filled(_sampleCapacity, 0.0);
  int _sampleIndex = 0;
  int _sampleCount = 0;
  int _lastPublishMs = 0;

  @override
  void initState() {
    super.initState();
    if (FpsOverlayWidget.isEnabled) {
      SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    }
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    if (!mounted || timings.isEmpty) {
      return;
    }
    for (final timing in timings) {
      final totalMs = timing.totalSpan.inMicroseconds / 1000.0;
      final buildMs = timing.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = timing.rasterDuration.inMicroseconds / 1000.0;
      _totalMsSamples[_sampleIndex] = totalMs;
      _buildMsSamples[_sampleIndex] = buildMs;
      _rasterMsSamples[_sampleIndex] = rasterMs;
      _sampleIndex = (_sampleIndex + 1) % _sampleCapacity;
      if (_sampleCount < _sampleCapacity) {
        _sampleCount++;
      }
    }

    // Chỉ cập nhật UI mỗi 500ms (2 Hz) để không gây rebuild 60 lần/giây
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastPublishMs < 500 || _sampleCount == 0) {
      return;
    }
    _lastPublishMs = nowMs;

    double sumTotal = 0;
    double sumBuild = 0;
    double sumRaster = 0;
    for (int i = 0; i < _sampleCount; i++) {
      sumTotal += _totalMsSamples[i];
      sumBuild += _buildMsSamples[i];
      sumRaster += _rasterMsSamples[i];
    }
    final avgTotal = sumTotal / _sampleCount;
    final avgBuild = sumBuild / _sampleCount;
    final avgRaster = sumRaster / _sampleCount;
    final fps = avgTotal > 0.1 ? (1000.0 / avgTotal).clamp(0.0, 120.0) : 60.0;

    _snapshotNotifier.value = FpsSnapshot(
      fps: fps,
      frameTimeMs: avgTotal,
      buildTimeMs: avgBuild,
      rasterTimeMs: avgRaster,
      gameUpdateMs: widget.game.lastAvgUpdateMs,
      enemyCount: widget.game.enemies.length,
      bulletCount: widget.game.activeBullets.length,
      particleCount: widget.game.activeParticleCount,
    );
  }

  @override
  void dispose() {
    if (FpsOverlayWidget.isEnabled) {
      SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    }
    _snapshotNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!FpsOverlayWidget.isEnabled) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: IgnorePointer(
        child: ValueListenableBuilder<FpsSnapshot>(
          valueListenable: _snapshotNotifier,
          builder: (context, s, _) {
            final fpsColor = s.fps >= 55.0
                ? GameConstants.hudHpHealthyColor
                : (s.fps >= 40.0
                      ? GameConstants.hudGoldColor
                      : GameConstants.hudDangerColor);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: GameConstants.hudPixelBoxDecoration(
                color: GameConstants.hudSurfaceColor,
                borderColor: GameConstants.cardBorderColor,
                borderWidth: 1.5,
                withShadow: false,
              ),
              child: Text(
                'FPS ${s.fps.toStringAsFixed(0)} | '
                '${s.frameTimeMs.toStringAsFixed(1)}ms '
                '(U:${s.buildTimeMs.toStringAsFixed(1)} '
                'R:${s.rasterTimeMs.toStringAsFixed(1)} '
                'G:${s.gameUpdateMs.toStringAsFixed(1)}) | '
                'E:${s.enemyCount} B:${s.bulletCount} P:${s.particleCount}',
                style: GameConstants.hudTextStyle(
                  fontSize: 9.5,
                  color: fpsColor,
                  fontWeight: FontWeight.w800,
                  tabularNumbers: true,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
