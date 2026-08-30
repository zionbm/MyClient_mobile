part of 'work_item_form_screen.dart';

class _TopFormActions extends StatelessWidget {
  const _TopFormActions({
    required this.saving,
    required this.onSave,
    required this.onCancel,
  });

  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              minimumSize: const Size(56, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('שמור'),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: saving ? null : onCancel,
            style: TextButton.styleFrom(
              minimumSize: const Size(52, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('ביטול'),
          ),
        ],
      ),
    );
  }
}

class _StatusOption {
  const _StatusOption(this.value, this.label);

  final String value;
  final String label;
}
