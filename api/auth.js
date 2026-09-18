// POST /api/auth — {action:'register'|'login', username, password}
// Trả {ok, token, username}. Token dùng cho /api/sync và /api/subscribe.
const crypto = require('crypto');
const { kv, kvConfigured } = require('./_kv');
const { validName, hashPw, getUser, newSession } = require('./_auth');

module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });
  if (!kvConfigured) return res.status(500).json({ error: 'KV chua cau hinh' });
  const { action, username: raw, password } = req.body || {};
  const username = String(raw || '').trim();
  if (!validName(username)) return res.status(400).json({ error: 'ten 2-30 ky tu (chu/so/._- )' });
  if (typeof password !== 'string' || password.length < 6) {
    return res.status(400).json({ error: 'mat khau >= 6 ky tu' });
  }
  if (action === 'register') {
    if (await getUser(username)) return res.status(409).json({ error: 'ten da ton tai' });
    const salt = crypto.randomBytes(16).toString('hex');
    await kv('hset', `user:${username}`,
      'salt', salt, 'hash', hashPw(password, salt),
      'created', String(Date.now()), 'tasks', '[]', 'savedAt', '0');
    await kv('sadd', 'users', username);
    return res.status(200).json({ ok: true, token: await newSession(username), username });
  }
  if (action === 'login') {
    const tries = +((await kv('get', `login:try:${username}`)) || 0);
    if (tries >= 20) return res.status(429).json({ error: 'sai nhieu lan, thu lai sau 10 phut' });
    const u = await getUser(username);
    const ok = u && crypto.timingSafeEqual(Buffer.from(hashPw(password, u.salt)), Buffer.from(u.hash));
    if (!ok) {
      try { await kv('incr', `login:try:${username}`); await kv('expire', `login:try:${username}`, '600'); } catch {}
      return res.status(401).json({ error: 'sai ten hoac mat khau' });
    }
    try { await kv('del', `login:try:${username}`); } catch {}
    return res.status(200).json({ ok: true, token: await newSession(username), username });
  }
  return res.status(400).json({ error: 'action register|login?' });
};
