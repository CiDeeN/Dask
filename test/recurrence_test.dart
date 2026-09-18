import 'package:flutter_test/flutter_test.dart';

// =====================================================================
// Logic chuẩn (mirror đúng spec + test_verify_recurrence.py).
// Khi app có lib/recurrence.dart, XÓA block này và thay bằng:
//   import 'package:app/recurrence.dart';
// =====================================================================

const int dayMs = 86400000;

int computeNextDue(int lastDone, int cycleDays) =>
    lastDone + cycleDays * dayMs;

int effectiveDue(int nextDue, int? snoozedUntil) =>
    snoozedUntil == null ? nextDue : (nextDue > snoozedUntil ? nextDue : snoozedUntil);

/// diffDays = ceil((effectiveDue - now) / 86400000)
/// <0 overdue | ==0 due_today | ==1 due_grace | 2..7 upcoming | >7 ok
String getStatus(int now, int nextDue, [int? snoozedUntil]) {
  final eff = effectiveDue(nextDue, snoozedUntil);
  final diffDays = ((eff - now) / dayMs).ceil();
  if (diffDays < 0) return 'overdue';
  if (diffDays == 0) return 'due_today';
  if (diffDays == 1) return 'due_grace';
  if (diffDays <= 7) return 'upcoming';
  return 'ok';
}

class DoneResult {
  final String result; // early | done | late
  final int newNextDue;
  DoneResult(this.result, this.newNextDue);
}

DoneResult markDone(int now, int nextDue, int cycleDays) {
  final String r;
  if (now < nextDue - dayMs) {
    r = 'early';
  } else if (now > nextDue) {
    r = 'late';
  } else {
    r = 'done';
  }
  return DoneResult(r, now + cycleDays * dayMs);
}

int skipTask(int nextDue, int cycleDays) => nextDue + cycleDays * dayMs;
int snooze(int now, [int snoozeMs = dayMs]) => now + snoozeMs;
int changeCycle(int lastDone, int newCycleDays) =>
    computeNextDue(lastDone, newCycleDays);

int utc(int y, int m, int d, [int hh = 0, int mm = 0]) =>
    DateTime.utc(y, m, d, hh, mm).millisecondsSinceEpoch;

// =====================================================================

void main() {
  group('computeNextDue', () {
    test('cơ bản: +cycle*86400000', () {
      final last = utc(2024, 1, 1);
      expect(computeNextDue(last, 7), last + 7 * dayMs);
      expect(computeNextDue(last, 1), last + dayMs);
      expect(computeNextDue(last, 180), last + 180 * dayMs);
    });

    test('cycle 1 ngày vs 180 ngày chênh đúng 179 ngày', () {
      final last = utc(2024, 1, 1);
      expect(computeNextDue(last, 180) - computeNextDue(last, 1),
          179 * dayMs);
    });

    test('Feb29 năm nhuận: +1d = 01/03, +365d = 28/02 năm sau', () {
      final last = utc(2024, 2, 29, 8);
      final n1 = DateTime.fromMillisecondsSinceEpoch(
          computeNextDue(last, 1),
          isUtc: true);
      expect(n1.day, 1);
      expect(n1.month, 3);
      final n365 = DateTime.fromMillisecondsSinceEpoch(
          computeNextDue(last, 365),
          isUtc: true);
      expect(n365.year, 2025);
      expect(n365.month, 2);
      expect(n365.day, 28);
    });
  });

  group('getStatus', () {
    test('overdue khi quá hạn > 1 ngày', () {
      final now = utc(2024, 1, 10);
      expect(getStatus(now, utc(2024, 1, 8)), 'overdue');
    });

    test('biên: quá 1ms trong ngày -> due_today; quá 1d+1ms -> overdue', () {
      final now = utc(2024, 1, 10);
      expect(getStatus(now, now - 1), 'due_today');
      expect(getStatus(now, now - dayMs - 1), 'overdue');
    });

    test('due_today khi eff == now', () {
      final now = utc(2024, 1, 10, 8);
      expect(getStatus(now, now), 'due_today');
    });

    test('due_grace khi còn đúng 1 ngày', () {
      final now = utc(2024, 1, 10);
      expect(getStatus(now, now + dayMs), 'due_grace');
    });

    test('upcoming 2..7 ngày, ok > 7 ngày', () {
      final now = utc(2024, 1, 10);
      expect(getStatus(now, now + 2 * dayMs), 'upcoming');
      expect(getStatus(now, now + 7 * dayMs), 'upcoming');
      expect(getStatus(now, now + 8 * dayMs), 'ok');
      expect(getStatus(now, now + 180 * dayMs), 'ok');
    });

    test('cycle 1 ngày -> grace, cycle 180 ngày -> ok', () {
      final last = utc(2024, 1, 1);
      expect(getStatus(last, computeNextDue(last, 1)), 'due_grace');
      expect(getStatus(last, computeNextDue(last, 180)), 'ok');
    });

    test('effectiveDue = max(nextDue, snoozedUntil)', () {
      expect(effectiveDue(100, 200), 200);
      expect(effectiveDue(300, 200), 300);
      expect(effectiveDue(100, null), 100);
    });

    test('snooze đẩy overdue thành grace', () {
      final now = utc(2024, 1, 10);
      final pastDue = utc(2024, 1, 5);
      expect(getStatus(now, pastDue), 'overdue');
      expect(getStatus(now, pastDue, snooze(now)), 'due_grace');
    });
  });

  group('markDone', () {
    test('done sớm (early) khi now < nextDue - 1d, reset từ now', () {
      final now = utc(2024, 1, 5);
      final due = utc(2024, 1, 10);
      final r = markDone(now, due, 7);
      expect(r.result, 'early');
      expect(r.newNextDue, now + 7 * dayMs);
    });

    test('biên early/done: == nextDue-1d là done, -1ms nữa là early', () {
      final due = utc(2024, 1, 10);
      expect(markDone(due - dayMs, due, 7).result, 'done');
      expect(markDone(due - dayMs - 1, due, 7).result, 'early');
    });

    test('đúng hạn (done) trong [nextDue-1d, nextDue]', () {
      final due = utc(2024, 1, 10);
      final r = markDone(due - 3600 * 1000, due, 7);
      expect(r.result, 'done');
      expect(r.newNextDue, due - 3600 * 1000 + 7 * dayMs);
      expect(markDone(due, due, 7).result, 'done');
    });

    test('trễ (late) khi now > nextDue, reset từ now', () {
      final due = utc(2024, 1, 10);
      final r = markDone(due + 1, due, 7);
      expect(r.result, 'late');
      expect(r.newNextDue, due + 1 + 7 * dayMs);
      expect(markDone(due + 3 * dayMs, due, 7).result, 'late');
    });
  });

  group('skip / snooze / đổi cycle', () {
    test('skip giữ nhịp: nextDue + cycle (khác markDone reset từ now)', () {
      final due = utc(2024, 1, 10);
      expect(skipTask(due, 7), due + 7 * dayMs);
      final now = utc(2024, 1, 5);
      expect(skipTask(due, 7), isNot(markDone(now, due, 7).newNextDue));
    });

    test('snooze mặc định +1 ngày, custom ms', () {
      final now = utc(2024, 1, 10, 8);
      expect(snooze(now), now + dayMs);
      expect(snooze(now, 2 * 3600 * 1000), now + 2 * 3600 * 1000);
    });

    test('đổi cycle recompute từ lastDone', () {
      final last = utc(2024, 1, 1);
      expect(changeCycle(last, 7), last + 7 * dayMs);
      expect(changeCycle(last, 30), last + 30 * dayMs);
      expect(changeCycle(last, 14) - changeCycle(last, 7), 7 * dayMs);
    });
  });
}
