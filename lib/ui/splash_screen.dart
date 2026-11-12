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
                  colors: [Color(0xFF141526), Color(0xFF232B52)],
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
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.65),
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
                  // Nút cài đặt âm thanh ở góc trên bên phải
                  Align(
                    alignment: Alignment.topRight,
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.60),
                        shape: CircleBorder(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: IconButton(
                          key: const Key('splash_audio_settings_button'),
                          tooltip: 'Cài đặt âm thanh',
                          onPressed: () {
                            AudioSettingsService.instance.playUiClick();
                            AudioSettingsDialog.show(context);
                          },
                          icon: const Icon(
                            Icons.settings_rounded,
                            color: Colors.white,
                            size: 26,
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
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: GameConstants.primaryColor.withValues(
                                alpha: 0.9,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: GameConstants.accentColor,
                                width: 1.5,
                              ),
                            ),
                            child: const Text(
                              'HUIT SURVIVAL 2D',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'SINH VIÊN HUIT ĐÁNH QUÁI DEADLINE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.0,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(0, 3),
                                  blurRadius: 8,
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
                      child: SizedBox(
                        width: 210,
                        height: 52,
                        child: ElevatedButton.icon(
                          key: const Key('splash_play_button'),
                          onPressed: _enterLobby,
                          icon: const Icon(Icons.play_arrow_rounded, size: 30),
                          label: const Text(
                            'CHƠI',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.8,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GameConstants.accentColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                              side: const BorderSide(
                                color: Colors.white70,
                                width: 2,
                              ),
                            ),
                            elevation: 10,
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
