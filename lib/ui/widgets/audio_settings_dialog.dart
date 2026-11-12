import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../services/audio_settings_service.dart';

/// Hộp thoại cài đặt âm thanh: bật/tắt nhạc nền, bật/tắt hiệu ứng và kéo chỉnh âm lượng
class AudioSettingsDialog extends StatelessWidget {
  const AudioSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const AudioSettingsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = AudioSettingsService.instance;

    return Dialog(
      backgroundColor: GameConstants.cardColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: GameConstants.cardBorderColor,
          width: 2,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: ListenableBuilder(
            listenable: audio,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        color: GameConstants.accentColor,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'CÀI ĐẶT ÂM THANH',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('close_audio_settings_button'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                        tooltip: 'Đóng',
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 14),
                  // Nhạc nền (BGM)
                  _AudioChannelControl(
                    switchKey: const Key('bgm_toggle_switch'),
                    sliderKey: const Key('bgm_volume_slider'),
                    icon: audio.musicEnabled
                        ? Icons.music_note_rounded
                        : Icons.music_off_rounded,
                    label: 'Nhạc nền',
                    enabled: audio.musicEnabled,
                    volume: audio.musicVolume,
                    accentColor: GameConstants.accentColor,
                    onToggle: audio.setMusicEnabled,
                    onVolumeChanged: audio.setMusicVolume,
                  ),
                  const SizedBox(height: 10),
                  // Hiệu ứng âm thanh (SFX)
                  _AudioChannelControl(
                    switchKey: const Key('sfx_toggle_switch'),
                    sliderKey: const Key('sfx_volume_slider'),
                    icon: audio.sfxEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    label: 'Hiệu ứng âm thanh',
                    enabled: audio.sfxEnabled,
                    volume: audio.sfxVolume,
                    accentColor: GameConstants.dashCyanColor,
                    onToggle: audio.setSfxEnabled,
                    onVolumeChanged: audio.setSfxVolume,
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: () {
                          audio.playUiClick();
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GameConstants.accentColor,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'XONG',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AudioChannelControl extends StatelessWidget {
  final Key switchKey;
  final Key sliderKey;
  final IconData icon;
  final String label;
  final bool enabled;
  final double volume;
  final Color accentColor;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onVolumeChanged;

  const _AudioChannelControl({
    required this.switchKey,
    required this.sliderKey,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.volume,
    required this.accentColor,
    required this.onToggle,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (volume * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled ? accentColor.withValues(alpha: 0.4) : Colors.white12,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: enabled ? accentColor : Colors.white38, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: enabled ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Text(
                enabled ? '$pct%' : 'Tắt',
                style: TextStyle(
                  color: enabled ? accentColor : Colors.white38,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Switch(
                key: switchKey,
                value: enabled,
                activeThumbColor: accentColor,
                onChanged: onToggle,
              ),
            ],
          ),
          SizedBox(
            height: 28,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: enabled ? accentColor : Colors.white24,
                inactiveTrackColor: Colors.white12,
                thumbColor: enabled ? accentColor : Colors.white38,
                trackHeight: 4,
              ),
              child: Slider(
                key: sliderKey,
                value: volume,
                onChanged: enabled ? onVolumeChanged : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
