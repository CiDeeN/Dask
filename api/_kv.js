// Helper gọi Vercel KV (Upstash REST) bằng fetch có sẵn của Node 18+ — không cần npm dep.
// Cần env: KV_REST_API_URL + KV_REST_API_TOKEN (tự có khi tạo KV trong Vercel dashboard).
const URL = process.env.KV_REST_API_URL;
const TOKEN = process.env.KV_REST_API_TOKEN;

async function kv(cmd, ...args) {
  const res = await fetch(`${URL}/${cmd}/${args.map((a) => encodeURIComponent(a)).join('/')}`, {
    headers: { Authorization: `Bearer ${TOKEN}` },
  });
  if (!res.ok) throw new Error(`KV ${cmd} -> ${res.status}`);
  return (await res.json()).result;
}

module.exports = { kv, kvConfigured: Boolean(URL && TOKEN) };
