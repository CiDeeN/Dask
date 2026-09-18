// GET /api/cron — Vercel Cron gọi mỗi sáng (vercel.json: "0 0 * * *" = 7h VN).
// Duyệt từng USER (mỗi người 1 list riêng), gửi 1 push tóm tắt cho việc đến hạn/quá hạn
// tới mọi máy đã đăng ký của user đó.
// Env: KV_*, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT?, CRON_SECRET?
const webpush = require('web-push');
const { kv, kvConfigured } = require('./_kv');

const DAY = 86400000;

function statusOf(t, now) {
  const eff = t.snoozedUntil && t.snoozedUntil > now ? t.snoozedUntil : t.nextDueAt;
  const diff = Math.floor((eff - now) / DAY);
  if (diff < -(t.grace || 0)) return { s: 'overdue', diff, txt: `Quá hạn ${-diff} ngày` };
  if (diff < 0) return { s: 'dueGrace', diff, txt: `Trễ ${-diff} ngày` };
  if (diff === 0) return { s: 'dueToday', diff, txt: 'Đến hạn hôm nay' };
  if (diff <= (t.remindBefore == null ? 2 : t.remindBefore)) return { s: 'upcoming', diff, txt: `Còn ${diff} ngày` };
  return { s: 'ok', diff, txt: `Còn ${diff} ngày` };
}

async function sendTo(subId, user, payload) {
  let rec = null;
  try { rec = await kv('hgetall', `push:sub:${subId}`); } catch { rec = null; }
  if (!rec || !rec.sub) { try { await kv('srem', `user:${user}:subs`, subId); } catch {} return 'cleaned'; }
  try {
    await webpush.sendNotification(JSON.parse(rec.sub), JSON.stringify(payload));
    return 'sent';
  } catch (e) {
    if (e && (e.statusCode === 404 || e.statusCode === 410)) {
      try { await kv('del', `push:sub:${subId}`); await kv('srem', `user:${user}:subs`, subId); } catch {}
      return 'cleaned';
    }
    return 'failed';
  }
}

module.exports = async (req, res) => {
  if (process.env.CRON_SECRET && req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  if (!kvConfigured) return res.status(500).json({ error: 'KV chua cau hinh' });
  if (!process.env.VAPID_PUBLIC_KEY || !process.env.VAPID_PRIVATE_KEY) {
    return res.status(500).json({ error: 'thieu VAPID_PUBLIC_KEY/VAPID_PRIVATE_KEY' });
  }
  webpush.setVapidDetails(
    process.env.VAPID_SUBJECT || 'https://dask-kappa.vercel.app/',
    process.env.VAPID_PUBLIC_KEY,
    process.env.VAPID_PRIVATE_KEY
  );
  const users = (await kv('smembers', 'users')) || [];
  const now = Date.now();
  let users_ = 0, sent = 0, cleaned = 0;
  for (const u of users) {
    let r = null;
    try { r = await kv('hgetall', `user:${u}`); } catch { r = null; }
    if (!r) continue;
    let tasks = [];
    try { tasks = JSON.parse(r.tasks || '[]'); } catch { tasks = []; }
    const subIds = (await kv('smembers', `user:${u}:subs`)) || [];
    if (!tasks.length || !subIds.length) continue;
    users_++;
    const due = tasks
      .filter((t) => t && t.isActive !== false && t.nextDueAt)
      .map((t) => ({ t, st: statusOf(t, now) }))
      .filter((x) => (x.st.s === 'dueToday' || x.st.s === 'overdue') && x.st.diff >= -7);
    if (!due.length) continue;
    const payload = due.length === 1
      ? { title: due[0].st.s === 'overdue' ? `Quá hạn: ${due[0].t.title}` : `Đến hạn: ${due[0].t.title}`, body: due[0].st.txt }
      : {
          title: `${due.length} việc đến hạn`,
          body: due.slice(0, 3).map((x) => `• ${x.t.title} (${x.st.txt.toLowerCase()})`).join('\n'),
        };
    for (const id of subIds) {
      const out = await sendTo(id, u, payload);
      if (out === 'sent') sent++;
      else if (out === 'cleaned') cleaned++;
    }
  }
  return res.status(200).json({ ok: true, users: users_, sent, cleaned });
};
