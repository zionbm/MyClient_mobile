import 'package:dev_mobile/src/features/v2/home/v2_today_overview.dart';
import 'package:dev_mobile/src/models/v2_activity.dart';
import 'package:dev_mobile/src/models/v2_task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('today overview prioritizes open overdue and scheduled work', () {
    final now = DateTime(2026, 9, 2, 12);
    final overview = V2TodayOverview.from(
      now: now,
      tasks: [
        _task('later', DateTime(2026, 9, 2, 16)),
        _task('overdue', DateTime(2026, 9, 1, 9)),
        _task('done', DateTime(2026, 9, 2, 8), V2TaskStatus.done),
      ],
      todayActivities: [
        _activity('later-job', startsAt: DateTime(2026, 9, 2, 15)),
        _activity('next-visit', startsAt: DateTime(2026, 9, 2, 13)),
        _activity(
          'closed-job',
          startsAt: DateTime(2026, 9, 2, 10),
          status: V2ActivityStatus.closed,
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
  });
}

V2Task _task(
  String id,
  DateTime dueAt, [
  V2TaskStatus status = V2TaskStatus.open,
]) => V2Task(id: id, title: id, status: status, dueAt: dueAt, version: 1);

V2Activity _activity(
  String id, {
  DateTime? startsAt,
  V2ActivityStatus status = V2ActivityStatus.open,
}) => V2Activity(
  id: id,
  kind: id.contains('visit') ? V2ActivityKind.visit : V2ActivityKind.job,
  customerId: 'customer',
  title: id,
  status: status,
  startsAt: startsAt,
  version: 1,
);
