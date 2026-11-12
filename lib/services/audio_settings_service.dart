import 'dart:io' show Platform;
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

/// Quản lý cài đặt bật/tắt và âm lượng Nhạc nền (BGM) & Hiệu ứng âm thanh (SFX)
class AudioSettingsService extends ChangeNotifier {
  AudioSettingsService._();

  static final AudioSettingsService instance = AudioSettingsService._();

  static const String _musicEnabledKey = 'huit_audio_music_enabled';
  static const String _sfxEnabledKey = 'huit_audio_sfx_enabled';
  static const String _musicVolumeKey = 'huit_audio_music_volume';
  static const String _sfxVolumeKey = 'huit_audio_sfx_volume';

  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  double _musicVolume = 0.65;
  double _sfxVolume = 0.85;
  bool _initialized = false;
  bool _bgmStarted = false;

  bool get musicEnabled => _musicEnabled;
  bool get sfxEnabled => _sfxEnabled;
  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  double get effectiveMusicVolume => _musicEnabled ? _musicVolume : 0.0;
  double get effectiveSfxVolume => _sfxEnabled ? _sfxVolume : 0.0;

  bool get _isTestEnvironment =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _musicEnabled = prefs.getBool(_musicEnabledKey) ?? true;
      _sfxEnabled = prefs.getBool(_sfxEnabledKey) ?? true;
      _musicVolume = (prefs.getDouble(_musicVolumeKey) ?? 0.65).clamp(0.0, 1.0);
      _sfxVolume = (prefs.getDouble(_sfxVolumeKey) ?? 0.85).clamp(0.0, 1.0);
      notifyListeners();
    } catch (_) {
      // An toàn khi chạy trong môi trường test không mock SharedPreferences
    }
  }

  Future<void> ensureBgmPlaying() async {
    await init();
    if (_isTestEnvironment || !_musicEnabled || _musicVolume <= 0.0) {
      return;
    }
    try {
      FlameAudio.bgm.initialize();
      if (!_bgmStarted) {
        _bgmStarted = true;
        await FlameAudio.bgm.play(
          GameConstants.bgmThemeAudio,
          volume: _musicVolume,
        );
      } else {
        await FlameAudio.bgm.audioPlayer.setVolume(_musicVolume);
        await FlameAudio.bgm.resume();
      }
    } catch (_) {}
  }

  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    notifyListeners();
    await _savePrefBool(_musicEnabledKey, enabled);
    if (_isTestEnvironment) {
      return;
    }
    try {
      if (!enabled) {
        await FlameAudio.bgm.pause();
      } else {
        await ensureBgmPlaying();
      }
    } catch (_) {}
  }

  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
    notifyListeners();
    await _savePrefBool(_sfxEnabledKey, enabled);
  }

  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume.clamp(0.0, 1.0);
    if (_musicVolume > 0 && !_musicEnabled) {
      _musicEnabled = true;
      await _savePrefBool(_musicEnabledKey, true);
    }
    notifyListeners();
    await _savePrefDouble(_musicVolumeKey, _musicVolume);
    if (_isTestEnvironment) {
      return;
    }
    try {
      if (_bgmStarted) {
        await FlameAudio.bgm.audioPlayer.setVolume(effectiveMusicVolume);
        if (_musicVolume <= 0) {
          await FlameAudio.bgm.pause();
        } else if (_musicEnabled) {
          await FlameAudio.bgm.resume();
        }
      } else if (_musicEnabled && _musicVolume > 0) {
        await ensureBgmPlaying();
      }
    } catch (_) {}
  }

  Future<void> setSfxVolume(double volume) async {
    _sfxVolume = volume.clamp(0.0, 1.0);
    if (_sfxVolume > 0 && !_sfxEnabled) {
      _sfxEnabled = true;
      await _savePrefBool(_sfxEnabledKey, true);
    }
    notifyListeners();
    await _savePrefDouble(_sfxVolumeKey, _sfxVolume);
  }

  void playUiClick() => _playSfx(GameConstants.sfxUiAudio);
  void playShoot() => _playSfx(GameConstants.sfxShootAudio);
  void playDash() => _playSfx(GameConstants.sfxDashAudio);

  void _playSfx(String file) {
    if (_isTestEnvironment || !_sfxEnabled || _sfxVolume <= 0.0) {
      return;
    }
    try {
      FlameAudio.play(file, volume: _sfxVolume);
    } catch (_) {}
  }

  Future<void> _savePrefBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  Future<void> _savePrefDouble(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (_) {}
  }
}
