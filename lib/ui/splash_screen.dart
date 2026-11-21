import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/player_class.dart';
import '../models/stage_info.dart';
import '../services/audio_settings_service.dart';
import 'main_menu_screen.dart';
import 'widgets/audio_settings_dialog.dart';

/// Màn hình chờ gọn gàng: 1 nút CHƠI ở giữa dưới + 1 nút Cài đặt âm thanh ở góc phải
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _assetsPreloaded = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    AudioSettingsService.instance.ensureBgmPlaying();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_assetsPreloaded) {
      _assetsPreloaded = true;
      _precacheAssets();
    }
  }

  Future<void> _precacheAssets() async {
    final paths = <String>[
      GameConstants.splashBgAsset,
      GameConstants.lobbyBgAsset,
      for (final c in PlayerClassInfo.availableClasses) c.spriteAssetPath,
      for (final s in StageInfo.availableStages) s.mapAssetPath,
    ];
    for (final path in paths) {
      if (!mounted) {
        return;
      }
      try {
        await precacheImage(AssetImage(path), context);
      } catch (_) {}
    }
  }

  void _enterLobby() {
    if (_navigated || !mounted) {
      return;
    }
    _navigated = true;
    AudioSettingsService.instance.playUiClick();
    AudioSettingsService.instance.ensureBgmPlaying();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const MainMenuScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameConstants.backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Nền pixel art màn hình chờ
          Image.asset(
            GameConstants.splashBgAsset,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, _, _) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    GameConstants.pixelInk,
                    GameConstants.pixelPanelDark,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Lớp phủ tối nhẹ để nổi bật tiêu đề và nút Chơi
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  GameConstants.pixelShadowBlack.withValues(alpha: 0.62),
                  Colors.transparent,
                  GameConstants.pixelShadowBlack.withValues(alpha: 0.72),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Stack(
                children: [
                  // Nút cài đặt âm thanh ở góc trên bên phải (đạt chuẩn >= 48dp)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      width: GameConstants.hudMinTouchTarget,
                      height: GameConstants.hudMinTouchTarget,
                      decoration: GameConstants.hudPixelBoxDecoration(
                        color: GameConstants.hudSurfaceColor,
                        borderColor: GameConstants.cardBorderColor,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          key: const Key('splash_audio_settings_button'),
                          tooltip: 'Cài đặt âm thanh',
                          onPressed: () {
                            AudioSettingsService.instance.playUiClick();
                            AudioSettingsDialog.show(context);
                          },
                          icon: const Icon(
                            Icons.settings_rounded,
                            color: GameConstants.hudTextPrimaryColor,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Tiêu đề game ở phía trên giữa
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: GameConstants.hudPixelBoxDecoration(
                              color: GameConstants.primaryColor,
                              borderColor: GameConstants.hudGoldColor,
                              borderRadius: GameConstants.hudCornerRadius,
                            ),
                            child: Text(
                              'HUIT SURVIVAL 2D',
                              style: GameConstants.hudTextStyle(
                                fontSize: 11.5,
                                color: GameConstants.hudTextPrimaryColor,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'SINH VIÊN HUIT ĐÁNH QUÁI DEADLINE',
                            textAlign: TextAlign.center,
                            style: GameConstants.hudTextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: GameConstants.hudTextPrimaryColor,
                              letterSpacing: 0.8,
                              shadows: const [
                                Shadow(
                                  color: GameConstants.pixelShadowBlack,
                                  offset: Offset(2, 2),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Duy nhất 1 nút CHƠI ở phía dưới giữa
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: GameConstants.hudSplashPlayButtonWidth,
                        height: GameConstants.hudSplashPlayButtonHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            GameConstants.hudModalCornerRadius,
                          ),
                          boxShadow: GameConstants.hudPixelShadow,
                        ),
                        child: ElevatedButton.icon(
                          key: const Key('splash_play_button'),
                          onPressed: _enterLobby,
                          icon: const Icon(Icons.play_arrow_rounded, size: 30),
                          label: Text(
                            'CHƠI',
                            style: GameConstants.hudTextStyle(
                              fontSize: 19,
                              color: GameConstants.pixelInk,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.8,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GameConstants.accentColor,
                            foregroundColor: GameConstants.pixelInk,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                GameConstants.hudModalCornerRadius,
                              ),
                              side: const BorderSide(
                                color: GameConstants.hudGoldColor,
                                width: GameConstants.hudBorderWidth,
                              ),
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
        ],
      ),
    );
  }
}
