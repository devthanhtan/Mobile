import 'package:flutter/material.dart';
import '../constants.dart';

/// Thông tin màn chơi / bản đồ HUIT (1-1, 1-2, 1-3, 1-4) và Boss tương ứng
class StageInfo {
  final String id;
  final String stageCode; // '1-1', '1-2', '1-3', '1-4'
  final String name;
  final String subtitle;
  final String bossName;
  final String bossTitle;
  final double bossMaxHp;
  final String mapAssetPath; // assets/images/maps/... cho Flutter UI
  final String flameMapPath; // maps/... cho Flame
  final String bossAssetPath; // assets/images/enemy/... cho Flutter UI
  final String flameBossPath; // enemy/... cho Flame
  final Color themeColor;

  const StageInfo({
    required this.id,
    required this.stageCode,
    required this.name,
    required this.subtitle,
    required this.bossName,
    required this.bossTitle,
    required this.bossMaxHp,
    required this.mapAssetPath,
    required this.flameMapPath,
    required this.bossAssetPath,
    required this.flameBossPath,
    required this.themeColor,
  });

  static const List<StageInfo> availableStages = [
    StageInfo(
      id: 'exam_hall',
      stageCode: '1-1',
      name: 'Phòng Thi Giảng Đường',
      subtitle: 'Khu A • Không gian rộng',
      bossName: 'Sách Đề Thi Cuối Kỳ',
      bossTitle: 'BOSS ĐỀ THI ĐÓNG DẤU F',
      bossMaxHp: 2200.0,
      mapAssetPath: 'assets/images/${GameConstants.mapExamHallPath}',
      flameMapPath: GameConstants.mapExamHallPath,
      bossAssetPath: 'assets/images/${GameConstants.bossFinalExamPath}',
      flameBossPath: GameConstants.bossFinalExamPath,
      themeColor: Color(0xFFFF7043),
    ),
    StageInfo(
      id: 'library',
      stageCode: '1-2',
      name: 'Thư Viện HUIT',
      subtitle: 'Tầng 2 • Thảm đỏ trung tâm',
      bossName: 'Rồng Giám Thị Tối Cao',
      bossTitle: 'BOSS HỘI ĐỒNG KỶ LUẬT',
      bossMaxHp: 2600.0,
      mapAssetPath: 'assets/images/${GameConstants.mapLibraryPath}',
      flameMapPath: GameConstants.mapLibraryPath,
      bossAssetPath: 'assets/images/${GameConstants.bossDragonDeanPath}',
      flameBossPath: GameConstants.bossDragonDeanPath,
      themeColor: Color(0xFFFFCA28),
    ),
    StageInfo(
      id: 'lab',
      stageCode: '1-3',
      name: 'Phòng Lab Công Nghệ',
      subtitle: 'Tầng 4 • Sàn thép Lab',
      bossName: 'Cỗ Máy Bản Vẽ Quá Tải',
      bossTitle: 'BOSS BLUEPRINT OVERLOAD',
      bossMaxHp: 2800.0,
      mapAssetPath: 'assets/images/${GameConstants.mapLabPath}',
      flameMapPath: GameConstants.mapLabPath,
      bossAssetPath: 'assets/images/${GameConstants.bossBlueprintPath}',
      flameBossPath: GameConstants.bossBlueprintPath,
      themeColor: Color(0xFF29B6F6),
    ),
    StageInfo(
      id: 'canteen',
      stageCode: '1-4',
      name: 'Căng-Tin HUIT',
      subtitle: 'Khu B • Thử thách cuối',
      bossName: 'Golem Đồng Hồ Deadline',
      bossTitle: 'BOSS ÁP LỰC THỜI GIAN',
      bossMaxHp: 3000.0,
      mapAssetPath: 'assets/images/${GameConstants.mapCanteenPath}',
      flameMapPath: GameConstants.mapCanteenPath,
      bossAssetPath: 'assets/images/${GameConstants.bossGolemPath}',
      flameBossPath: GameConstants.bossGolemPath,
      themeColor: Color(0xFFAB47BC),
    ),
  ];

  static StageInfo get defaultStage => availableStages.first;
}
