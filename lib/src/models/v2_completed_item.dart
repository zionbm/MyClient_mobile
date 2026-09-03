import 'v2_activity.dart';
import 'v2_task.dart';

class V2CompletedItem {
  const V2CompletedItem._({
    required this.completedAt,
    this.task,
    this.activity,
  });

  factory V2CompletedItem.task(V2Task task) =>
      V2CompletedItem._(task: task, completedAt: task.completedAt!);

  factory V2CompletedItem.activity(V2Activity activity) => V2CompletedItem._(
    activity: activity,
    completedAt: activity.executionCompletedAt!,
  );

  final V2Task? task;
  final V2Activity? activity;
  final DateTime completedAt;

  String get title => task?.title ?? activity!.title;
  String? get customerName => task?.customerName ?? activity?.customerName;
  String get kindLabel => task != null ? 'משימה' : activity!.kind.hebrewLabel;
}
