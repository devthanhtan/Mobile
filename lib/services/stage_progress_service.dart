import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stage_info.dart';

/// Quản lý tiến trình mở khóa màn chơi (phải vượt qua màn trước mới mở màn sau)
class StageProgressService extends ChangeNotifier {
  StageProgressService._();

  static final StageProgressService instance = StageProgressService._();

  static const String _unlockedIndexKey = 'huit_unlocked_max_stage_index';
  static const String _completedIdsKey = 'huit_completed_stage_ids';

  int _unlockedMaxIndex = 0; // Mặc định chỉ mở Màn 1-1 (index 0)
  final Set<String> _completedStageIds = {};
  bool _initialized = false;

  int get unlockedMaxIndex => _unlockedMaxIndex;
  Set<String> get completedStageIds => Set.unmodifiable(_completedStageIds);

  bool isStageUnlockedByIndex(int index) {
    return index >= 0 &&
        index < StageInfo.availableStages.length &&
        index <= _unlockedMaxIndex;
  }

  bool isStageUnlocked(StageInfo stage) {
    final idx = StageInfo.availableStages.indexWhere((s) => s.id == stage.id);
    return isStageUnlockedByIndex(idx);
  }

  bool isStageCompleted(StageInfo stage) {
    return _completedStageIds.contains(stage.id);
  }

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await reloadFromStorage();
  }

  Future<void> reloadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final maxPossible = StageInfo.availableStages.length - 1;
      _unlockedMaxIndex = (prefs.getInt(_unlockedIndexKey) ?? 0).clamp(
        0,
        maxPossible,
      );
      final savedCompleted = prefs.getStringList(_completedIdsKey) ?? const [];
      _completedStageIds
        ..clear()
        ..addAll(savedCompleted);
      notifyListeners();
    } catch (_) {}
  }

  /// Đánh dấu đã hoàn thành màn hiện tại và mở khóa màn kế tiếp (nếu có)
  Future<void> markStageCompleted(StageInfo stage) async {
    await init();
    final idx = StageInfo.availableStages.indexWhere((s) => s.id == stage.id);
    if (idx < 0) {
      return;
    }
    _completedStageIds.add(stage.id);
    final maxPossible = StageInfo.availableStages.length - 1;
    final nextIndex = math.min(maxPossible, idx + 1);
    if (nextIndex > _unlockedMaxIndex) {
      _unlockedMaxIndex = nextIndex;
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unlockedIndexKey, _unlockedMaxIndex);
      await prefs.setStringList(_completedIdsKey, _completedStageIds.toList());
    } catch (_) {}
  }

  @visibleForTesting
  Future<void> resetProgressForTest({int unlockedMaxIndex = 0}) async {
    _initialized = true;
    _unlockedMaxIndex = unlockedMaxIndex.clamp(
      0,
      StageInfo.availableStages.length - 1,
    );
    _completedStageIds.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unlockedIndexKey, _unlockedMaxIndex);
      await prefs.setStringList(_completedIdsKey, const []);
    } catch (_) {}
  }
}

