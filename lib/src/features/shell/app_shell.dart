import 'package:flutter/material.dart';

import '../../core/state/data_invalidator.dart';
import '../auth/session_controller.dart';
import '../calls/calls_screen.dart';
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

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final VoiceCommandRecorder _voiceRecorder = VoiceCommandRecorder();
  final List<AssistantConversationEntry> _conversation = [];
  Future<int>? _pendingActionsCountFuture;
  late int _seenDataVersion;
  bool _releaseRequested = false;

  @override
  void initState() {
    super.initState();
    _seenDataVersion = widget.controller.dataInvalidator.revision(DataScope.ai);
    widget.controller.dataInvalidator.addListener(_handleDataChanged);
    _voiceRecorder.addListener(_handleVoiceChanged);
    _loadPendingActionsCount(notify: false);
  }

  @override
  void dispose() {
    widget.controller.dataInvalidator.removeListener(_handleDataChanged);
    _voiceRecorder.removeListener(_handleVoiceChanged);
    _voiceRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      V2HomeScreen(
        controller: widget.controller,
        onOpenCalendar: () => setState(() => _index = 5),
      ),
      V2CustomersScreen(controller: widget.controller),
      CallsScreen(
        controller: widget.controller,
        pendingActionsCountFuture: _pendingActionsCountFuture,
      ),
      MoreScreen(
        controller: widget.controller,
        pendingActionsCountFuture: _pendingActionsCountFuture,
      ),
      AssistantConversationScreen(
        controller: widget.controller,
        recorder: _voiceRecorder,
        entries: List.unmodifiable(_conversation),
        onSubmitText: _submitText,
        onStartVoice: _startVoice,
        onStopVoice: _voiceRecorder.stopForReview,
        onCancelVoice: _cancelVoice,
        onOpenPendingActions: _openPendingActions,
        onResolved: _handleAssistantResolved,
      ),
      V2CalendarScreen(controller: widget.controller),
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
              onStopForReview: _voiceRecorder.stopForReview,
              onSubmit: _submitReviewedVoice,
              onRecordAgain: _startVoice,
              onCancel: _cancelVoice,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BrandedBottomNavigation(
        selectedIndex: _index,
        voicePhase: _voiceRecorder.phase,
        onDestinationSelected: (value) => setState(() => _index = value),
        onVoicePressed: () => setState(() => _index = 4),
        onVoiceLongPressStart: _startGlobalPushToTalk,
        onVoiceLongPressEnd: _finishGlobalPushToTalk,
      ),
    );
  }

  void _handleVoiceChanged() {
    if (_releaseRequested && _voiceRecorder.recording) {
      _releaseRequested = false;
      _voiceRecorder.stopForReview();
    }
    if (mounted) setState(() {});
  }

  void _startVoice() {
    _releaseRequested = false;
    _voiceRecorder.start(widget.controller);
  }

  void _cancelVoice() {
    _releaseRequested = false;
    _voiceRecorder.cancel();
  }

  void _startGlobalPushToTalk() {
    setState(() => _index = 4);
    _releaseRequested = false;
    _voiceRecorder.start(widget.controller);
  }

  void _finishGlobalPushToTalk() {
    if (_voiceRecorder.recording) {
      _voiceRecorder.stopForReview();
    } else if (_voiceRecorder.preparing) {
      _releaseRequested = true;
    }
  }

  Future<void> _submitReviewedVoice() async {
    final transcript = _voiceRecorder.reviewTranscript;
    final upload = await _voiceRecorder.submitReviewedTranscript(
      widget.controller,
    );
    _appendConversation(transcript, upload);
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
                  label: 'בית',
                  selected: selectedIndex == 0,
                  onTap: () => onDestinationSelected(0),
                ),
              ),
              Expanded(
                child: _BottomDestination(
                  icon: Icons.people_alt_outlined,
                  selectedIcon: Icons.people_alt,
                  label: 'לקוחות',
                  selected: selectedIndex == 1,
                  onTap: () => onDestinationSelected(1),
                ),
              ),
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -18),
                  child: Semantics(
                    button: true,
                    label: recording
                        ? 'עצור לבדיקת התמלול'
                        : busy
                        ? 'מעבד הקלטה'
                        : 'פקודה קולית',
                    child: GestureDetector(
                      onLongPressStart: busy
                          ? null
                          : (_) => onVoiceLongPressStart(),
                      onLongPressEnd: busy
                          ? null
                          : (_) => onVoiceLongPressEnd(),
                      child: InkResponse(
                        onTap: busy ? null : onVoicePressed,
                        radius: 38,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: recording
                                ? const Color(0xFFF06449)
                                : const Color(0xFF073F43),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
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
                                  padding: EdgeInsets.all(21),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 150),
                                  child: Icon(
                                    recording
                                        ? Icons.stop_rounded
                                        : Icons.mic_none_rounded,
                                    key: ValueKey(recording),
                                    color: Colors.white,
                                    size: 34,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _BottomDestination(
                  icon: Icons.call_outlined,
                  selectedIcon: Icons.call,
                  label: 'שיחות',
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
        ? const Color(0xFF073F43)
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 32,
            height: 3,
            margin: const EdgeInsets.only(bottom: 5),
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(selected ? selectedIcon : icon, color: color, size: 25),
          const SizedBox(height: 2),
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
