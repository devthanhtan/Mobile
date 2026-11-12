import 'package:flutter/material.dart';

/// Mô tả thông số vũ khí người chơi có thể mang và đổi slot trong trận
class WeaponInfo {
  final String name;
  final String assetPath; // assets/images/weapon/... cho Flutter UI
  final String flamePath; // weapon/... cho Flame
  final double damage;
  final double fireCooldown;
  final double bulletSpeed;
  final int bulletCount;
  final double spreadAngleRadians;
  final Color bulletColor;

  const WeaponInfo({
    required this.name,
    required this.assetPath,
    required this.flamePath,
    required this.damage,
    required this.fireCooldown,
    this.bulletSpeed = 480.0,
    this.bulletCount = 1,
    this.spreadAngleRadians = 0.0,
    this.bulletColor = const Color(0xFF00E5FF),
  });
}

