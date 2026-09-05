import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/state/data_invalidator.dart';
import '../auth/session_controller.dart';
import '../more/more_screen.dart';
import '../voice/assistant_conversation_screen.dart';
import '../voice/voice_command_recorder.dart';
import '../voice/voice_recording_status_card.dart';
import '../crm/customers_screen.dart';
import '../crm/calendar_screen.dart';
import '../crm/home_screen.dart';
import '../crm/pending_actions_screen.dart';
import 'widgets/branded_bottom_navigation.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final SessionController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  int _previousIndex = 0;
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
      HomeScreen(controller: widget.controller),
      CalendarScreen(controller: widget.controller),
      CustomersScreen(controller: widget.controller),
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

    return PopScope(
      canPop: _index != 4,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index == 4) {
          setState(() => _index = _previousIndex);
        }
      },
      child: Scaffold(
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
        bottomNavigationBar: BrandedBottomNavigation(
          selectedIndex: _index,
          voicePhase: _voiceRecorder.phase,
          onDestinationSelected: _selectDestination,
          onVoicePressed: _handlePrimaryVoicePressed,
          onVoiceLongPressStart: _startGlobalPushToTalk,
          onVoiceLongPressEnd: _finishGlobalPushToTalk,
        ),
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
    if (mounted) _showAssistant();
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
      _showAssistant();
    }
  }

  void _showAssistant() {
    if (_index != 4) _previousIndex = _index;
    setState(() => _index = 4);
  }

  void _selectDestination(int value) {
    if (_index == value) return;
    setState(() {
      _index = value;
      _previousIndex = value;
    });
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
      if (_index != 4) _previousIndex = _index;
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
        builder: (_) => PendingActionsScreen(controller: widget.controller),
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
    final nextFuture = widget.controller.apiClient.assistant
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
