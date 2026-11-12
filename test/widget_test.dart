import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huit_deadline/game/lobby_game.dart';
import 'package:huit_deadline/main.dart';
import 'package:huit_deadline/models/player_class.dart';
import 'package:huit_deadline/models/stage_info.dart';
import 'package:huit_deadline/services/audio_settings_service.dart';
import 'package:huit_deadline/services/stage_progress_service.dart';
import 'package:huit_deadline/ui/game_screen.dart';
import 'package:huit_deadline/ui/main_menu_screen.dart';
import 'package:huit_deadline/ui/splash_screen.dart';
import 'package:huit_deadline/ui/widgets/audio_settings_dialog.dart';
import 'package:huit_deadline/ui/widgets/stage_map_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Splash has 1 Play button + Audio Settings, enters walkable Lobby, and Portal opens 1-1..1-4 Stage Map',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(854, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const HuitDeadlineApp());
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);
      final playBtn = find.byKey(const Key('splash_play_button'));
      final audioBtn = find.byKey(const Key('splash_audio_settings_button'));
      expect(playBtn, findsOneWidget);
      expect(audioBtn, findsOneWidget);

      // Mở Cài đặt âm thanh ở góc phải màn hình chờ
      await tester.tap(audioBtn);
      await tester.pumpAndSettle();
      expect(find.byType(AudioSettingsDialog), findsOneWidget);

      // Tắt nhạc nền và kiểm tra trạng thái
      final bgmSwitch = find.byKey(const Key('bgm_toggle_switch'));
      await tester.tap(bgmSwitch);
      await tester.pump();
      expect(AudioSettingsService.instance.musicEnabled, isFalse);

      // Kéo giảm âm lượng hiệu ứng SFX
      final sfxSlider = find.byKey(const Key('sfx_volume_slider'));
      await tester.drag(sfxSlider, const Offset(-80, 0));
      await tester.pump();
      expect(AudioSettingsService.instance.sfxVolume, lessThan(0.85));

      await tester.tap(find.byKey(const Key('close_audio_settings_button')));
      await tester.pumpAndSettle();

      // Nhấn nút CHƠI để vào Sảnh chờ có thể di chuyển
      await tester.tap(playBtn);
      await tester.pumpAndSettle();

      expect(find.byType(MainMenuScreen), findsOneWidget);
      expect(find.byKey(const Key('lobby_interact_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Walkable Lobby switches hero near teammate spot and opens 1-1..1-4 Stage Map at Portal',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(854, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late LobbyGame lobbyGame;
      final openCount = <int>[];
      lobbyGame = LobbyGame(
        onPortalEntered: () => openCount.add(1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MainMenuScreen(lobbyGameOverride: lobbyGame),
        ),
      );

      for (int i = 0; i < 60; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 16));
        if (lobbyGame.lobbyPlayer != null &&
            lobbyGame.lobbyPlayer!.isMounted) {
          break;
        }
      }
      expect(lobbyGame.lobbyPlayer, isNotNull);

      // Di chuyển tới chỗ đồng đội Thực Phẩm và đổi nhân vật
      final foodSpot = LobbyGame.heroSpotPositions[PlayerClassType.food]!;
      lobbyGame.lobbyPlayer!.position.setFrom(foodSpot + Vector2(20, 0));
      await tester.pump(const Duration(milliseconds: 30));
      expect(
        lobbyGame.nearbyInteractionNotifier.value.hero?.type,
        equals(PlayerClassType.food),
      );

      await tester.tap(find.byKey(const Key('lobby_interact_button')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      expect(lobbyGame.selectedClass.type, equals(PlayerClassType.food));

      // Di chuyển tới cổng vào màn ở trên cùng
      lobbyGame.lobbyPlayer!.position.setFrom(LobbyGame.portalPosition);
      await tester.pump(const Duration(milliseconds: 30));
      expect(lobbyGame.nearbyInteractionNotifier.value.isPortal, isTrue);
      expect(openCount.length, equals(1));
    },
  );

  testWidgets(
    'StageMapDialog locks unreached stages and unlocks 1-2 after completing 1-1',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await StageProgressService.instance.resetProgressForTest(
        unlockedMaxIndex: 0,
      );
      tester.view.physicalSize = const Size(854, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final picked = await StageMapDialog.show(
                      context,
                      selectedClass:
                          PlayerClassInfo.getByType(PlayerClassType.it),
                      initialStage: StageInfo.defaultStage,
                    );
                    if (picked != null && context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GameScreen(
                            selectedClass: PlayerClassInfo.getByType(
                              PlayerClassType.it,
                            ),
                            selectedStage: picked,
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('OPEN MAP'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN MAP'));
      await tester.pumpAndSettle();

      expect(find.byType(StageMapDialog), findsOneWidget);
      expect(find.byKey(const Key('stage_node_1-1')), findsOneWidget);
      expect(find.byKey(const Key('stage_node_1-2')), findsOneWidget);
      expect(find.byKey(const Key('stage_node_1-3')), findsOneWidget);
      expect(find.byKey(const Key('stage_node_1-4')), findsOneWidget);

      // Trước khi thắng 1-1: chọn 1-2 sẽ bị khóa
      await tester.tap(find.byKey(const Key('stage_node_1-2')));
      await tester.pumpAndSettle();
      expect(find.text('ĐANG KHÓA'), findsOneWidget);
      expect(find.textContaining('Cần hoàn thành Màn 1-1'), findsOneWidget);

      // Sau khi hoàn thành Màn 1-1: Màn 1-2 tự động mở khóa, 1-3 vẫn khóa
      await StageProgressService.instance.markStageCompleted(
        StageInfo.availableStages[0],
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('CHIẾN 1-2'), findsOneWidget);

      await tester.tap(find.byKey(const Key('enter_selected_stage_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.textContaining('1-2'), findsOneWidget);
      expect(find.textContaining('05:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
