"""
Port Python thuần của logic recurrence (để verify không cần Flutter/Dart).

Logic chuẩn:
  computeNextDue = lastDone + cycle * 86400000
  effectiveDue   = max(nextDue, snoozedUntil)  (snoozedUntil=None => nextDue)
  diffDays       = ceil((effectiveDue - now) / 86400000)
  status theo diffDays:
    diffDays < 0       -> "overdue"
    diffDays == 0      -> "due_today"   (hôm nay, eff <=24h tới hoặc vừa quá trong ngày -> ceil=0)
    diffDays == 1      -> "due_grace"   (còn 1 ngày / trong grace 1 ngày)
    2 <= diffDays <= 7 -> "upcoming"
    diffDays > 7       -> "ok"
  markDone(now, nextDue, cycle):
    early nếu now < nextDue - 86400000
    late  nếu now > nextDue
    else  done (đúng hạn: trong [nextDue-1d, nextDue])
    reset nextDue = now + cycle * 86400000
  skip:   nextDue = nextDue + cycle * 86400000 (giữ nhịp, không lấy now)
  snooze: snoozedUntil = now + snoozeMs (mặc định 1 ngày)
  đổi cycle: nextDue = lastDone + newCycle * 86400000 (recompute từ lastDone)

Chạy: python test_verify_recurrence.py
"""

import math
import sys
from datetime import datetime, timezone

DAY_MS = 86400000


# ---------- logic lõi (mirror Dart) ----------
def compute_next_due(last_done_ms: int, cycle_days: int) -> int:
    return last_done_ms + cycle_days * DAY_MS


def effective_due(next_due_ms: int, snoozed_until_ms=None) -> int:
    if snoozed_until_ms is None:
        return next_due_ms
    return max(next_due_ms, snoozed_until_ms)


def get_status(now_ms: int, next_due_ms: int, snoozed_until_ms=None) -> str:
    eff = effective_due(next_due_ms, snoozed_until_ms)
    diff_days = math.ceil((eff - now_ms) / DAY_MS)
    if diff_days < 0:
        return "overdue"
    if diff_days == 0:
        return "due_today"
    if diff_days == 1:
        return "due_grace"
    if 2 <= diff_days <= 7:
        return "upcoming"
    return "ok"


def mark_done(now_ms: int, next_due_ms: int, cycle_days: int):
    """Trả về (result, new_next_due). result ∈ {early, done, late}."""
    if now_ms < next_due_ms - DAY_MS:
        result = "early"
    elif now_ms > next_due_ms:
        result = "late"
    else:
        result = "done"
    return result, now_ms + cycle_days * DAY_MS


def skip_task(next_due_ms: int, cycle_days: int) -> int:
    return next_due_ms + cycle_days * DAY_MS


def snooze(now_ms: int, snooze_ms: int = DAY_MS) -> int:
    return now_ms + snooze_ms


def change_cycle(last_done_ms: int, new_cycle_days: int) -> int:
    return compute_next_due(last_done_ms, new_cycle_days)


def dt_utc(y, m, d, hh=0, mm=0, ss=0) -> int:
    return int(datetime(y, m, d, hh, mm, ss, tzinfo=timezone.utc).timestamp() * 1000)


# ---------- mini test runner ----------
PASSED = 0
FAILED = 0
FAILURES = []


def check(name, fn):
    global PASSED, FAILED
    try:
        fn()
        PASSED += 1
        print(f"PASS: {name}")
    except AssertionError as e:
        FAILED += 1
        FAILURES.append(name)
        print(f"FAIL: {name} -- {e}")
    except Exception as e:  # noqa: BLE001
        FAILED += 1
        FAILURES.append(name)
        print(f"FAIL: {name} -- EXCEPTION {type(e).__name__}: {e}")


# ---------- test cases ----------
def t_compute_basic():
    last = dt_utc(2024, 1, 1)
    assert compute_next_due(last, 7) == last + 7 * DAY_MS
    assert compute_next_due(last, 1) == last + DAY_MS
    assert compute_next_due(last, 180) == last + 180 * DAY_MS


def t_status_overdue():
    now = dt_utc(2024, 1, 10)
    due = dt_utc(2024, 1, 8)  # quá 2 ngày
    assert get_status(now, due) == "overdue"


def t_status_overdue_1ms():
    # vừa quá hạn 1ms -> ceil(số âm rất nhỏ) == 0 -> due_today (trong ngày)
    # quá 1 ngày + 1ms -> ceil(-1.000..) == -1 -> overdue
    now = dt_utc(2024, 1, 10)
    assert get_status(now, now - 1) == "due_today"
    assert get_status(now, now - DAY_MS - 1) == "overdue"


def t_status_due_today():
    now = dt_utc(2024, 1, 10, 8, 0, 0)
    assert get_status(now, now) == "due_today"
    # +1h => ceil(0.04) = 1 => due_grace theo mapping
    assert get_status(now, now + 3600 * 1000) == "due_grace"


def t_status_due_grace():
    now = dt_utc(2024, 1, 10)
    assert get_status(now, now + DAY_MS) == "due_grace"


def t_status_upcoming():
    now = dt_utc(2024, 1, 10)
    assert get_status(now, now + 2 * DAY_MS) == "upcoming"
    assert get_status(now, now + 7 * DAY_MS) == "upcoming"


def t_status_ok():
    now = dt_utc(2024, 1, 10)
    assert get_status(now, now + 8 * DAY_MS) == "ok"
    assert get_status(now, now + 180 * DAY_MS) == "ok"


def t_effective_due_snooze():
    now = dt_utc(2024, 1, 10)
    past_due = dt_utc(2024, 1, 5)  # overdue nếu không snooze
    assert get_status(now, past_due) == "overdue"
    snz = snooze(now, DAY_MS)  # snooze tới mai
    assert get_status(now, past_due, snz) == "due_grace"
    # snoozedUntil cũ hơn nextDue thì không ảnh hưởng
    future_due = now + 5 * DAY_MS
    assert get_status(now, future_due, now - DAY_MS) == "upcoming"


def t_markdone_early():
    now = dt_utc(2024, 1, 5)
    due = dt_utc(2024, 1, 10)
    r, nxt = mark_done(now, due, 7)
    assert r == "early", f"got {r}"
    assert nxt == now + 7 * DAY_MS  # reset từ now


def t_markdone_early_boundary():
    due = dt_utc(2024, 1, 10)
    # đúng biên nextDue-1d => done (vì early là < nghiêm ngặt)
    r, _ = mark_done(due - DAY_MS, due, 7)
    assert r == "done", f"got {r}"
    r2, _ = mark_done(due - DAY_MS - 1, due, 7)
    assert r2 == "early", f"got {r2}"


def t_markdone_ontime():
    due = dt_utc(2024, 1, 10)
    r, nxt = mark_done(due - 3600 * 1000, due, 7)  # trước 1h
    assert r == "done", f"got {r}"
    assert nxt == (due - 3600 * 1000) + 7 * DAY_MS
    r2, _ = mark_done(due, due, 7)  # đúng hạn tuyệt đối
    assert r2 == "done"


def t_markdone_late():
    due = dt_utc(2024, 1, 10)
    r, nxt = mark_done(due + 1, due, 7)
    assert r == "late", f"got {r}"
    assert nxt == due + 1 + 7 * DAY_MS
    r2, _ = mark_done(due + 3 * DAY_MS, due, 7)
    assert r2 == "late"


def t_skip_keeps_cadence():
    due = dt_utc(2024, 1, 10)
    assert skip_task(due, 7) == due + 7 * DAY_MS
    # skip khác markDone: markDone reset từ now, skip cộng dồn từ nextDue
    now = dt_utc(2024, 1, 5)
    _, nxt_done = mark_done(now, due, 7)
    assert skip_task(due, 7) != nxt_done


def t_snooze():
    now = dt_utc(2024, 1, 10, 8, 0, 0)
    assert snooze(now) == now + DAY_MS
    assert snooze(now, 2 * 3600 * 1000) == now + 2 * 3600 * 1000


def t_change_cycle():
    last = dt_utc(2024, 1, 1)
    assert change_cycle(last, 7) == last + 7 * DAY_MS
    assert change_cycle(last, 30) == last + 30 * DAY_MS
    # đổi 7 -> 14 ngày
    assert change_cycle(last, 14) - change_cycle(last, 7) == 7 * DAY_MS


def t_feb29_leap():
    # 2024 là năm nhuận, 29/02 tồn tại
    last = dt_utc(2024, 2, 29, 8, 0, 0)
    nxt1 = compute_next_due(last, 1)
    back = datetime.fromtimestamp(nxt1 / 1000, tz=timezone.utc)
    assert (back.day, back.month) == (1, 3), f"got {back}"
    # cycle 365 từ Feb29 -> Feb28 năm sau (ms math thuần, không drift lịch)
    nxt365 = compute_next_due(last, 365)
    back365 = datetime.fromtimestamp(nxt365 / 1000, tz=timezone.utc)
    assert (back365.day, back365.month, back365.year) == (28, 2, 2025), f"got {back365}"


def t_cycle_1_vs_180():
    last = dt_utc(2024, 1, 1)
    n1 = compute_next_due(last, 1)
    n180 = compute_next_due(last, 180)
    assert n180 - n1 == 179 * DAY_MS
    # status: cycle 1 ngày -> mai là grace; cycle 180 -> ok
    now = last
    assert get_status(now, n1) == "due_grace"
    assert get_status(now, n180) == "ok"
    # markDone reset đúng từng cycle
    _, r1 = mark_done(n1, n1, 1)
    _, r180 = mark_done(n1, n1, 180)
    assert r180 - r1 == 179 * DAY_MS


def t_effective_due_max():
    assert effective_due(100, 200) == 200
    assert effective_due(300, 200) == 300
    assert effective_due(100, None) == 100


CASES = [
    ("computeNextDue co ban", t_compute_basic),
    ("status overdue", t_status_overdue),
    ("status bien overdue/due_today", t_status_overdue_1ms),
    ("status due_today/grace", t_status_due_today),
    ("status due_grace", t_status_due_grace),
    ("status upcoming", t_status_upcoming),
    ("status ok", t_status_ok),
    ("effectiveDue + snooze", t_effective_due_snooze),
    ("markDone som (early)", t_markdone_early),
    ("markDone bien early/done", t_markdone_early_boundary),
    ("markDone dung han (done)", t_markdone_ontime),
    ("markDone tre (late)", t_markdone_late),
    ("skip giu nhip", t_skip_keeps_cadence),
    ("snooze", t_snooze),
    ("doi cycle", t_change_cycle),
    ("Feb29 nam nhuan", t_feb29_leap),
    ("cycle 1 ngay vs 180 ngay", t_cycle_1_vs_180),
    ("effectiveDue = max()", t_effective_due_max),
]


def main():
    print("=== test_verify_recurrence.py ===")
    for name, fn in CASES:
        check(name, fn)
    print(f"\nTong: {PASSED} PASS, {FAILED} FAIL / {len(CASES)} case")
    if FAILED:
        print("THAT BAI:", FAILURES)
        sys.exit(1)
    print("TAT CA PASS")


if __name__ == "__main__":
    main()
