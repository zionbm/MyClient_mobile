import '../../../api/api_client.dart';
import '../../../models/session.dart';
import '../../../models/v2_activity.dart';
import '../../../models/v2_completed_item.dart';
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
    final activitiesFuture = _apiClient.v2Activities.schedule(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      from: from,
      to: next,
    );
    final tasksFuture = _apiClient.v2Tasks.listAll(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      state: 'OPEN',
      dueBefore: next,
      includeUndated: true,
    );
    final jobsFuture = _apiClient.v2Activities.listAll(
      kind: V2ActivityKind.job,
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      status: 'OPEN',
      scheduled: false,
      executed: false,
    );
    final visitsFuture = _apiClient.v2Activities.listAll(
      kind: V2ActivityKind.visit,
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      status: 'OPEN',
      scheduled: false,
      executed: false,
    );
    final awaitingPaymentJobsFuture = _apiClient.v2Activities.listAll(
      kind: V2ActivityKind.job,
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      status: 'OPEN',
      executed: true,
    );
    final awaitingPaymentVisitsFuture = _apiClient.v2Activities.listAll(
      kind: V2ActivityKind.visit,
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      status: 'OPEN',
      executed: true,
    );
    final completedItemsFuture = _apiClient.v2Activities.completed(
      businessId: session.businessId!,
      firebaseUid: session.firebaseUid,
      mockPhoneNumber: session.mockPhoneNumber,
      from: from,
      to: next,
    );
    late List<V2Activity> activities;
    late List<V2Task> tasks;
    late List<V2Activity> jobs;
    late List<V2Activity> visits;
    late List<V2Activity> awaitingPaymentJobs;
    late List<V2Activity> awaitingPaymentVisits;
    late List<V2CompletedItem> completedItems;
    await Future.wait<void>([
      activitiesFuture.then((value) => activities = value),
      tasksFuture.then((value) => tasks = value),
      jobsFuture.then((value) => jobs = value),
      visitsFuture.then((value) => visits = value),
      awaitingPaymentJobsFuture.then((value) => awaitingPaymentJobs = value),
      awaitingPaymentVisitsFuture.then(
        (value) => awaitingPaymentVisits = value,
      ),
      completedItemsFuture.then((value) => completedItems = value),
    ]);
    return V2TodayOverview.from(
      now: now,
      tasks: tasks,
      todayActivities: activities,
      allActivities: [...jobs, ...visits],
      awaitingPaymentActivities: [
        ...awaitingPaymentJobs,
        ...awaitingPaymentVisits,
      ],
      completedItems: completedItems,
    );
  }
}

class V2TodayOverview {
  const V2TodayOverview({
    this.overdueTasks = const [],
    this.todayTasks = const [],
    this.undatedTasks = const [],
    this.todayActivities = const [],
    this.unscheduledActivities = const [],
    this.awaitingPaymentActivities = const [],
    this.completedItems = const [],
  });

  final List<V2Task> overdueTasks;
  final List<V2Task> todayTasks;
  final List<V2Task> undatedTasks;
  final List<V2Activity> todayActivities;
  final List<V2Activity> unscheduledActivities;
  final List<V2Activity> awaitingPaymentActivities;
  final List<V2CompletedItem> completedItems;

  ({V2Task? task, V2Activity? activity}) get priority {
    if (overdueTasks.isNotEmpty) {
      return (task: overdueTasks.first, activity: null);
    }
    final task = todayTasks.firstOrNull ?? undatedTasks.firstOrNull;
    final activity = todayActivities.firstOrNull;
    if (task == null && activity == null) {
      return (task: null, activity: unscheduledActivities.firstOrNull);
    }
    if (task == null) return (task: null, activity: activity);
    if (activity == null) return (task: task, activity: null);
    final taskTime = task.dueAt?.toLocal();
    final activityTime = activity.startsAt?.toLocal();
    if (taskTime == null || activityTime == null) {
      return (task: task, activity: null);
    }
    return taskTime.isBefore(activityTime)
        ? (task: task, activity: null)
        : (task: null, activity: activity);
  }

  factory V2TodayOverview.from({
    required DateTime now,
    required List<V2Task> tasks,
    required List<V2Activity> todayActivities,
    required List<V2Activity> allActivities,
    List<V2Activity> awaitingPaymentActivities = const [],
    List<V2CompletedItem> completedItems = const [],
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
    final undated = openTasks
        .where((task) => task.dueAt == null)
        .toList(growable: false);
    final scheduled =
        todayActivities
            .where(
              (item) =>
                  item.status == V2ActivityStatus.open &&
                  item.executionCompletedAt == null,
            )
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
                  item.status == V2ActivityStatus.open &&
                  item.startsAt == null &&
                  item.executionCompletedAt == null,
            )
            .toList()
          ..sort((left, right) => left.title.compareTo(right.title));
    return V2TodayOverview(
      overdueTasks: overdue,
      todayTasks: dueToday,
      undatedTasks: undated,
      todayActivities: scheduled,
      unscheduledActivities: unscheduled,
      awaitingPaymentActivities:
          awaitingPaymentActivities
              .where(
                (item) =>
                    item.executionCompletedAt != null &&
                    item.executionCompletedAt!.toLocal().isBefore(today),
              )
              .toList()
            ..sort(
              (left, right) => right.executionCompletedAt!.compareTo(
                left.executionCompletedAt!,
              ),
            ),
      completedItems: completedItems,
    );
  }
}
