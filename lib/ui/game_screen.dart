import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../game/huit_game.dart';
import '../models/player_class.dart';
import '../models/stage_info.dart';
import '../utils/fps_monitor.dart';
import 'widgets/audio_settings_dialog.dart';
import 'widgets/game_controls.dart';

/// Màn hình chiến đấu nằm ngang tích hợp HUD sinh tồn 5 phút, Boss HP Bar và cụm nút Soul Knight
/// Mỗi cụm HUD và GameWidget đều được bọc RepaintBoundary để cô lập layer vẽ ở 60 FPS.
class GameScreen extends StatefulWidget {
  final PlayerClassInfo selectedClass;
  final StageInfo? selectedStage;

  const GameScreen({
    super.key,
    required this.selectedClass,
    this.selectedStage,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final HuitDeadlineGame _game;
  late final StageInfo _stage;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _stage = widget.selectedStage ?? StageInfo.defaultStage;
    _game = HuitDeadlineGame(
      selectedClass: widget.selectedClass,
      selectedStage: _stage,
    );
  }

  String _formatDuration(double totalSeconds) {
    final clamped = totalSeconds.ceil().clamp(0, 3600);
    final minutes = (clamped ~/ 60).toString().padLeft(2, '0');
    final seconds = (clamped % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      _game.isPausedByUi = _isPaused;
      _game.paused = _isPaused;
    });
  }

  void _restartMatch() {
    setState(() {
      _isPaused = false;
      _game.paused = false;
      _game.resetGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameConstants.backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Nền FlameGame Engine bọc RepaintBoundary riêng biệt với lớp HUD
          RepaintBoundary(child: GameWidget(game: _game)),

          // 2. HUD phía trên (HP, Khiên, Xu, Đồng hồ 05:00 hoặc Boss HP Bar)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GameConstants.hudTopPaddingH,
                  vertical: GameConstants.hudTopPaddingV,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RepaintBoundary(child: _buildLeftPlayerStatsHud()),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RepaintBoundary(
                        child: _buildCenterSurvivalOrBossHud(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RepaintBoundary(child: _buildRightControlsHud()),
                  ],
                ),
              ),
            ),
          ),

          // 2b. Bộ đếm FPS / Frame time (chỉ hiển thị trong debug / profile / SHOW_FPS)
          if (FpsOverlayWidget.isEnabled)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: FpsOverlayWidget(game: _game),
                ),
              ),
            ),

          // 3. Banner cảnh báo Boss khi vừa hết 5 phút & quái thường biến mất
          RepaintBoundary(
            child: ValueListenableBuilder<bool>(
              valueListenable: _game.showBossWarningNotifier,
              builder: (context, showWarning, _) {
                if (!showWarning) {
                  return const SizedBox.shrink();
                }
                return IgnorePointer(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 70),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      decoration: GameConstants.hudPixelBoxDecoration(
                        color: GameConstants.hudWarningBannerBgColor,
                        borderColor: GameConstants.hudGoldColor,
                        borderRadius: GameConstants.hudModalCornerRadius,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'HẾT 05:00 SINH TỒN — QUÁI THƯỜNG ĐÃ BIẾN MẤT!',
                            style: GameConstants.hudTextStyle(
                              fontSize: GameConstants.hudBossWarningSubSize,
                              color: GameConstants.hudGoldColor,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'CẢNH BÁO BOSS: ${_stage.bossName.toUpperCase()} ĐANG GIÁNG LÂM!',
                            style: GameConstants.hudTextStyle(
                              fontSize: GameConstants.hudBossWarningTitleSize,
                              color: GameConstants.hudTextPrimaryColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 4. Joystick di chuyển góc dưới trái (cô lập bằng RepaintBoundary)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: GameConstants.hudBottomMarginH,
                  bottom: GameConstants.hudBottomMarginV,
                ),
                child: RepaintBoundary(
                  child: VirtualJoystick(
                    size: GameConstants.hudJoystickSize,
                    knobRadius: GameConstants.hudJoystickKnobRadius,
                    onDirectionChanged: _game.setMoveDirection,
                  ),
                ),
              ),
            ),
          ),

          // 5. Cụm nút góc dưới phải kiểu Soul Knight: Bắn (trái) + Đổi vũ khí & Dash 8s (phải)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  right: GameConstants.hudBottomMarginH,
                  bottom: GameConstants.hudBottomMarginV,
                ),
                child: RepaintBoundary(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ShootButton(
                          size: GameConstants.hudShootButtonSize,
                          onShootingChanged: (active) =>
                              _game.setShooting(active),
                          onAimChanged: (dir) {
                            if (dir != null) {
                              _game.setShooting(true, aimDirection: dir);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: GameConstants.hudButtonGap + 2),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<int>(
                            valueListenable: _game.activeWeaponIndexNotifier,
                            builder: (context, weaponIdx, _) {
                              final weapons = widget.selectedClass.loadout;
                              final weapon = weapons[
                                  weaponIdx.clamp(0, weapons.length - 1)];
                              return WeaponSwitchButton(
                                size: GameConstants.hudWeaponSwitchButtonSize,
                                weaponAssetPath: weapon.assetPath,
                                activeSlotNumber: weaponIdx + 1,
                                onSwitch: _game.switchWeapon,
                              );
                            },
                          ),
                          const SizedBox(height: GameConstants.hudButtonGap),
                          // DashButton tự lắng nghe dashCooldownNotifier qua CustomPainter (không rebuild 60Hz)
                          DashButton(
                            size: GameConstants.hudDashButtonSize,
                            cooldownListenable: _game.dashCooldownNotifier,
                            cooldownTotal: GameConstants.dashCooldownSeconds,
                            onDash: _game.triggerDash,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 6. Overlay Tạm dừng hoặc Kết thúc trận (Chiến thắng / Thất bại)
          ValueListenableBuilder<GameMatchResult>(
            valueListenable: _game.matchResultNotifier,
            builder: (context, result, _) {
              if (result == GameMatchResult.playing && !_isPaused) {
                return const SizedBox.shrink();
              }
              return _buildModalOverlay(result);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPlayerStatsHud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: GameConstants.hudPixelBoxDecoration(
        color: GameConstants.hudSurfaceColor,
        borderColor: widget.selectedClass.themeColor,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: GameConstants.pixelPanelDark,
              borderRadius: BorderRadius.circular(
                GameConstants.hudBarCornerRadius,
              ),
              border: Border.all(
                color: GameConstants.cardBorderColor,
                width: 1.5,
              ),
            ),
            child: Image.asset(
              widget.selectedClass.spriteAssetPath,
              width: 30,
              height: 30,
              filterQuality: FilterQuality.none,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh Máu + Khiên
              ValueListenableBuilder<double>(
                valueListenable: _game.playerHpNotifier,
                builder: (context, hp, _) {
                  final maxHp = _game.playerMaxHpNotifier.value;
                  final ratio = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite,
                        color: GameConstants.hudDangerColor,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: GameConstants.hudHpBarWidth,
                        height: GameConstants.hudHpBarHeight,
                        decoration: BoxDecoration(
                          color: GameConstants.hudTrackBgColor,
                          borderRadius: BorderRadius.circular(
                            GameConstants.hudBarCornerRadius,
                          ),
                          border: Border.all(
                            color: GameConstants.cardBorderColor,
                            width: 1.2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            GameConstants.hudBarCornerRadius - 1,
                          ),
                          child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation(
                              ratio > 0.35
                                  ? GameConstants.hudHpHealthyColor
                                  : GameConstants.hudDangerColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${hp.ceil()}/${maxHp.toInt()}',
                        style: GameConstants.hudTextStyle(
                          fontSize: GameConstants.hudStatFontSize,
                          color: GameConstants.hudTextPrimaryColor,
                          fontWeight: FontWeight.w900,
                          tabularNumbers: true,
                        ),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: _game.shieldCountNotifier,
                        builder: (context, shields, _) {
                          if (shields <= 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.shield,
                                  color: GameConstants.dashCyanColor,
                                  size: 13,
                                ),
                                Text(
                                  '$shields',
                                  style: GameConstants.hudTextStyle(
                                    fontSize: GameConstants.hudStatFontSize,
                                    color: GameConstants.dashCyanColor,
                                    fontWeight: FontWeight.w900,
                                    tabularNumbers: true,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
              // Đồng hồ sinh tồn 05:00 + Xu + Quái hạ gục đặt gọn ngay trong ô thanh máu
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _game.isBossPhaseNotifier,
                    builder: (context, isBossPhase, _) {
                      if (isBossPhase) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: GameConstants.hudDangerColor,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'ĐẤU BOSS',
                                style: GameConstants.hudTextStyle(
                                  fontSize: GameConstants.hudStatFontSize,
                                  color: GameConstants.hudDangerColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ValueListenableBuilder<double>(
                        valueListenable: _game.remainingSurvivalSecondsNotifier,
                        builder: (context, remaining, _) {
                          final isUrgent = remaining <= 30.0;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_rounded,
                                  color: isUrgent
                                      ? GameConstants.hudDangerColor
                                      : GameConstants.hudGoldColor,
                                  size: 12,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _formatDuration(remaining),
                                  style: GameConstants.hudTextStyle(
                                    fontSize: GameConstants.hudTimerFontSize,
                                    color: isUrgent
                                        ? GameConstants.hudDangerColor
                                        : GameConstants.hudTextPrimaryColor,
                                    fontWeight: FontWeight.w900,
                                    tabularNumbers: true,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _game.coinCountNotifier,
                    builder: (context, coins, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          color: GameConstants.hudGoldColor,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$coins',
                          style: GameConstants.hudTextStyle(
                            fontSize: GameConstants.hudStatFontSize,
                            color: GameConstants.hudGoldColor,
                            fontWeight: FontWeight.w800,
                            tabularNumbers: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: _game.killCountNotifier,
                    builder: (context, kills, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: GameConstants.accentColor,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$kills',
                          style: GameConstants.hudTextStyle(
                            fontSize: GameConstants.hudStatFontSize,
                            color: GameConstants.pixelCream,
                            fontWeight: FontWeight.w800,
                            tabularNumbers: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCenterSurvivalOrBossHud() {
    return Center(
      child: ValueListenableBuilder<bool>(
        valueListenable: _game.isBossPhaseNotifier,
        builder: (context, isBossPhase, _) {
          if (!isBossPhase) {
            return const SizedBox.shrink();
          }

          return ValueListenableBuilder<double>(
            valueListenable: _game.bossHpNotifier,
            builder: (context, bossHp, _) {
              final maxHp = _game.bossMaxHpNotifier.value;
              final ratio = maxHp > 0 ? (bossHp / maxHp).clamp(0.0, 1.0) : 0.0;
              return Container(
                constraints: const BoxConstraints(
                  maxWidth: GameConstants.hudBossBarMaxWidth,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: GameConstants.hudPixelBoxDecoration(
                  color: GameConstants.hudBossPanelBgColor,
                  borderColor: GameConstants.hudDangerColor,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            _stage.bossTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GameConstants.hudTextStyle(
                              fontSize: GameConstants.hudBossTitleFontSize,
                              color: GameConstants.hudGoldColor,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${bossHp.ceil()}/${maxHp.toInt()}',
                          style: GameConstants.hudTextStyle(
                            fontSize: GameConstants.hudStatFontSize,
                            color: GameConstants.hudTextPrimaryColor,
                            fontWeight: FontWeight.w800,
                            tabularNumbers: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: GameConstants.hudTrackBgColor,
                        borderRadius: BorderRadius.circular(
                          GameConstants.hudBarCornerRadius,
                        ),
                        border: Border.all(
                          color: GameConstants.pixelDeepCrimson,
                          width: 1.2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          GameConstants.hudBarCornerRadius - 1,
                        ),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: GameConstants.hudBossBarHeight,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation(
                            GameConstants.hudDangerColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRightControlsHud() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(
            maxWidth: GameConstants.hudStageChipMaxWidth,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: GameConstants.hudPixelBoxDecoration(
            color: GameConstants.hudSurfaceColor,
            borderColor: _stage.themeColor,
          ),
          child: Text(
            'Màn ${_stage.stageCode}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GameConstants.hudTextStyle(
              fontSize: GameConstants.hudStageFontSize,
              color: GameConstants.hudTextPrimaryColor,
              fontWeight: FontWeight.w900,
              tabularNumbers: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildPixelHudIconButton(
          icon: Icons.settings_rounded,
          iconSize: 22,
          onTap: () => AudioSettingsDialog.show(context),
        ),
        const SizedBox(width: 8),
        _buildPixelHudIconButton(
          icon: Icons.pause_rounded,
          iconSize: 24,
          onTap: _togglePause,
        ),
      ],
    );
  }

  Widget _buildPixelHudIconButton({
    required IconData icon,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return Container(
      width: GameConstants.hudMinTouchTarget,
      height: GameConstants.hudMinTouchTarget,
      decoration: GameConstants.hudPixelBoxDecoration(
        color: GameConstants.hudSurfaceColor,
        borderColor: GameConstants.cardBorderColor,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(
            GameConstants.hudCornerRadius - 1,
          ),
          onTap: onTap,
          child: Icon(
            icon,
            color: GameConstants.hudTextPrimaryColor,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildModalOverlay(GameMatchResult result) {
    final bool isWin = result == GameMatchResult.victory;
    final bool isLose = result == GameMatchResult.gameOver;
    final String title;
    final Color titleColor;
    final Color borderColor;
    if (isWin) {
      title = 'CHIẾN THẮNG! ĐÃ VƯỢT QUA ${_stage.bossName.toUpperCase()}';
      titleColor = GameConstants.hudGoldColor;
      borderColor = GameConstants.hudGoldColor;
    } else if (isLose) {
      title = 'THẤT BẠI! BỊ DEADLINE ĐÁNH GỤC';
      titleColor = GameConstants.hudDangerColor;
      borderColor = GameConstants.hudDangerColor;
    } else {
      title = 'TẠM DỪNG TRẬN ĐẤU';
      titleColor = GameConstants.hudTextPrimaryColor;
      borderColor = GameConstants.cardBorderColor;
    }

    return Container(
      color: GameConstants.hudOverlayScrimColor,
      alignment: Alignment.center,
      child: Container(
        width: GameConstants.hudModalWidth,
        padding: const EdgeInsets.all(20),
        decoration: GameConstants.hudPixelBoxDecoration(
          color: GameConstants.cardColor,
          borderColor: borderColor,
          borderRadius: GameConstants.hudModalCornerRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GameConstants.hudTextStyle(
                fontSize: GameConstants.hudModalTitleSize,
                color: titleColor,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Điểm: ${_game.score}   •   Tiêu diệt: ${_game.killCount}   •   Xu: ${_game.coinCount}',
              textAlign: TextAlign.center,
              style: GameConstants.hudTextStyle(
                fontSize: GameConstants.hudModalBodySize,
                color: GameConstants.pixelCream,
                fontWeight: FontWeight.w700,
                tabularNumbers: true,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: GameConstants.hudModalButtonHeight,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GameConstants.hudTextPrimaryColor,
                        backgroundColor: GameConstants.pixelInk,
                        side: const BorderSide(
                          color: GameConstants.cardBorderColor,
                          width: GameConstants.hudBorderWidth,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            GameConstants.hudCornerRadius,
                          ),
                        ),
                      ),
                      child: Text(
                        'VỀ SẢNH',
                        style: GameConstants.hudTextStyle(
                          fontSize: GameConstants.hudModalBodySize,
                          color: GameConstants.hudTextPrimaryColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: GameConstants.hudButtonGap),
                Expanded(
                  child: SizedBox(
                    height: GameConstants.hudModalButtonHeight,
                    child: ElevatedButton(
                      onPressed: (!isWin && !isLose)
                          ? _togglePause
                          : _restartMatch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GameConstants.accentColor,
                        foregroundColor: GameConstants.pixelInk,
                        elevation: 0,
                        side: const BorderSide(
                          color: GameConstants.hudGoldColor,
                          width: GameConstants.hudBorderWidth,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            GameConstants.hudCornerRadius,
                          ),
                        ),
                      ),
                      child: Text(
                        (!isWin && !isLose) ? 'TIẾP TỤC' : 'CHƠI LẠI',
                        style: GameConstants.hudTextStyle(
                          fontSize: GameConstants.hudModalBodySize,
                          color: GameConstants.pixelInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
