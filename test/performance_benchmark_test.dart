import 'dart:io';
import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huit_deadline/components/enemy_component.dart';
import 'package:huit_deadline/game/huit_game.dart';
import 'package:huit_deadline/models/player_class.dart';
import 'package:huit_deadline/models/stage_info.dart';
import 'package:huit_deadline/models/weapon_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Benchmark đo hiệu năng vòng lặp game với 32 quái + bắn đạn liên tục + Dash cooldown
void main() {
  testWidgets(
    'Performance benchmark: 32 enemies + continuous bullets + HUD notifier pressure',
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

      int timerNotifications = 0;
      int dashNotifications = 0;
      game.remainingSurvivalSecondsNotifier.addListener(() {
        timerNotifications++;
      });
      game.dashCooldownNotifier.addListener(() {
        dashNotifications++;
      });

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
      expect(player.isMounted, isTrue);

      // Spawn 32 quái xung quanh người chơi (gần + xa, đủ 3 loại)
      final rng = math.Random(42);
      for (int i = 0; i < 32; i++) {
        final angle = (math.pi * 2 / 32) * i;
        final dist = 240.0 + (i % 4) * 120.0;
        final type = NormalEnemyType.values[i % NormalEnemyType.values.length];
        game.world.add(
          EnemyComponent(
            position:
                player.position +
                Vector2(math.cos(angle) * dist, math.sin(angle) * dist),
            type: type,
            difficultyScale: 1.5,
          ),
        );
      }

      // Đợi quái mount hoàn tất
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pump(const Duration(milliseconds: 16));

      // Kích hoạt bắn liên tục & Dash để tạo tải thực tế (đạn + hồi chiêu + quái bắn)
      timerNotifications = 0;
      dashNotifications = 0;
      game.triggerDash();
      game.setShooting(true);
      game.setMoveDirection(Vector2(0.7, 0.3));

      // Warm-up 15 frame
      for (int i = 0; i < 15; i++) {
        game.update(1.0 / 60.0);
      }

      // Đo 180 frame (= 3 giây ở 60 FPS)
      const measuredFrames = 180;
      final frameTimesUs = List<int>.filled(measuredFrames, 0);
      final rssBefore = ProcessInfo.currentRss;
      final sw = Stopwatch();

      for (int i = 0; i < measuredFrames; i++) {
        // Đổi hướng nhẹ để test camera & auto-aim
        if (i % 30 == 0) {
          final a = rng.nextDouble() * math.pi * 2;
          game.setMoveDirection(Vector2(math.cos(a), math.sin(a)));
        }
        sw
          ..reset()
          ..start();
        game.update(1.0 / 60.0);
        sw.stop();
        frameTimesUs[i] = sw.elapsedMicroseconds;
      }

      final rssAfter = ProcessInfo.currentRss;
      game.setShooting(false);

      final sorted = List<int>.from(frameTimesUs)..sort();
      final totalUs = frameTimesUs.fold<int>(0, (a, b) => a + b);
      final avgMs = (totalUs / measuredFrames) / 1000.0;
      final p95Ms = sorted[(measuredFrames * 0.95).floor()] / 1000.0;
      final maxMs = sorted.last / 1000.0;
      final rssDeltaKb = (rssAfter - rssBefore) / 1024.0;

      // Dùng debugPrint để xuất số liệu đo benchmark trong flutter test
      debugPrint(
        'BENCHMARK_RESULT | frames=$measuredFrames '
        '| avgMs=${avgMs.toStringAsFixed(3)} '
        '| p95Ms=${p95Ms.toStringAsFixed(3)} '
        '| maxMs=${maxMs.toStringAsFixed(3)} '
        '| timerNotifies=$timerNotifications '
        '| dashNotifies=$dashNotifications '
        '| rssDeltaKB=${rssDeltaKb.toStringAsFixed(1)}',
      );

      expect(avgMs, lessThan(16.67));
    },
  );

  testWidgets(
    'Registries, Bullet Pool, HUD quantization, and dt clamping work accurately',
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

      // 1. Kiểm tra registry enemies tự thêm ở onMount & tự xóa ở onRemove
      final enemy = EnemyComponent(
        position: game.player!.position + Vector2(180, 0),
        type: NormalEnemyType.deadline,
      );
      game.world.add(enemy);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.enemies.contains(enemy), isTrue);

      enemy.removeFromParent();
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.enemies.contains(enemy), isFalse);

      // 2. Kiểm tra Object Pool tái sử dụng đúng instance BulletComponent
      final b1 = game.spawnBullet(
        x: game.player!.position.x,
        y: game.player!.position.y,
        dirX: 1,
        dirY: 0,
        damage: 10,
        speed: 400,
        color: Colors.cyanAccent,
        maxDistance: 200,
        isEnemyBullet: false,
      );
      expect(b1, isNotNull);
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.activeBullets.contains(b1), isTrue);

      b1!.consume();
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.activeBullets.contains(b1), isFalse);

      final b2 = game.spawnBullet(
        x: game.player!.position.x,
        y: game.player!.position.y,
        dirX: 0,
        dirY: 1,
        damage: 15,
        speed: 450,
        color: Colors.amberAccent,
        maxDistance: 250,
        isEnemyBullet: false,
      );
      expect(identical(b1, b2), isTrue);

      // 3. Kiểm tra kẹp dt lớn (ví dụ 1.5s do lag/chuyển app) chỉ tiến tối đa 1/30s
      final elapsedBefore = game.elapsedSurvivalSeconds;
      game.update(1.5);
      expect(
        game.elapsedSurvivalSeconds - elapsedBefore,
        closeTo(1.0 / 30.0, 0.001),
      );

      // 3b. Kiểm tra Camera luôn focus chính xác vào vị trí nhân vật ngay khi vào màn & khi di chuyển
      expect(
        game.camera.viewfinder.position.distanceTo(game.player!.position),
        lessThan(1.0),
      );
      game.player!.position.setValues(520.0, 640.0);
      game.update(1.0 / 60.0);
      expect(
        game.camera.viewfinder.position.distanceTo(game.player!.position),
        lessThan(1.0),
      );

      // 4. Kiểm tra cache SpriteAnimation tạo 1 lần cho Player, Enemy, Boss, Item
      expect(game.spriteCache.playerAnimations, isNotNull);
      expect(game.spriteCache.playerAnimations!.idle.frames.length, equals(4));
      expect(game.spriteCache.playerAnimations!.walk.frames.length, equals(4));
      expect(game.spriteCache.playerAnimations!.hit.frames.length, equals(1));
      expect(game.spriteCache.playerAnimations!.death.frames.length, equals(4));
      expect(game.spriteCache.bossAnimations, isNotNull);
      expect(game.spriteCache.bossAnimations!.death.frames.length, equals(6));
      expect(game.spriteCache.itemAnimations.length, equals(4));

      // 5. Kiểm tra 5 vũ khí riêng trong WeaponConfig (Bút bi, Laptop 0.4s laser, USB nảy, Trà sữa hồi máu, Giáo trình cận chiến)
      expect(WeaponConfig.allWeapons.length, equals(5));
      final player = game.player!;

      // 5a. Laptop (Slot 2 của SV IT): giữ nạp 0.4s bắn laser xuyên nhiều quái thẳng hàng
      await tester.runAsync(() => player.switchWeapon());
      expect(player.activeWeapon.kind, equals(WeaponKind.laptop));
      final lineEnemy1 = EnemyComponent(
        position: player.position + Vector2(110, 0),
        type: NormalEnemyType.quiz,
      );
      final lineEnemy2 = EnemyComponent(
        position: player.position + Vector2(230, 0),
        type: NormalEnemyType.quiz,
      );
      game.world.add(lineEnemy1);
      game.world.add(lineEnemy2);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final e1HpBefore = lineEnemy1.hp;
      final e2HpBefore = lineEnemy2.hp;

      // Giữ nút bắn qua mốc 0.4s để Laptop xả tia laser xuyên cả 2 quái
      game.setShooting(true, aimDirection: Vector2(1, 0));
      for (int i = 0; i < 16; i++) {
        game.update(0.03);
      }
      game.setShooting(false);
      expect(lineEnemy1.hp, lessThan(e1HpBefore));
      expect(lineEnemy2.hp, lessThan(e2HpBefore));

      // 5b. Trà sữa: trúng quái hồi máu cho người chơi
      player.currentHp = 50.0;
      WeaponConfig.boba.strategy.executeFire(
        player: player,
        game: game,
        config: WeaponConfig.boba,
        aimDir: Vector2(1, 0),
      );
      await tester.pump(const Duration(milliseconds: 16));
      for (int i = 0; i < 12; i++) {
        game.update(0.025);
      }
      expect(player.currentHp, greaterThan(50.0));

      // 5c. Giáo trình cận chiến: vung cung tròn đẩy lùi quái
      final meleeTarget = EnemyComponent(
        position: player.position + Vector2(54, 0),
        type: NormalEnemyType.quiz,
      );
      game.world.add(meleeTarget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 16));
      final beforeX = meleeTarget.position.x;
      WeaponConfig.textbook.strategy.executeFire(
        player: player,
        game: game,
        config: WeaponConfig.textbook,
        aimDir: Vector2(1, 0),
      );
      expect(meleeTarget.position.x, greaterThan(beforeX + 20.0));
    },
  );
}
