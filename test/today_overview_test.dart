import 'package:dev_mobile/src/features/crm/home/today_overview.dart';
import 'package:dev_mobile/src/models/activity.dart';
import 'package:dev_mobile/src/models/completed_item.dart';
import 'package:dev_mobile/src/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('today overview prioritizes open overdue and scheduled work', () {
    final now = DateTime(2026, 9, 2, 12);
    final overview = TodayOverview.from(
      now: now,
      tasks: [
        _task('later', DateTime(2026, 9, 2, 16)),
        _task('overdue', DateTime(2026, 9, 1, 9)),
        _task('done', DateTime(2026, 9, 2, 8), TaskStatus.done),
      ],
      todayActivities: [
        _activity('later-job', startsAt: DateTime(2026, 9, 2, 15)),
        _activity('next-visit', startsAt: DateTime(2026, 9, 2, 13)),
        _activity(
          'closed-job',
          startsAt: DateTime(2026, 9, 2, 10),
          status: ActivityStatus.closed,
        ),
      ],
      allActivities: [
        _activity('z-unscheduled'),
        _activity('a-unscheduled'),
        _activity('scheduled', startsAt: DateTime(2026, 9, 3, 9)),
      ],
    );

    expect(overview.overdueTasks.map((item) => item.id), ['overdue']);
    expect(overview.todayTasks.map((item) => item.id), ['later']);
    expect(overview.todayActivities.map((item) => item.id), [
      'next-visit',
      'later-job',
    ]);
    expect(overview.unscheduledActivities.map((item) => item.id), [
      'a-unscheduled',
      'z-unscheduled',
    ]);
    expect(overview.priority.task?.id, 'overdue');
    expect(overview.priority.activity, isNull);
  });

  test(
    'today overview chooses the earliest scheduled item when none are late',
    () {
      final overview = TodayOverview.from(
        now: DateTime(2026, 9, 2, 8),
        tasks: [_task('task', DateTime(2026, 9, 2, 12))],
        todayActivities: [
          _activity('visit', startsAt: DateTime(2026, 9, 2, 10)),
        ],
        allActivities: const [],
      );

      expect(overview.priority.task, isNull);
      expect(overview.priority.activity?.id, 'visit');
    },
  );

  test('today overview keeps undated work visible and exposes completions', () {
    final completedTask = _task(
      'completed-task',
      DateTime(2026, 9, 1, 9),
      TaskStatus.done,
      DateTime(2026, 9, 2, 11),
    );
    final overview = TodayOverview.from(
      now: DateTime(2026, 9, 2, 12),
      tasks: [_task('undated', null), completedTask],
      todayActivities: const [],
      allActivities: const [],
      completedItems: [CompletedItem.task(completedTask)],
    );

    expect(overview.undatedTasks.map((item) => item.id), ['undated']);
    expect(overview.priority.task?.id, 'undated');
    expect(overview.completedItems.single.title, 'completed-task');
  });

  test(
    'today overview keeps older completed work with an open balance visible',
    () {
      final todayCompletion = _activity(
        'today-payment',
        executionCompletedAt: DateTime(2026, 9, 2, 9),
      );
      final olderCompletion = _activity(
        'older-payment',
        executionCompletedAt: DateTime(2026, 9, 1, 18),
      );
      final overview = TodayOverview.from(
        now: DateTime(2026, 9, 2, 12),
        tasks: const [],
        todayActivities: const [],
        allActivities: const [],
        awaitingPaymentActivities: [todayCompletion, olderCompletion],
        completedItems: [CompletedItem.activity(todayCompletion)],
      );

      expect(overview.awaitingPaymentActivities.map((item) => item.id), [
        'older-payment',
      ]);
      expect(overview.completedItems.single.title, 'today-payment');
    },
  );
}

Task _task(
  String id,
  DateTime? dueAt, [
  TaskStatus status = TaskStatus.open,
  DateTime? completedAt,
]) => Task(
  id: id,
  title: id,
  status: status,
  dueAt: dueAt,
  completedAt: completedAt,
  version: 1,
);

Activity _activity(
  String id, {
  DateTime? startsAt,
  DateTime? executionCompletedAt,
  ActivityStatus status = ActivityStatus.open,
}) => Activity(
  id: id,
  kind: id.contains('visit') ? ActivityKind.visit : ActivityKind.job,
  customerId: 'customer',
  title: id,
  status: status,
  startsAt: startsAt,
  executionCompletedAt: executionCompletedAt,
  version: 1,
);
