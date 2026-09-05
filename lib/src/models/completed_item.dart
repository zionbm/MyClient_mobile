import 'activity.dart';
import 'task.dart';

class CompletedItem {
  const CompletedItem._({required this.completedAt, this.task, this.activity});

  factory CompletedItem.task(Task task) =>
      CompletedItem._(task: task, completedAt: task.completedAt!);

  factory CompletedItem.activity(Activity activity) => CompletedItem._(
    activity: activity,
    completedAt: activity.executionCompletedAt!,
  );

  final Task? task;
  final Activity? activity;
  final DateTime completedAt;

  String get title => task?.title ?? activity!.title;
  String? get customerName => task?.customerName ?? activity?.customerName;
  String get kindLabel => task != null ? 'משימה' : activity!.kind.hebrewLabel;
}
