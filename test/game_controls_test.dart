import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huit_deadline/components/boss_component.dart';
import 'package:huit_deadline/components/bullet_component.dart';
import 'package:huit_deadline/components/enemy_component.dart';
import 'package:huit_deadline/constants.dart';
import 'package:huit_deadline/game/huit_game.dart';
import 'package:huit_deadline/models/player_class.dart';
import 'package:huit_deadline/models/stage_info.dart';
import 'package:huit_deadline/ui/game_screen.dart';
import 'package:huit_deadline/ui/widgets/game_controls.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('VirtualJoystick updates direction and resets on release', (
    tester,
  ) async {
    Vector2 lastDir = Vector2(99, 99);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: VirtualJoystick(
              size: 124,
              knobRadius: 21,
              onDirectionChanged: (dir) => lastDir = dir,
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(VirtualJoystick));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.moveBy(const Offset(45, 0));
    await tester.pump();

    expect(lastDir.x, greaterThan(0.8));
    expect(lastDir.y.abs(), lessThan(0.15));

    await gesture.up();
    await tester.pump();

    expect(lastDir, equals(Vector2.zero()));
  });

  testWidgets('ShootButton shoots on press/drag and stops on release', (
    tester,
  ) async {
    bool isShooting = false;
    Vector2? aimDir;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ShootButton(
              size: 104,
              onShootingChanged: (val) => isShooting = val,
              onAimChanged: (dir) => aimDir = dir,
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(ShootButton));
    final gesture = await tester.startGesture(center);
    await tester.pump();
    expect(isShooting, isTrue);

    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    expect(aimDir, isNotNull);
    expect(aimDir!.y, lessThan(-0.8));

    await gesture.up();
    await tester.pump();
    expect(isShooting, isFalse);
    expect(aimDir, isNull);
  });

  testWidgets('DashButton triggers only when ready and displays 8s cooldown', (
    tester,
  ) async {
    int dashCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DashButton(
              cooldownRemaining: 0.0,
              cooldownTotal: GameConstants.dashCooldownSeconds,
              onDash: () => dashCount++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DashButton));
    await tester.pump();
    expect(dashCount, equals(1));

    // Khi đang hồi chiêu 7.2s: hiển thị số giây '8' và không cho bấm lại
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DashButton(
              cooldownRemaining: 7.2,
              cooldownTotal: GameConstants.dashCooldownSeconds,
              onDash: () => dashCount++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('8'), findsOneWidget);

    await tester.tap(find.byType(DashButton));
    await tester.pump();
    expect(dashCount, equals(1));
  });

  testWidgets('WeaponSwitchButton shows slot badge and invokes onSwitch', (
    tester,
  ) async {
    int switches = 0;
    final itClass = PlayerClassInfo.getByType(PlayerClassType.it);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: WeaponSwitchButton(
              weaponAssetPath: itClass.primaryWeapon.assetPath,
              activeSlotNumber: 1,
              onSwitch: () => switches++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.byType(WeaponSwitchButton));
    await tester.pump();
    expect(switches, equals(1));
  });

  testWidgets('GameScreen renders Soul-Knight landscape HUD without AutoFire', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(
          selectedClass: PlayerClassInfo.getByType(PlayerClassType.it),
          selectedStage: StageInfo.availableStages.first,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(VirtualJoystick), findsOneWidget);
    expect(find.byType(ShootButton), findsOneWidget);
    expect(find.byType(DashButton), findsOneWidget);
    expect(find.byType(WeaponSwitchButton), findsOneWidget);
    expect(find.textContaining('05:00'), findsOneWidget);
    expect(find.textContaining('Tự bắn'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Survival phase spawns enemies, vanishes them on 00:00, and spawns large Boss + 8s Dash works',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(854, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final game = HuitDeadlineGame(
        selectedClass: PlayerClassInfo.getByType(PlayerClassType.it),
        selectedStage: StageInfo.availableStages.first,
        survivalDurationSeconds: 1.4,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameWidget(game: game),
          ),
        ),
      );

      for (int i = 0; i < 60; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 16));
        if (game.player != null && game.player!.isMounted) {
          break;
        }
      }

      expect(game.player, isNotNull);
      expect(game.player!.isMounted, isTrue);

      // Kiểm tra Dash hồi chiêu 8 giây
      final dashed = game.triggerDash();
      expect(dashed, isTrue);
      expect(game.dashCooldownNotifier.value, equals(8.0));
      expect(game.triggerDash(), isFalse);

      // Kiểm tra đổi vũ khí
      await tester.runAsync(() => game.player!.switchWeapon());
      expect(game.activeWeaponIndexNotifier.value, equals(1));

      // Chạy game trong giai đoạn sinh tồn để đảm bảo có quái thường xuất hiện
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        game.world.children.whereType<EnemyComponent>().isNotEmpty,
        isTrue,
      );

      // Chạy qua mốc hết thời gian sinh tồn -> quái biến mất & chuyển sang pha Boss
      for (int i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(game.isBossPhase, isTrue);
      expect(game.remainingSurvivalSecondsNotifier.value, equals(0.0));

      for (final enemy in game.world.children.whereType<EnemyComponent>()) {
        expect(enemy.isVanishing, isTrue);
      }

      // Đợi hiệu ứng biến mất (0.45s) & delay Boss xuất hiện (1.6s)
      for (int i = 0; i < 42; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 16));

      expect(game.world.children.whereType<EnemyComponent>().isEmpty, isTrue);
      final bosses = game.world.children.whereType<BossComponent>().toList();
      expect(bosses.length, equals(1));
      expect(bosses.first.size.x, equals(GameConstants.bossSize));
      expect(bosses.first.size.x, greaterThanOrEqualTo(180.0));
    },
  );

  testWidgets(
    'Auto-aim targets nearest enemy, hits point-blank overlapping enemies, and ranged monsters shoot back',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(854, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final game = HuitDeadlineGame(
        selectedClass: PlayerClassInfo.getByType(PlayerClassType.it),
        selectedStage: StageInfo.availableStages.first,
        survivalDurationSeconds: 300.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GameWidget(game: game)),
        ),
      );

      for (int i = 0; i < 60; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump(const Duration(milliseconds: 16));
        if (game.player != null && game.player!.isMounted) {
          break;
        }
      }
      final player = game.player!;

      // 1. Auto-aim: đặt quái phía trên-trái dù nhân vật hướng phải
      final rangedQuiz = EnemyComponent(
        position: player.position + Vector2(-140, -100),
        type: NormalEnemyType.quiz,
      );
      game.world.add(rangedQuiz);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 16));

      game.setShooting(true);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pump(const Duration(milliseconds: 30));
      game.setShooting(false);

      final playerBullets = game.world.children
          .whereType<BulletComponent>()
          .where((b) => !b.isEnemyBullet)
          .toList();
      expect(playerBullets, isNotEmpty);
      final expectedDir = (rangedQuiz.position - player.position).normalized();
      expect(playerBullets.first.direction.dot(expectedDir), greaterThan(0.95));

      // 2. Point-blank: đặt quái áp sát ngay tâm người chơi (khoảng cách 4px) -> bắn phải trúng ngay!
      final huggingEnemy = EnemyComponent(
        position: player.position + Vector2(4, 0),
        type: NormalEnemyType.deadline,
      );
      final initialHp = huggingEnemy.hp;
      game.world.add(huggingEnemy);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 16));

      game.setShooting(true);
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      game.setShooting(false);
      expect(huggingEnemy.hp, lessThan(initialHp));

      // 3. Quái Email & Quiz có thể bắn đạn đỏ/cam về phía người chơi
      final shooterEmail = EnemyComponent(
        position: player.position + Vector2(220, 0),
        type: NormalEnemyType.email,
      );
      game.world.add(shooterEmail);
      for (int i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final enemyBullets = game.world.children
          .whereType<BulletComponent>()
          .where((b) => b.isEnemyBullet)
          .toList();
      expect(enemyBullets, isNotEmpty);
    },
  );
}
