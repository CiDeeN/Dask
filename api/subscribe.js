// POST /api/subscribe (Bearer) — gắn push subscription của máy này vào USER đang đăng nhập.
// Body: { subscription: {endpoint, keys:{p256dh, auth}} }. Cron gửi push theo list của user.
const crypto = require('crypto');
const { kv, kvConfigured } = require('./_kv');
const { authToken } = require('./_auth');

const TTL = 60 * 60 * 24 * 90;

module.exports = async (req, res) => {
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });
  if (!kvConfigured) return res.status(500).json({ error: 'KV chua cau hinh (KV_REST_API_URL/TOKEN)' });
  const username = await authToken(req);
  if (!username) return res.status(401).json({ error: 'dang nhap truoc' });
  const { subscription } = req.body || {};
  if (!subscription || !subscription.endpoint || !subscription.keys || !subscription.keys.p256dh || !subscription.keys.auth) {
    return res.status(400).json({ error: 'thieu subscription' });
  }
  const id = crypto.createHash('sha256').update(subscription.endpoint).digest('hex').slice(0, 32);
  await kv('hset', `push:sub:${id}`, 'sub', JSON.stringify(subscription), 'user', username, 'updated', String(Date.now()));
  await kv('sadd', `user:${username}:subs`, id);
  await kv('expire', `push:sub:${id}`, String(TTL));
  return res.status(200).json({ ok: true });
};
