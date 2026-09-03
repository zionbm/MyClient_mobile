import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../voice/voice_command_recorder.dart';

class BrandedBottomNavigation extends StatelessWidget {
  const BrandedBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.voicePhase,
    required this.onDestinationSelected,
    required this.onVoicePressed,
    required this.onVoiceLongPressStart,
    required this.onVoiceLongPressEnd,
  });

  final int selectedIndex;
  final VoiceRecordingPhase voicePhase;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onVoicePressed;
  final VoidCallback onVoiceLongPressStart;
  final VoidCallback onVoiceLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final recording = voicePhase == VoiceRecordingPhase.recording;
    final busy =
        voicePhase == VoiceRecordingPhase.preparing ||
        voicePhase == VoiceRecordingPhase.finalizingTranscript ||
        voicePhase == VoiceRecordingPhase.submitting;
    final assistantSelected = selectedIndex == 4;
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: const Border(top: BorderSide(color: AppColors.border)),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              Expanded(
                child: _BottomDestination(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'היום',
                  selected: selectedIndex == 0,
                  onTap: () => onDestinationSelected(0),
                ),
              ),
              Expanded(
                child: _BottomDestination(
                  icon: Icons.calendar_month_outlined,
                  selectedIcon: Icons.calendar_month,
                  label: 'יומן',
                  selected: selectedIndex == 1,
                  onTap: () => onDestinationSelected(1),
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -6),
                  child: Semantics(
                    button: true,
                    label: recording
                        ? 'סיים ושלח את ההקלטה'
                        : busy
                        ? 'מעבד הקלטה'
                        : 'עוזרת. לחיצה לפתיחת שיחה, לחיצה ארוכה להקלטה',
                    child: GestureDetector(
                      onLongPressStart: busy
                          ? null
                          : (_) => onVoiceLongPressStart(),
                      onLongPressEnd: busy
                          ? null
                          : (_) => onVoiceLongPressEnd(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkResponse(
                            onTap: busy ? null : onVoicePressed,
                            radius: 38,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: recording
                                    ? AppColors.accent
                                    : AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: assistantSelected
                                      ? AppColors.primary
                                      : colors.surface,
                                  width: assistantSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.18,
                                    ),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: busy
                                  ? const Padding(
                                      padding: EdgeInsets.all(17),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppColors.onPrimary,
                                      ),
                                    )
                                  : AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      child: Icon(
                                        recording
                                            ? Icons.stop_rounded
                                            : Icons.mic_none_rounded,
                                        key: ValueKey(recording),
                                        color: recording
                                            ? AppColors.background
                                            : AppColors.onPrimary,
                                        size: 27,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            recording ? 'מקליט' : 'עוזרת',
                            style: TextStyle(
                              color: recording
                                  ? AppColors.accent
                                  : AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _BottomDestination(
                  icon: Icons.people_alt_outlined,
                  selectedIcon: Icons.people_alt,
                  label: 'לקוחות',
                  selected: selectedIndex == 2,
                  onTap: () => onDestinationSelected(2),
                ),
              ),
              Expanded(
                child: _BottomDestination(
                  icon: Icons.more_horiz,
                  selectedIcon: Icons.more,
                  label: 'עוד',
                  selected: selectedIndex == 3,
                  onTap: () => onDestinationSelected(3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomDestination extends StatelessWidget {
  const _BottomDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 46,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(selected ? selectedIcon : icon, color: color, size: 24),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
