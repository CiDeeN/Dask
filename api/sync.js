// /api/sync — danh sách task THEO USER (mỗi người 1 list riêng, đồng bộ đa máy).
// GET (Bearer) -> {tasks, savedAt}.
// PUT (Bearer) {tasks, savedAt} -> last-writer-wins cả list theo savedAt; luôn trả bản thắng để client hội tụ.
const { kv, kvConfigured } = require('./_kv');
const { authToken } = require('./_auth');

function cleanTasks(tasks) {
  return (Array.isArray(tasks) ? tasks : [])
    .filter((t) => t && t.id && t.nextDueAt)
    .map((t) => ({
      id: String(t.id),
      title: String(t.title || 'Việc').slice(0, 60),
      icon: String(t.icon || '🧹').slice(0, 8),
      cycleDays: Math.min(730, Math.max(1, t.cycleDays | 0 || 7)),
      lastDoneAt: t.lastDoneAt || null,
      nextDueAt: +t.nextDueAt || 0,
      grace: t.grace | 0 || 0,
      remindBefore: t.remindBefore == null ? 2 : Math.min(30, Math.max(0, +t.remindBefore || 0)),
      snoozedUntil: t.snoozedUntil || null,
      isActive: t.isActive !== false,
    }))
    .slice(0, 200);
}

module.exports = async (req, res) => {
  if (!kvConfigured) return res.status(500).json({ error: 'KV chua cau hinh' });
  const username = await authToken(req);
  if (!username) return res.status(401).json({ error: 'het phien, dang nhap lai' });
  if (req.method === 'GET') {
    const r = await kv('hgetall', `user:${username}`);
    let tasks = [];
    try { tasks = JSON.parse((r && r.tasks) || '[]'); } catch { tasks = []; }
    return res.status(200).json({ ok: true, tasks, savedAt: +((r && r.savedAt) || 0) });
  }
  if (req.method === 'PUT') {
    const { tasks, savedAt } = req.body || {};
    const r = await kv('hgetall', `user:${username}`);
    const serverSaved = +((r && r.savedAt) || 0);
    if ((+savedAt || 0) > serverSaved && Array.isArray(tasks)) {
      const clean = cleanTasks(tasks);
      const now = Date.now();
      await kv('hset', `user:${username}`, 'tasks', JSON.stringify(clean), 'savedAt', String(now));
      return res.status(200).json({ ok: true, tasks: clean, savedAt: now });
    }
    let st = [];
    try { st = JSON.parse((r && r.tasks) || '[]'); } catch { st = []; }
    return res.status(200).json({ ok: true, tasks: st, savedAt: serverSaved, stale: true });
  }
  return res.status(405).json({ error: 'GET/PUT only' });
};
