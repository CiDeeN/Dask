// Auth dùng chung: session token (Bearer) -> username. Mật khẩu hash scrypt, không lưu plain.
const crypto = require('crypto');
const { kv } = require('./_kv');

const SES_TTL = 60 * 60 * 24 * 180; // phiên 180 ngày

function validName(u) {
  return typeof u === 'string' && /^[a-zA-Z0-9_.\- ]{2,30}$/.test(u.trim());
}
function hashPw(pw, salt) {
  return crypto.scryptSync(pw, salt, 32).toString('hex');
}
async function getUser(username) {
  const r = await kv('hgetall', `user:${username}`);
  return r && r.hash ? r : null;
}
async function newSession(username) {
  const tok = crypto.randomBytes(32).toString('hex');
  await kv('set', `session:${tok}`, username, 'EX', String(SES_TTL));
  return tok;
}
// Trả về username hoặc null.
async function authToken(req) {
  const m = /^Bearer ([a-f0-9]{64})$/.exec(req.headers.authorization || '');
  if (!m) return null;
  try {
    return (await kv('get', `session:${m[1]}`)) || null;
  } catch { return null; }
}

module.exports = { validName, hashPw, getUser, newSession, authToken };
