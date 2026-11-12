import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../models/player_class.dart';
import '../../models/stage_info.dart';
import '../../services/audio_settings_service.dart';
import '../../services/stage_progress_service.dart';

/// Hộp thoại bản đồ thế giới hiển thị tuyến đường chọn màn (1-1, 1-2, 1-3, 1-4) có khóa tiến trình
class StageMapDialog extends StatefulWidget {
  final PlayerClassInfo selectedClass;
  final StageInfo initialStage;

  const StageMapDialog({
    super.key,
    required this.selectedClass,
    required this.initialStage,
  });

  static Future<StageInfo?> show(
    BuildContext context, {
    required PlayerClassInfo selectedClass,
    required StageInfo initialStage,
  }) {
    return showDialog<StageInfo>(
      context: context,
      builder: (_) => StageMapDialog(
        selectedClass: selectedClass,
        initialStage: initialStage,
      ),
    );
  }

  @override
  State<StageMapDialog> createState() => _StageMapDialogState();
}

class _StageMapDialogState extends State<StageMapDialog> {
  late StageInfo _selectedStage;
  final StageProgressService _progress = StageProgressService.instance;

  @override
  void initState() {
    super.initState();
    _selectedStage = _progress.isStageUnlocked(widget.initialStage)
        ? widget.initialStage
        : StageInfo.availableStages[_progress.unlockedMaxIndex];
    _progress.init();
  }

  @override
  Widget build(BuildContext context) {
    final stages = StageInfo.availableStages;

    return ListenableBuilder(
      listenable: _progress,
      builder: (context, _) {
        final selectedIdx = stages.indexWhere(
          (s) => s.id == _selectedStage.id,
        );
        final isSelectedUnlocked = _progress.isStageUnlockedByIndex(
          selectedIdx,
        );
        final prevStageCode = selectedIdx > 0
            ? stages[selectedIdx - 1].stageCode
            : '1-1';

        return Dialog(
          backgroundColor: const Color(0xFF13172B),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: _selectedStage.themeColor.withValues(alpha: 0.75),
              width: 2,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740, maxHeight: 370),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tiêu đề bản đồ chọn màn
                  Row(
                    children: [
                      const Icon(
                        Icons.map_rounded,
                        color: GameConstants.accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'BẢN ĐỒ CHỌN MÀN CHIẾN ĐẤU',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('close_stage_map_button'),
                        onPressed: () {
                          AudioSettingsService.instance.playUiClick();
                          Navigator.of(context).pop(null);
                        },
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Chuỗi nút màn chơi 1-1 -> 1-2 -> 1-3 -> 1-4 nối tuyến (khóa nếu chưa qua màn trước)
                  Expanded(
                    child: Row(
                      children: List.generate(stages.length * 2 - 1, (idx) {
                        if (idx.isOdd) {
                          final rightStageIdx = (idx + 1) ~/ 2;
                          final routeUnlocked = _progress
                              .isStageUnlockedByIndex(rightStageIdx);
                          return Container(
                            width: 18,
                            height: 3,
                            color: routeUnlocked
                                ? Colors.amberAccent.withValues(alpha: 0.7)
                                : Colors.white12,
                          );
                        }
                        final stageIdx = idx ~/ 2;
                        final stage = stages[stageIdx];
                        final isSelected = stage.id == _selectedStage.id;
                        final isUnlocked = _progress.isStageUnlockedByIndex(
                          stageIdx,
                        );
                        final isCompleted = _progress.isStageCompleted(stage);

                        return Expanded(
                          child: GestureDetector(
                            key: Key('stage_node_${stage.stageCode}'),
                            onTap: () {
                              AudioSettingsService.instance.playUiClick();
                              setState(() => _selectedStage = stage);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? (isUnlocked
                                            ? stage.themeColor
                                            : Colors.white54)
                                      : (isUnlocked
                                            ? Colors.white24
                                            : Colors.white10),
                                  width: isSelected ? 2.6 : 1.2,
                                ),
                                boxShadow: isSelected && isUnlocked
                                    ? [
                                        BoxShadow(
                                          color: stage.themeColor.withValues(
                                            alpha: 0.35,
                                          ),
                                          blurRadius: 10,
                                        ),
                                      ]
                                    : null,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ColorFiltered(
                                    colorFilter: isUnlocked
                                        ? const ColorFilter.mode(
                                            Colors.transparent,
                                            BlendMode.dst,
                                          )
                                        : const ColorFilter.mode(
                                            Color(0xAA0A0D18),
                                            BlendMode.srcATop,
                                          ),
                                    child: Image.asset(
                                      stage.mapAssetPath,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.none,
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.28),
                                          Colors.black.withValues(
                                            alpha: isUnlocked ? 0.82 : 0.90,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Mã màn 1-1, 1-2... ở góc trên trái
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected && isUnlocked
                                            ? stage.themeColor
                                            : Colors.black87,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isUnlocked
                                              ? Colors.white54
                                              : Colors.white24,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        stage.stageCode,
                                        style: TextStyle(
                                          color: isSelected && isUnlocked
                                              ? Colors.black
                                              : (isUnlocked
                                                    ? Colors.white
                                                    : Colors.white54),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Icon Khóa / Hoàn thành / Boss ở góc trên phải
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: !isUnlocked
                                        ? Container(
                                            width: 28,
                                            height: 28,
                                            decoration: const BoxDecoration(
                                              color: Colors.black87,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.lock_rounded,
                                              color: Colors.white54,
                                              size: 16,
                                            ),
                                          )
                                        : isCompleted
                                        ? Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.greenAccent,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.check_rounded,
                                              color: Colors.greenAccent,
                                              size: 18,
                                            ),
                                          )
                                        : Container(
                                            width: 28,
                                            height: 28,
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: stage.themeColor,
                                              ),
                                            ),
                                            child: Image.asset(
                                              stage.bossAssetPath,
                                              fit: BoxFit.contain,
                                              filterQuality: FilterQuality.none,
                                            ),
                                          ),
                                  ),
                                  // Biểu tượng ổ khóa trung tâm nếu chưa mở khóa
                                  if (!isUnlocked)
                                    const Center(
                                      child: Icon(
                                        Icons.lock_outline_rounded,
                                        color: Colors.white38,
                                        size: 36,
                                      ),
                                    ),
                                  Positioned(
                                    left: 8,
                                    right: 8,
                                    bottom: 8,
                                    child: Text(
                                      stage.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: !isUnlocked
                                            ? Colors.white38
                                            : (isSelected
                                                  ? stage.themeColor
                                                  : Colors.white),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Dải thông tin màn đã chọn + nút vào trận (hoặc thông báo khóa)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            (isSelectedUnlocked
                                    ? _selectedStage.themeColor
                                    : Colors.white24)
                                .withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          _selectedStage.bossAssetPath,
                          width: 38,
                          height: 38,
                          filterQuality: FilterQuality.none,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Màn ${_selectedStage.stageCode}: ${_selectedStage.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelectedUnlocked
                                      ? _selectedStage.themeColor
                                      : Colors.white54,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                isSelectedUnlocked
                                    ? 'Sinh tồn 05:00 • Boss: ${_selectedStage.bossName}'
                                    : 'Cần hoàn thành Màn $prevStageCode để mở khóa!',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelectedUnlocked
                                      ? Colors.white70
                                      : Colors.orangeAccent,
                                  fontSize: 11.5,
                                  fontWeight: isSelectedUnlocked
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            key: const Key('enter_selected_stage_button'),
                            onPressed: isSelectedUnlocked
                                ? () {
                                    AudioSettingsService.instance.playUiClick();
                                    Navigator.of(context).pop(_selectedStage);
                                  }
                                : null,
                            icon: Icon(
                              isSelectedUnlocked
                                  ? Icons.play_arrow_rounded
                                  : Icons.lock_rounded,
                            ),
                            label: Text(
                              isSelectedUnlocked
                                  ? 'CHIẾN ${_selectedStage.stageCode}'
                                  : 'ĐANG KHÓA',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GameConstants.accentColor,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.white12,
                              disabledForegroundColor: Colors.white38,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
