import 'package:flutter/material.dart';
import '../constants.dart';
import 'weapon_info.dart';

/// Enum phân loại 3 class nhân vật Sinh viên HUIT
enum PlayerClassType {
  it, // Công nghệ thông tin
  food, // Công nghệ thực phẩm
  eco, // Kinh tế / Quản trị
}

/// Lớp lưu trữ thông tin chỉ số, vũ khí và hình ảnh của từng class
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
  final WeaponInfo primaryWeapon;
  final WeaponInfo secondaryWeapon;
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

  /// Danh sách 3 Class nhân vật Sinh viên HUIT
  static const List<PlayerClassInfo> availableClasses = [
    PlayerClassInfo(
      type: PlayerClassType.it,
      name: 'Sinh Viên IT',
      department: 'Khoa Công Nghệ Thông Tin',
      description: 'Gõ phím thần tốc! Sát thương +20%. Trang bị Bút Viết Code & Laptop Gaming.',
      spriteAssetPath: 'assets/images/${GameConstants.playerITPath}',
      flameSpritePath: GameConstants.playerITPath,
      initialWeaponName: 'Bút Viết Code',
      initialWeaponAssetPath: 'assets/images/${GameConstants.weaponPenPath}',
      flameWeaponPath: GameConstants.weaponPenPath,
      primaryWeapon: WeaponInfo(
        name: 'Bút Viết Code',
        assetPath: 'assets/images/${GameConstants.weaponPenPath}',
        flamePath: GameConstants.weaponPenPath,
        damage: 28.0,
        fireCooldown: 0.24,
        bulletSpeed: 520.0,
        bulletCount: 1,
        bulletColor: Colors.cyanAccent,
      ),
      secondaryWeapon: WeaponInfo(
        name: 'Laptop Gaming',
        assetPath: 'assets/images/${GameConstants.weaponLaptopPath}',
        flamePath: GameConstants.weaponLaptopPath,
        damage: 20.0,
        fireCooldown: 0.44,
        bulletSpeed: 460.0,
        bulletCount: 3,
        spreadAngleRadians: 0.38,
        bulletColor: Color(0xFF40C4FF),
      ),
      maxHp: 100.0,
      moveSpeed: 185.0,
      damageMultiplier: 1.2,
      themeColor: Colors.cyanAccent,
    ),
    PlayerClassInfo(
      type: PlayerClassType.food,
      name: 'Sinh Viên Thực Phẩm',
      department: 'Khoa Công Nghệ Thực Phẩm',
      description: 'Dinh dưỡng dồi dào! Thêm 40% máu tối đa. Trang bị Trà Sữa & Laptop Lab.',
      spriteAssetPath: 'assets/images/${GameConstants.playerFoodPath}',
      flameSpritePath: GameConstants.playerFoodPath,
      initialWeaponName: 'Trà Sữa Hồi Máu',
      initialWeaponAssetPath: 'assets/images/${GameConstants.weaponBobaPath}',
      flameWeaponPath: GameConstants.weaponBobaPath,
      primaryWeapon: WeaponInfo(
        name: 'Trà Sữa Hồi Máu',
        assetPath: 'assets/images/${GameConstants.weaponBobaPath}',
        flamePath: GameConstants.weaponBobaPath,
        damage: 32.0,
        fireCooldown: 0.28,
        bulletSpeed: 470.0,
        bulletCount: 1,
        bulletColor: Colors.lightGreenAccent,
      ),
      secondaryWeapon: WeaponInfo(
        name: 'Laptop Phân Tích',
        assetPath: 'assets/images/${GameConstants.weaponLaptopPath}',
        flamePath: GameConstants.weaponLaptopPath,
        damage: 19.0,
        fireCooldown: 0.45,
        bulletSpeed: 450.0,
        bulletCount: 3,
        spreadAngleRadians: 0.42,
        bulletColor: Color(0xFF69F0AE),
      ),
      maxHp: 140.0,
      moveSpeed: 165.0,
      damageMultiplier: 1.0,
      themeColor: Colors.lightGreenAccent,
    ),
    PlayerClassInfo(
      type: PlayerClassType.eco,
      name: 'Sinh Viên Kinh Tế',
      department: 'Khoa Quản Trị Kinh Doanh',
      description: 'Nhanh nhạy & linh hoạt! Di chuyển +20%. Trang bị USB Dữ Liệu & Bút Ký.',
      spriteAssetPath: 'assets/images/${GameConstants.playerEcoPath}',
      flameSpritePath: GameConstants.playerEcoPath,
      initialWeaponName: 'USB Dữ Liệu',
      initialWeaponAssetPath: 'assets/images/${GameConstants.weaponUsbPath}',
      flameWeaponPath: GameConstants.weaponUsbPath,
      primaryWeapon: WeaponInfo(
        name: 'USB Dữ Liệu',
        assetPath: 'assets/images/${GameConstants.weaponUsbPath}',
        flamePath: GameConstants.weaponUsbPath,
        damage: 24.0,
        fireCooldown: 0.19,
        bulletSpeed: 540.0,
        bulletCount: 1,
        bulletColor: Colors.amberAccent,
      ),
      secondaryWeapon: WeaponInfo(
        name: 'Bút Ký Hợp Đồng',
        assetPath: 'assets/images/${GameConstants.weaponPenPath}',
        flamePath: GameConstants.weaponPenPath,
        damage: 36.0,
        fireCooldown: 0.38,
        bulletSpeed: 580.0,
        bulletCount: 2,
        spreadAngleRadians: 0.18,
        bulletColor: Color(0xFFFFD54F),
      ),
      maxHp: 90.0,
      moveSpeed: 218.0,
      damageMultiplier: 1.0,
      themeColor: Colors.amberAccent,
    ),
  ];

  static PlayerClassInfo getByType(PlayerClassType type) {
    return availableClasses.firstWhere((element) => element.type == type);
  }
}
