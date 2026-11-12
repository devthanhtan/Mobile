import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../game/huit_game.dart';
import '../models/player_class.dart';
import '../models/stage_info.dart';
import 'widgets/audio_settings_dialog.dart';
import 'widgets/game_controls.dart';

/// Màn hình chiến đấu nằm ngang tích hợp HUD sinh tồn 5 phút, Boss HP Bar và cụm nút Soul Knight
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
          // 1. Nền FlameGame Engine
          GameWidget(game: _game),

          // 2. HUD phía trên (HP, Khiên, Xu, Đồng hồ 05:00 hoặc Boss HP Bar)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLeftPlayerStatsHud(),
                    const SizedBox(width: 8),
                    Expanded(child: _buildCenterSurvivalOrBossHud()),
                    const SizedBox(width: 8),
                    _buildRightControlsHud(),
                  ],
                ),
              ),
            ),
          ),

          // 3. Banner cảnh báo Boss khi vừa hết 5 phút & quái thường biến mất
          ValueListenableBuilder<bool>(
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
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC7F0000),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.amberAccent,
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.55),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'HẾT 05:00 SINH TỒN — QUÁI THƯỜNG ĐÃ BIẾN MẤT!',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'CẢNH BÁO BOSS: ${_stage.bossName.toUpperCase()} ĐANG GIÁNG LÂM!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // 4. Joystick di chuyển góc dưới trái
          SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 20),
                child: VirtualJoystick(
                  size: 124,
                  knobRadius: 21,
                  onDirectionChanged: _game.setMoveDirection,
                ),
              ),
            ),
          ),

          // 5. Cụm nút góc dưới phải kiểu Soul Knight: Bắn (trái) + Đổi vũ khí & Dash 8s (phải)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 22, bottom: 18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: ShootButton(
                        size: 104,
                        onShootingChanged: (active) =>
                            _game.setShooting(active),
                        onAimChanged: (dir) {
                          if (dir != null) {
                            _game.setShooting(true, aimDirection: dir);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: _game.activeWeaponIndexNotifier,
                          builder: (context, weaponIdx, _) {
                            final weapons = widget.selectedClass.loadout;
                            final weapon =
                                weapons[weaponIdx.clamp(0, weapons.length - 1)];
                            return WeaponSwitchButton(
                              size: 66,
                              weaponAssetPath: weapon.assetPath,
                              activeSlotNumber: weaponIdx + 1,
                              onSwitch: _game.switchWeapon,
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        ValueListenableBuilder<double>(
                          valueListenable: _game.dashCooldownNotifier,
                          builder: (context, cooldown, _) {
                            return DashButton(
                              size: 74,
                              cooldownRemaining: cooldown,
                              cooldownTotal: GameConstants.dashCooldownSeconds,
                              onDash: _game.triggerDash,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
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
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.selectedClass.themeColor.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            widget.selectedClass.spriteAssetPath,
            width: 32,
            height: 32,
            filterQuality: FilterQuality.none,
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
                        color: Colors.redAccent,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 84,
                        height: 10,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation(
                              ratio > 0.35
                                  ? const Color(0xFF4CAF50)
                                  : Colors.redAccent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${hp.ceil()}/${maxHp.toInt()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
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
                                  color: Colors.cyanAccent,
                                  size: 13,
                                ),
                                Text(
                                  '$shields',
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
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
              const SizedBox(height: 3),
              // Đồng hồ sinh tồn 05:00 + Xu + Quái hạ gục đặt gọn ngay trong ô thanh máu
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _game.isBossPhaseNotifier,
                    builder: (context, isBossPhase, _) {
                      if (isBossPhase) {
                        return const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.redAccent,
                                size: 12,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'ĐẤU BOSS',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 10.5,
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
                                      ? Colors.redAccent
                                      : Colors.amberAccent,
                                  size: 12,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _formatDuration(remaining),
                                  style: TextStyle(
                                    color: isUrgent
                                        ? Colors.redAccent
                                        : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
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
                          color: Colors.amberAccent,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$coins',
                          style: const TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ValueListenableBuilder<int>(
                    valueListenable: _game.killCountNotifier,
                    builder: (context, kills, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: Colors.orangeAccent,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$kills',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
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
          // Khi đang trong 5 phút sinh tồn: giữ vùng giữa hoàn toàn trống để không che nhân vật
          if (!isBossPhase) {
            return const SizedBox.shrink();
          }

          // Giai đoạn Boss: Hiển thị thanh máu Boss lớn tạo cảm giác áp lực mạnh
          return ValueListenableBuilder<double>(
            valueListenable: _game.bossHpNotifier,
            builder: (context, bossHp, _) {
              final maxHp = _game.bossMaxHpNotifier.value;
              final ratio = maxHp > 0 ? (bossHp / maxHp).clamp(0.0, 1.0) : 0.0;
              return Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xD91E0B14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent, width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
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
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${bossHp.ceil()}/${maxHp.toInt()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 10,
                        backgroundColor: Colors.black54,
                        valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFFF1744),
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
          constraints: const BoxConstraints(maxWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _stage.themeColor.withValues(alpha: 0.6),
            ),
          ),
          child: Text(
            'Màn ${_stage.stageCode}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _stage.themeColor,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          height: 44,
          child: Material(
            color: Colors.black.withValues(alpha: 0.62),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => AudioSettingsDialog.show(context),
              child: const Icon(
                Icons.settings_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: Colors.black.withValues(alpha: 0.62),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _togglePause,
              child: const Icon(
                Icons.pause_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModalOverlay(GameMatchResult result) {
    final bool isWin = result == GameMatchResult.victory;
    final bool isLose = result == GameMatchResult.gameOver;
    final String title;
    final Color titleColor;
    if (isWin) {
      title = 'CHIẾN THẮNG! ĐÃ VƯỢT QUA ${_stage.bossName.toUpperCase()}';
      titleColor = Colors.amberAccent;
    } else if (isLose) {
      title = 'THẤT BẠI! BỊ DEADLINE ĐÁNH GỤC';
      titleColor = Colors.redAccent;
    } else {
      title = 'TẠM DỪNG TRẬN ĐẤU';
      titleColor = Colors.white;
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      alignment: Alignment.center,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: GameConstants.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isWin
                ? Colors.amberAccent
                : (isLose ? Colors.redAccent : GameConstants.cardBorderColor),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Điểm: ${_game.score}   •   Tiêu diệt: ${_game.killCount}   •   Xu: ${_game.coinCount}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('VỀ SẢNH'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: (!isWin && !isLose)
                          ? _togglePause
                          : _restartMatch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GameConstants.accentColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        (!isWin && !isLose) ? 'TIẾP TỤC' : 'CHƠI LẠI',
                        style: const TextStyle(fontWeight: FontWeight.w900),
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
