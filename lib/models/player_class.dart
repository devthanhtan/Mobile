import 'package:flutter/material.dart';
import '../constants.dart';
import 'weapon_config.dart';
import 'weapon_info.dart';

/// Enum phân loại 3 class nhân vật Sinh viên HUIT
enum PlayerClassType {
  it, // Công nghệ thông tin (Kính cận cyan)
  food, // Công nghệ thực phẩm (Kính bảo hộ xanh lá)
  eco, // Kinh tế / Quản trị (Mũ vàng)
}

/// Lớp lưu trữ thông tin chỉ số, vũ khí (Data + Strategy) và hình ảnh của từng class
class PlayerClassInfo {
  final PlayerClassType type;
  final String name;
  final String department;
  final String description;
  final String spriteAssetPath; // assets/images/... dùng cho Flutter Image UI
  final String flameSpritePath; // Đường dẫn tương đối dùng cho Flame (player/...)
  final String initialWeaponName;
  final String initialWeaponAssetPath;
  final String flameWeaponPath; // Đường dẫn tương đối dùng cho Flame (weapon/...)
  final WeaponConfig primaryWeapon;
  final WeaponConfig secondaryWeapon;
  final double maxHp;
  final double moveSpeed;
  final double damageMultiplier;
  final Color themeColor;

  const PlayerClassInfo({
    required this.type,
    required this.name,
    required this.department,
    required this.description,
    required this.spriteAssetPath,
    required this.flameSpritePath,
    required this.initialWeaponName,
    required this.initialWeaponAssetPath,
    required this.flameWeaponPath,
    required this.primaryWeapon,
    required this.secondaryWeapon,
    required this.maxHp,
    required this.moveSpeed,
    required this.damageMultiplier,
    required this.themeColor,
  });

  List<WeaponInfo> get loadout => [primaryWeapon, secondaryWeapon];
  List<WeaponConfig> get weaponConfigs => [primaryWeapon, secondaryWeapon];

  /// Danh sách 3 Class nhân vật Sinh viên HUIT trang bị đủ 5 vũ khí đặc trưng
  static const List<PlayerClassInfo> availableClasses = [
    PlayerClassInfo(
      type: PlayerClassType.it,
      name: 'Sinh Viên IT',
      department: 'Khoa Công Nghệ Thông Tin',
      description:
          'Kính cận code xuyên đêm! Sát thương +20%. Trang bị Bút Bi Thần Tốc & Laptop Laser.',
      spriteAssetPath: 'assets/images/${GameConstants.playerITPath}',
      flameSpritePath: GameConstants.playerITPath,
      initialWeaponName: 'Bút Bi Thần Tốc',
      initialWeaponAssetPath: 'assets/images/${GameConstants.weaponPenPath}',
      flameWeaponPath: GameConstants.weaponPenPath,
      primaryWeapon: WeaponConfig.pen,
      secondaryWeapon: WeaponConfig.laptop,
      maxHp: 100.0,
      moveSpeed: 185.0,
      damageMultiplier: 1.2,
      themeColor: GameConstants.pixelCyan,
    ),
    PlayerClassInfo(
      type: PlayerClassType.food,
      name: 'Sinh Viên Thực Phẩm',
      department: 'Khoa Công Nghệ Thực Phẩm',
      description:
          'Kính bảo hộ Lab & dinh dưỡng dồi dào (+40% HP). Trang bị Trà Sữa Hồi Máu & Giáo Trình.',
      spriteAssetPath: 'assets/images/${GameConstants.playerFoodPath}',
      flameSpritePath: GameConstants.playerFoodPath,
      initialWeaponName: 'Trà Sữa Trân Châu',
      initialWeaponAssetPath: 'assets/images/${GameConstants.weaponBobaPath}',
      flameWeaponPath: GameConstants.weaponBobaPath,
      primaryWeapon: WeaponConfig.boba,
      secondaryWeapon: WeaponConfig.textbook,
      maxHp: 140.0,
      moveSpeed: 165.0,
      damageMultiplier: 1.0,
      themeColor: GameConstants.pixelEmerald,
    ),
    PlayerClassInfo(
      type: PlayerClassType.eco,
      name: 'Sinh Viên Kinh Tế',
      department: 'Khoa Quản Trị Kinh Doanh',
      description:
          'Mũ vàng năng động, chạy nhanh +20%. Trang bị USB Phi Tiêu Nảy Tường & Giáo Trình.',
      spriteAssetPath: 'assets/images/${GameConstants.playerEcoPath}',
      flameSpritePath: GameConstants.playerEcoPath,
      initialWeaponName: 'USB Phi Tiêu',
      initialWeaponAssetPath: 'assets/images/${GameConstants.weaponUsbPath}',
      flameWeaponPath: GameConstants.weaponUsbPath,
      primaryWeapon: WeaponConfig.usb,
      secondaryWeapon: WeaponConfig.textbook,
      maxHp: 90.0,
      moveSpeed: 218.0,
      damageMultiplier: 1.0,
      themeColor: GameConstants.pixelGold,
    ),
  ];

  static PlayerClassInfo getByType(PlayerClassType type) {
    return availableClasses.firstWhere((element) => element.type == type);
  }
}
