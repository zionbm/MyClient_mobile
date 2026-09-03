import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

import '../../api/api_client.dart';
import '../../core/network/idempotency_key.dart';
import '../../core/state/data_invalidator.dart';
import '../../services/assistant_speech_player.dart';
import '../../utils/json_read.dart';
import '../auth/session_controller.dart';

class V2RecentActionsScreen extends StatefulWidget {
  const V2RecentActionsScreen({super.key, required this.controller});
  final SessionController controller;

  @override
  State<V2RecentActionsScreen> createState() => _V2RecentActionsScreenState();
}

class _V2RecentActionsScreenState extends State<V2RecentActionsScreen> {
  Future<Map<String, Object?>>? _future;
  String _responseMode = 'TEXT_ONLY';

  @override
  void initState() {
    super.initState();
    _load();
    _loadPreferences();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('היסטוריית פעולות')),
    body: Column(
      children: [
        SwitchListTile(
          title: const Text('הקראת תשובות העוזרת'),
          subtitle: const Text('הטקסט תמיד נשאר מוצג'),
          value: _responseMode == 'TEXT_AND_VOICE',
          onChanged: _changeResponseMode,
        ),
        Expanded(
          child: FutureBuilder<Map<String, Object?>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(
                  child: Text('לא הצלחנו לטעון פעולות אחרונות'),
                );
              }
              final batches = mapListValue(snapshot.data?['actionBatches']);
              if (batches.isEmpty) {
                return const Center(child: Text('עדיין אין פעולות V2'));
              }
              return RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: batches.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) => _batchCard(batches[index]),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _batchCard(Map<String, Object?> batch) {
    final undone = batch['status'] == 'UNDONE';
    final mutationCount =
        (mapValue(batch['_count'])['mutations'] as num?)?.toInt() ?? 0;
    final undoUntil = DateTime.tryParse(
      stringValue(batch['undoEligibleUntil']),
    );
    final canUndo =
        !undone &&
        mutationCount > 0 &&
        undoUntil != null &&
        undoUntil.isAfter(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              stringValue(batch['finalSummary'], fallback: 'פעולת עוזרת'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (nullableString(batch['approvedTranscript'])
                case final transcript?) ...[
              const SizedBox(height: 6),
              Text(
                '״$transcript״',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (_responseMode == 'TEXT_AND_VOICE')
                  TextButton.icon(
                    onPressed: () => _speak(batch),
                    icon: const Icon(Icons.volume_up_outlined),
                    label: const Text('השמעה'),
                  ),
                if (_responseMode == 'TEXT_AND_VOICE')
                  TextButton.icon(
                    onPressed: AssistantSpeechPlayer.stop,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('עצירה'),
                  ),
                if (canUndo)
                  TextButton.icon(
                    onPressed: () => _undo(batch),
                    icon: const Icon(Icons.undo),
                    label: const Text('ביטול פעולה'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    final session = widget.controller.session!;
    setState(() {
      _future = widget.controller.apiClient.v2ActionBatches.list(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
    });
    await _future;
  }

  Future<void> _loadPreferences() async {
    final session = widget.controller.session!;
    final json = await widget.controller.apiClient.v2ActionBatches.preferences(
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
    );
    if (!mounted) return;
    final preferences = mapValue(json['preferences']);
    setState(
      () => _responseMode = stringValue(
        preferences['assistantResponseMode'],
        fallback: 'TEXT_ONLY',
      ),
    );
  }

  Future<void> _changeResponseMode(bool enabled) async {
    final previous = _responseMode;
    setState(() => _responseMode = enabled ? 'TEXT_AND_VOICE' : 'TEXT_ONLY');
    final session = widget.controller.session!;
    try {
      await widget.controller.apiClient.v2ActionBatches.updatePreferences(
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        mode: _responseMode,
      );
      if (!enabled) await AssistantSpeechPlayer.stop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _responseMode = previous);
      _error(error.message);
    }
  }

  Future<void> _undo(Map<String, Object?> batch) async {
    final session = widget.controller.session!;
    try {
      final preview = await widget.controller.apiClient.v2ActionBatches.preview(
        businessId: session.businessId!,
        actionBatchId: stringValue(batch['id']),
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      if (preview['eligible'] != true) {
        return _error(
          stringValue(preview['reason'], fallback: 'לא ניתן לבטל את הפעולה'),
        );
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('ביטול הפעולה'),
          content: Text(
            'הפעולה תשחזר ${preview['mutationCount']} שינויים. להמשיך?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('חזרה'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ביטול הפעולה'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await widget.controller.apiClient.v2ActionBatches.undo(
        businessId: session.businessId!,
        actionBatchId: stringValue(batch['id']),
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        idempotencyKey: IdempotencyKey.create('action_batch_undo'),
      );
      widget.controller.markDataChanged({DataScope.crm, DataScope.ai});
      await _load();
    } on ApiException catch (error) {
      _error(error.message);
    }
  }

  Future<void> _speak(Map<String, Object?> batch) async {
    final session = widget.controller.session!;
    try {
      final speech = await widget.controller.apiClient.v2ActionBatches.speech(
        businessId: session.businessId!,
        actionBatchId: stringValue(batch['id']),
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      );
      final audio = nullableString(speech['audioBase64']);
      if (audio == null) {
        return _error('שירות הקול עדיין במצב הדמיה; הטקסט נשאר זמין.');
      }
      await AssistantSpeechPlayer.playBase64(audio);
    } on Object catch (_) {
      _error('לא הצלחנו להשמיע את התשובה; תוצאת הפעולה לא השתנתה.');
    }
  }

  void _error(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
