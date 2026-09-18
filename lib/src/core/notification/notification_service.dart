import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../features/habits/data/models.dart';
import '../../../features/reminders/recurrence.dart' as rec;

/// Dev2 sở hữu: wrapper flutter_local_notifications + timezone.
///
/// Tương thích model Dev1 (epoch ms: nextDueAt/snoozedUntil/lastDoneAt).
/// - init() 1 lần ở main (trước runApp)
/// - requestPermissions(): Android 13+ POST_NOTIFICATIONS, iOS alert/badge/sound
/// - schedule(task): nhắc trước `remindBeforeDays` lúc 8h, tôn trọng quiet hours 22h-7h
/// - cancel(task): hủy theo task.id
/// - scheduleDigest(): 1 noti tổng hợp 7h sáng mỗi ngày
/// - grouping Android: groupKey chung `groupHabits`
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const String _channelId = 'habits_reminder';
  static const String _channelName = 'Nhắc việc nhà';
  static const String _channelDesc = 'Nhắc các việc nhà định kỳ sắp tới hạn';
  static const String _digestChannelId = 'habits_digest';
  static const String _groupKey = 'groupHabits';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    // TODO: picks đúng timezone thiết bị khi có flutter_timezone.
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: android,
      iOS: ios,
    );
    await _plugin.initialize(initSettings);
    await _createChannels();
    _initialized = true;
  }

  Future<void> _createChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _digestChannelId,
        'Tổng hợp hằng ngày',
        description: 'Thông báo tổng hợp các việc sắp tới hạn mỗi sáng',
        importance: Importance.defaultImportance,
      ),
    );
  }

  /// Xin quyền. Trả về true nếu được cấp (hoặc platform không cần xin).
  Future<bool> requestPermissions() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      bool androidGranted = true;
      if (android != null) {
        final bool? granted =
            await android.requestNotificationsPermission();
        androidGranted = granted ?? true;
      }
      final IOSFlutterLocalNotificationsPlugin? ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      bool iosGranted = true;
      if (ios != null) {
        final bool? granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        iosGranted = granted ?? false;
      }
      return androidGranted && iosGranted;
    } catch (e) {
      debugPrint('requestPermissions error: $e');
      return false;
    }
  }

  /// Giờ yên tĩnh 22h -> 7h: nếu [time] rơi vào khoảng này thì dời tới 7h sáng.
  @visibleForTesting
  tz.TZDateTime applyQuietHours(tz.TZDateTime time) {
    final int h = time.hour;
    final bool inQuiet = h >= 22 || h < 7;
    if (!inQuiet) return time;
    if (h >= 22) {
      final tz.TZDateTime nextDay = time.add(const Duration(days: 1));
      return tz.TZDateTime(
        time.location,
        nextDay.year,
        nextDay.month,
        nextDay.day,
        7,
        0,
      );
    } else {
      return tz.TZDateTime(
        time.location,
        time.year,
        time.month,
        time.day,
        7,
        0,
      );
    }
  }

  /// Lịch nhắc cho 1 task: (effectiveDue - remindBeforeDays) lúc 8h sáng.
  /// effectiveDue = snoozedUntil (nếu còn hiệu lực) else nextDueAt.
  /// Task isActive=false -> chỉ cancel, không schedule.
  Future<void> scheduleTask(Task task) async {
    await init();
    await cancelTask(task.id);
    if (!task.isActive) return;

    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final rec.DueStatus st =
        rec.getStatus(task, nowMs: nowMs);
    if (st.state == rec.DueState.inactive) return;

    final DateTime due =
        DateTime.fromMillisecondsSinceEpoch(st.effectiveDueAt);
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime remindDay = tz.TZDateTime(
      tz.local,
      due.year,
      due.month,
      due.day,
      8,
      0,
    ).subtract(Duration(days: task.remindBeforeDays));

    if (remindDay.isBefore(now)) {
      // Due trong tương lai nhưng giờ nhắc hôm nay đã qua -> nhắc bù +5s
      // để user vẫn nhận được trong ngày (pattern thường dùng khi test).
      if (due.isBefore(DateTime.now())) return; // quá hạn: digest lo
      final tz.TZDateTime today8am = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        8,
        0,
      );
      if (now.isAfter(today8am) && st.diffDays <= task.remindBeforeDays) {
        remindDay = now.add(const Duration(seconds: 5));
      } else {
        if (remindDay.isBefore(now)) return;
      }
      if (remindDay.isBefore(now)) return;
    }

    remindDay = applyQuietHours(remindDay);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      groupKey: _groupKey,
      setAsGroupSummary: false,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      threadIdentifier: _groupKey,
    );
    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final String body = st.diffDays <= 0
        ? 'Đã tới hạn! ${task.lastDoneAt == null ? 'Chưa làm lần nào' : 'Lần cuối: ${_fmtDate(DateTime.fromMillisecondsSinceEpoch(task.lastDoneAt!))}'}'
        : 'Còn ${st.diffDays} ngày nữa tới hạn (${_fmtDate(due)})';

    await _plugin.zonedSchedule(
      task.id.hashCode,
      '⏰ ${task.title}',
      body,
      remindDay,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleAll(List<Task> tasks) async {
    for (final Task t in tasks) {
      await scheduleTask(t);
    }
  }

  Future<void> cancelTask(String taskId) async {
    try {
      await _plugin.cancel(taskId.hashCode);
    } catch (e) {
      debugPrint('cancelTask error: $e');
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Digest tổng hợp 7h sáng hằng ngày, lặp theo giờ (matchDateTimeComponents.time).
  Future<void> scheduleDigest({
    required int overdueCount,
    required int upcomingCount,
  }) async {
    await init();
    const int digestId = 0xD16357;
    await _plugin.cancel(digestId);

    if (overdueCount == 0 && upcomingCount == 0) return;

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime next7am = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      7,
      0,
    );
    if (!next7am.isAfter(now)) {
      next7am = next7am.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _digestChannelId,
      'Tổng hợp hằng ngày',
      channelDescription: 'Thông báo tổng hợp các việc sắp tới hạn mỗi sáng',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      groupKey: _groupKey,
      setAsGroupSummary: true,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      threadIdentifier: _groupKey,
    );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      digestId,
      '🏠 Việc nhà hôm nay',
      '$overdueCount quá hạn, $upcomingCount sắp tới — mở app để xem chi tiết',
      next7am,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
