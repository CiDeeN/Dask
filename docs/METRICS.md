# Metrics — Recurrence App

> Mục tiêu tối thiểu để coi tính năng nhắc lặp + streak là "khỏe".
> Đo theo cohort install (UTC), dashboard cập nhật hằng ngày.

## 1. Định nghĩa + Target

| Metric | Định nghĩa | Target | Ghi chú |
|---|---|---|---|
| D7 retention | % user mở app vào ngày 7 (±1d) sau install | **> 25%** | Cohort install, loại trừ reinstall cùng device_id trong 30d |
| D30 retention | % user mở app vào ngày 30 (±2d) sau install | **> 12%** | Tương tự D7, window rộng hơn |
| On-time rate | `done` đúng hạn / (done + late + early + skip) trong 28d | **> 40%** | `done` = now ∈ [nextDue−1d, nextDue]; xem `markDone` trong test |
| Noti open rate | số noti được mở / số noti đã deliver (7d rolling) | **> 15%** | Chỉ tính noti recurrence (có `taskId`), không tính promo |

## 2. Công thức chi tiết

- **D7** = users(active_day7) / users(installed_day0) × 100. Active = ≥1 foreground session ≥5s.
- **D30** = users(active_day30±2) / users(installed_day0) × 100.
- **On-time rate** = COUNT(result='done') / COUNT(result IN ('done','late','early','skip')) — lấy từ event `task_completed{result, cycleDays}`. Không tính `snooze` (chưa hoàn thành).
- **Noti open** = COUNT(`noti_open{taskId}`) / COUNT(`noti_delivered{taskId}`) — join theo `notiId`, window 24h sau deliver.

## 3. Event cần log (tối thiểu)

- `task_completed{result: done|late|early, cycleDays, diffMs}` — bắn trong `markDone`.
- `task_skipped{cycleDays}`, `task_snoozed{snoozeMs}`.
- `noti_delivered{notiId, taskId}`, `noti_open{notiId, taskId}`.
- `app_open{day_since_install}` cho D7/D30.

## 4. Cảnh báo (alert nếu 3 ngày liên tiếp dưới target)

- D7 < 25% → kiểm tra onboarding + noti permission granted rate.
- D30 < 12% → kiểm tra streak-cheat, offline sync, Feb29/cycle dài (180d) có bị `overdue` oan.
- On-time < 40% → xem phân bố cycle (1d quá khó?), giờ noti mặc định có lệch múi giờ HN/Tokyo.
- Noti open < 15% → kiểm tra gộp noti 50 task, giờ bắn, nội dung CTA.

## 5. Không "hack" metric

- Cấm tự bắn `app_open` nền để đẹp D7/D30; cấm tính `snooze` thành `done`.
- Mọi thay đổi định nghĩa phải bump version doc + backfill chú thích trên dashboard.
