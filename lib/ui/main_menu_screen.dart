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
                  horizontal: 14,
                  vertical: 10,
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
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: hero.themeColor.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                hero.spriteAssetPath,
                                width: 28,
                                height: 28,
                                filterQuality: FilterQuality.none,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    hero.name,
                                    style: TextStyle(
                                      color: hero.themeColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Kỷ lục: $_highScore',
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
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
                    // Nút Cài đặt âm thanh góc trên phải
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: CircleBorder(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: IconButton(
                          key: const Key('lobby_audio_settings_button'),
                          tooltip: 'Cài đặt âm thanh',
                          onPressed: () {
                            AudioSettingsService.instance.playUiClick();
                            AudioSettingsDialog.show(context);
                          },
                          icon: const Icon(
                            Icons.settings_rounded,
                            color: Colors.white,
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
                padding: const EdgeInsets.only(left: 24, bottom: 20),
                child: VirtualJoystick(
                  size: 120,
                  knobRadius: 20,
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
                padding: const EdgeInsets.only(right: 26, bottom: 24),
                child: ValueListenableBuilder<LobbyInteractionTarget>(
                  valueListenable: _lobbyGame.nearbyInteractionNotifier,
                  builder: (context, target, _) {
                    final IconData icon;
                    final String label;
                    final Color accent;
                    if (target.isPortal) {
                      icon = Icons.door_sliding_rounded;
                      label = 'VÀO CỔNG';
                      accent = const Color(0xFF64FFDA);
                    } else if (target.hero != null) {
                      icon = Icons.swap_horiz_rounded;
                      label = 'ĐỔI NV';
                      accent = target.hero!.themeColor;
                    } else {
                      icon = Icons.bolt_rounded;
                      label = 'LƯỚT';
                      accent = Colors.white70;
                    }

                    return Semantics(
                      button: true,
                      label: label,
                      child: GestureDetector(
                        key: const Key('lobby_interact_button'),
                        onTap: _lobbyGame.interactOrStep,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: target.hasTarget
                                ? accent.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.16),
                            border: Border.all(
                              color: target.hasTarget
                                  ? accent
                                  : Colors.white.withValues(alpha: 0.28),
                              width: target.hasTarget ? 2.4 : 1.6,
                            ),
                            boxShadow: target.hasTarget
                                ? [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(icon, color: accent, size: 32),
                              const SizedBox(height: 2),
                              Text(
                                label,
                                style: TextStyle(
                                  color: target.hasTarget
                                      ? accent
                                      : Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10.5,
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
