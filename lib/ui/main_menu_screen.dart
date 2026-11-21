import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../game/lobby_game.dart';
import '../models/player_class.dart';
import '../models/stage_info.dart';
import '../services/audio_settings_service.dart';
import '../services/stage_progress_service.dart';
import 'game_screen.dart';
import 'widgets/audio_settings_dialog.dart';
import 'widgets/game_controls.dart';
import 'widgets/stage_map_dialog.dart';

/// Màn hình Sảnh chờ tương tác kiểu Soul Knight: đi tới chỗ đồng đội để đổi nhân vật & đi vào cổng mở bản đồ chọn màn
class MainMenuScreen extends StatefulWidget {
  final LobbyGame? lobbyGameOverride;

  const MainMenuScreen({super.key, this.lobbyGameOverride});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  late final LobbyGame _lobbyGame;
  StageInfo _lastSelectedStage = StageInfo.defaultStage;
  int _highScore = 0;
  bool _isMapOpen = false;

  @override
  void initState() {
    super.initState();
    _lobbyGame =
        widget.lobbyGameOverride ??
        LobbyGame(onPortalEntered: _openStageMapSelector);
    _loadHighScore();
    AudioSettingsService.instance.ensureBgmPlaying();
    StageProgressService.instance.init();
  }

  Future<void> _loadHighScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) {
        return;
      }
      setState(() {
        _highScore = prefs.getInt(GameConstants.highScoreKey) ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _openStageMapSelector() async {
    if (_isMapOpen || !mounted) {
      return;
    }
    _isMapOpen = true;
    AudioSettingsService.instance.playUiClick();

    final chosenStage = await StageMapDialog.show(
      context,
      selectedClass: _lobbyGame.selectedClass,
      initialStage: _lastSelectedStage,
    );

    _isMapOpen = false;
    _lobbyGame.clearPortalTriggerCooldown();

    if (chosenStage != null && mounted) {
      _lastSelectedStage = chosenStage;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GameScreen(
            selectedClass: _lobbyGame.selectedClass,
            selectedStage: chosenStage,
          ),
        ),
      );
      _loadHighScore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameConstants.backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Phòng chờ Safe Room có thể điều khiển nhân vật đi lại
          GameWidget(game: _lobbyGame),

          // 2. HUD tối giản phía trên (Avatar đang chọn + Cài đặt âm thanh)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GameConstants.hudTopPaddingH,
                  vertical: GameConstants.hudTopPaddingV,
                ),
                child: Row(
                  children: [
                    // Ô thông tin nhân vật nhỏ gọn góc trái
                    ValueListenableBuilder<PlayerClassInfo>(
                      valueListenable: _lobbyGame.selectedClassNotifier,
                      builder: (context, hero, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: GameConstants.hudPixelBoxDecoration(
                            color: GameConstants.hudSurfaceColor,
                            borderColor: hero.themeColor,
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
                                  hero.spriteAssetPath,
                                  width: 28,
                                  height: 28,
                                  filterQuality: FilterQuality.none,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    hero.name,
                                    style: GameConstants.hudTextStyle(
                                      fontSize: 12,
                                      color: hero.themeColor,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'Kỷ lục: $_highScore',
                                    style: GameConstants.hudTextStyle(
                                      fontSize: GameConstants.hudStatFontSize,
                                      color: GameConstants.hudGoldColor,
                                      fontWeight: FontWeight.w800,
                                      tabularNumbers: true,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    // Nút Cài đặt âm thanh góc trên phải (đạt chuẩn >= 48x48dp)
                    Container(
                      width: GameConstants.hudMinTouchTarget,
                      height: GameConstants.hudMinTouchTarget,
                      decoration: GameConstants.hudPixelBoxDecoration(
                        color: GameConstants.hudSurfaceColor,
                        borderColor: GameConstants.cardBorderColor,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          key: const Key('lobby_audio_settings_button'),
                          tooltip: 'Cài đặt âm thanh',
                          onPressed: () {
                            AudioSettingsService.instance.playUiClick();
                            AudioSettingsDialog.show(context);
                          },
                          icon: const Icon(
                            Icons.settings_rounded,
                            color: GameConstants.hudTextPrimaryColor,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Joystick di chuyển góc dưới trái
          SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: GameConstants.hudBottomMarginH,
                  bottom: GameConstants.hudBottomMarginV,
                ),
                child: VirtualJoystick(
                  size: GameConstants.hudJoystickSize,
                  knobRadius: GameConstants.hudJoystickKnobRadius,
                  onDirectionChanged: _lobbyGame.setMoveDirection,
                ),
              ),
            ),
          ),

          // 4. Nút Tương tác thông minh góc dưới phải (Đổi nhân vật / Vào cổng / Lướt)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  right: GameConstants.hudBottomMarginH + 4,
                  bottom: GameConstants.hudBottomMarginV + 4,
                ),
                child: ValueListenableBuilder<LobbyInteractionTarget>(
                  valueListenable: _lobbyGame.nearbyInteractionNotifier,
                  builder: (context, target, _) {
                    final IconData icon;
                    final String label;
                    final Color accent;
                    if (target.isPortal) {
                      icon = Icons.door_sliding_rounded;
                      label = 'VÀO CỔNG';
                      accent = GameConstants.pixelCyan;
                    } else if (target.hero != null) {
                      icon = Icons.swap_horiz_rounded;
                      label = 'ĐỔI NV';
                      accent = target.hero!.themeColor;
                    } else {
                      icon = Icons.bolt_rounded;
                      label = 'LƯỚT';
                      accent = GameConstants.hudTextPrimaryColor;
                    }

                    return Semantics(
                      button: true,
                      label: label,
                      child: GestureDetector(
                        key: const Key('lobby_interact_button'),
                        onTap: _lobbyGame.interactOrStep,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: GameConstants.hudLobbyInteractButtonSize,
                          height: GameConstants.hudLobbyInteractButtonSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: target.hasTarget
                                ? accent.withValues(alpha: 0.24)
                                : GameConstants.hudSurfaceColor,
                            border: Border.all(
                              color: target.hasTarget
                                  ? accent
                                  : GameConstants.cardBorderColor,
                              width: GameConstants.hudBorderWidth,
                            ),
                            boxShadow: GameConstants.hudPixelShadow,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, color: accent, size: 30),
                              const SizedBox(height: 2),
                              Text(
                                label,
                                style: GameConstants.hudTextStyle(
                                  fontSize: GameConstants.hudStatFontSize,
                                  color: target.hasTarget
                                      ? accent
                                      : GameConstants.hudTextPrimaryColor,
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
            ),
          ),
        ],
      ),
    );
  }
}
