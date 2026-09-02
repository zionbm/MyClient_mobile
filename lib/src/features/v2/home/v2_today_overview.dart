import '../../../api/api_client.dart';
import '../../../models/page.dart' as pagination;
import '../../../models/session.dart';
import '../../../models/v2_activity.dart';
import '../../../models/v2_task.dart';

/// Combines the repositories needed by the daily work hub.
class V2TodayOverviewLoader {
  const V2TodayOverviewLoader(this._apiClient);

  final ApiClient _apiClient;

  Future<V2TodayOverview> load({
    required AppSession session,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final next = from.add(const Duration(days: 1));
    final values = await Future.wait<Object>([
      _apiClient.v2Activities.schedule(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        from: from,
        to: next,
      ),
      _apiClient.v2Tasks.list(
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
        limit: 50,
      ),
      _apiClient.v2Activities.list(
        kind: V2ActivityKind.job,
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      ),
      _apiClient.v2Activities.list(
        kind: V2ActivityKind.visit,
        businessId: session.businessId!,
        firebaseUid: session.firebaseUid,
        mockPhoneNumber: session.mockPhoneNumber,
      ),
    ]);
    final activities = values[0] as List<V2Activity>;
    final tasks = (values[1] as pagination.Page<V2Task>).items;
    final jobs = (values[2] as pagination.Page<V2Activity>).items;
    final visits = (values[3] as pagination.Page<V2Activity>).items;
    return V2TodayOverview.from(
      now: now,
      tasks: tasks,
      todayActivities: activities,
      allActivities: [...jobs, ...visits],
    );
  }
}

class V2TodayOverview {
  const V2TodayOverview({
    this.overdueTasks = const [],
    this.todayTasks = const [],
    this.todayActivities = const [],
    this.unscheduledActivities = const [],
  });

  final List<V2Task> overdueTasks;
  final List<V2Task> todayTasks;
  final List<V2Activity> todayActivities;
  final List<V2Activity> unscheduledActivities;

  factory V2TodayOverview.from({
    required DateTime now,
    required List<V2Task> tasks,
    required List<V2Activity> todayActivities,
    required List<V2Activity> allActivities,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final openTasks =
        tasks.where((task) => task.status == V2TaskStatus.open).toList()
          ..sort((left, right) {
            if (left.dueAt == null) return 1;
            if (right.dueAt == null) return -1;
            return left.dueAt!.compareTo(right.dueAt!);
          });
    final overdue = openTasks
        .where((task) {
          final due = task.dueAt?.toLocal();
          return due != null && due.isBefore(today);
        })
        .toList(growable: false);
    final dueToday = openTasks
        .where((task) {
          final due = task.dueAt?.toLocal();
          return due != null && !due.isBefore(today) && due.isBefore(tomorrow);
        })
        .toList(growable: false);
    final scheduled =
        todayActivities
            .where((item) => item.status == V2ActivityStatus.open)
            .toList()
          ..sort((left, right) {
            if (left.startsAt == null) return 1;
            if (right.startsAt == null) return -1;
            return left.startsAt!.compareTo(right.startsAt!);
          });
    final unscheduled =
        allActivities
            .where(
              (item) =>
                  item.status == V2ActivityStatus.open && item.startsAt == null,
            )
            .toList()
          ..sort((left, right) => left.title.compareTo(right.title));
    return V2TodayOverview(
      overdueTasks: overdue,
      todayTasks: dueToday,
      todayActivities: scheduled,
      unscheduledActivities: unscheduled,
    );
  }
}
