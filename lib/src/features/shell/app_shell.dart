import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/state/data_invalidator.dart';
import '../../theme/app_theme.dart';
import '../auth/session_controller.dart';
import '../more/more_screen.dart';
import '../voice/assistant_conversation_screen.dart';
import '../voice/voice_command_recorder.dart';
import '../voice/voice_recording_status_card.dart';
import '../v2/v2_customers_screen.dart';
import '../v2/v2_calendar_screen.dart';
import '../v2/v2_home_screen.dart';
import '../v2/v2_pending_actions_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final SessionController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  final VoiceCommandRecorder _voiceRecorder = VoiceCommandRecorder();
  final List<AssistantConversationEntry> _conversation = [];
  Future<int>? _pendingActionsCountFuture;
  late int _seenDataVersion;

  @override
  void initState() {
    super.initState();
    _seenDataVersion = widget.controller.dataInvalidator.revision(DataScope.ai);
    widget.controller.dataInvalidator.addListener(_handleDataChanged);
    WidgetsBinding.instance.addObserver(this);
    _voiceRecorder.addListener(_handleVoiceChanged);
    _loadPendingActionsCount(notify: false);
  }

  @override
  void dispose() {
    widget.controller.dataInvalidator.removeListener(_handleDataChanged);
    WidgetsBinding.instance.removeObserver(this);
    _voiceRecorder.removeListener(_handleVoiceChanged);
    _voiceRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      V2HomeScreen(controller: widget.controller),
      V2CalendarScreen(controller: widget.controller),
      V2CustomersScreen(controller: widget.controller),
      MoreScreen(
        controller: widget.controller,
        pendingActionsCountFuture: _pendingActionsCountFuture,
      ),
      AssistantConversationScreen(
        controller: widget.controller,
        recorder: _voiceRecorder,
        entries: List.unmodifiable(_conversation),
        onSubmitText: _submitText,
        onOpenPendingActions: _openPendingActions,
        onResolved: _handleAssistantResolved,
        pendingActionsCountFuture: _pendingActionsCountFuture,
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: pages),
          PositionedDirectional(
            start: 16,
            end: 16,
            bottom: 16,
            child: VoiceRecordingStatusCard(
              recorder: _voiceRecorder,
              onStopAndSubmit: _finishVoiceAndSubmit,
              onCancel: _cancelVoice,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BrandedBottomNavigation(
        selectedIndex: _index,
        voicePhase: _voiceRecorder.phase,
        onDestinationSelected: _selectDestination,
        onVoicePressed: _handlePrimaryVoicePressed,
        onVoiceLongPressStart: _startGlobalPushToTalk,
        onVoiceLongPressEnd: _finishGlobalPushToTalk,
      ),
    );
  }

  void _handleVoiceChanged() {
    if (mounted) setState(() {});
  }

  void _startVoice() {
    _voiceRecorder.start(widget.controller);
  }

  void _cancelVoice() {
    _voiceRecorder.cancel();
  }

  void _startGlobalPushToTalk() {
    HapticFeedback.mediumImpact();
    _voiceRecorder.start(widget.controller);
  }

  void _finishGlobalPushToTalk() {
    // A long press starts hands-free recording. The explicit "סיים ושלח"
    // action ends it so the user can keep reading the live transcript.
  }

  Future<void> _finishVoiceAndSubmit() async {
    if (!_voiceRecorder.recording) return;
    if (mounted) setState(() => _index = 4);
    final upload = await _voiceRecorder.stopAndSubmit(widget.controller);
    final transcript = _voiceRecorder.reviewTranscript;
    _appendConversation(transcript, upload);
  }

  void _handlePrimaryVoicePressed() {
    HapticFeedback.selectionClick();
    if (_voiceRecorder.recording) {
      _finishVoiceAndSubmit();
      return;
    }
    if (_index == 4) {
      _startVoice();
    } else {
      setState(() => _index = 4);
    }
  }

  void _selectDestination(int value) {
    if (_index == value) return;
    setState(() => _index = value);
    if (value <= 2) {
      widget.controller.markDataChanged({DataScope.crm});
    } else if (value == 3) {
      widget.controller.markDataChanged({
        DataScope.calls,
        DataScope.ai,
        DataScope.settings,
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.markDataChanged(DataScope.values.toSet());
    }
  }

  Future<void> _submitText(String transcript) async {
    final upload = await _voiceRecorder.submitTextCommand(
      widget.controller,
      transcript,
    );
    _appendConversation(transcript, upload);
  }

  void _appendConversation(
    String transcript,
    VoiceCommandUploadResult? upload,
  ) {
    if (!mounted || upload == null) return;
    setState(() {
      _index = 4;
      _conversation.add(
        AssistantConversationEntry(
          transcript: transcript,
          result: upload.result,
          actionBatchId: upload.actionBatchId,
        ),
      );
    });
    _voiceRecorder.acknowledgeResult();
    _loadPendingActionsCount();
  }

  Future<void> _openPendingActions() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => V2PendingActionsScreen(controller: widget.controller),
      ),
    );
    _handleAssistantResolved();
  }

  void _handleAssistantResolved() {
    widget.controller.markDataChanged({DataScope.crm, DataScope.ai});
    _loadPendingActionsCount();
  }

  void _handleDataChanged() {
    if (!mounted) return;
    final currentVersion = widget.controller.dataInvalidator.revision(
      DataScope.ai,
    );
    if (currentVersion == _seenDataVersion) return;
    _seenDataVersion = currentVersion;
    _loadPendingActionsCount();
  }

  void _loadPendingActionsCount({bool notify = true}) {
    final session = widget.controller.session;
    if (session?.businessId == null) return;
    final nextFuture = widget.controller.apiClient.v2Assistant
        .listPending(
          businessId: session!.businessId!,
          firebaseUid: session.firebaseUid,
          mockPhoneNumber: session.mockPhoneNumber,
        )
        .then((json) => (json['totalCount'] as num?)?.toInt() ?? 0);
    if (!notify) {
      _pendingActionsCountFuture = nextFuture;
      return;
    }
    setState(() => _pendingActionsCountFuture = nextFuture);
  }
}

class _BrandedBottomNavigation extends StatelessWidget {
  const _BrandedBottomNavigation({
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

    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: Colors.black12,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
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
                  offset: const Offset(0, -12),
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
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                color: recording
                                    ? AppColors.accent
                                    : AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: assistantSelected
                                      ? AppColors.primaryContainer
                                      : Colors.white,
                                  width: assistantSelected ? 5 : 4,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x26000000),
                                    blurRadius: 14,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: busy
                                  ? const Padding(
                                      padding: EdgeInsets.all(19),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
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
                                        color: Colors.white,
                                        size: 31,
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
            width: 52,
            height: 32,
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
