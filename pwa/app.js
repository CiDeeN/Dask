// PWA logic — port 1:1 từ lib/src/features/reminders/recurrence.dart (floor + grace/remindBefore).
const DAY = 86400000, KEY = 'habit_pwa_v1';
const PUSH_KEY = 'habit_push_sub';
const VAPID_PUBLIC = 'BH9R5rTTi21USFRWsV-0RYkxjz-V5_siaqDpi7qLSBb4WBpvXb9n-sH5jMSYn-5RbFMojhbBYmFKJifN0oMUw7k';
const $ = (s) => document.querySelector(s);

const TEMPLATES = [
  ['Dọn toilet','🚽',7,'Cọ bồn cầu, lavabo mỗi tuần.'],['Giặt ga giường','🛏️',14,'Tránh mạt bụi gây dị ứng.'],
  ['Lau nhà','🧹',3,'Quét + lau bếp, lối đi.'],['Giặt rèm cửa','👕',90,'Hút bụi thanh treo.'],
  ['Tẩy lồng giặt','🧺',30,'Chạy chế độ vệ sinh lồng.'],['Vệ sinh máy lạnh','🌬️',90,'Rửa lưới lọc.'],
  ['Thay bàn chải','🪥',90,'Tránh vi khuẩn tích tụ.'],['Thay lõi lọc nước','💧',180,'Theo khuyến cáo hãng.'],
  ['Cắt tóc','💇',30,'Tỉa định kỳ.'],['Tẩy giun','💊',180,'6 tháng/lần cả nhà.'],
  ['Khám răng','🦷',180,'Cạo vôi định kỳ.'],['Tưới cây','🌱',2,'Tưới sáng sớm.'],
  ['Dọn tủ lạnh','🧊',7,'Bỏ đồ hết hạn.'],['Thay nhớt xe','🛵',45,'Kiểm tra thắng, lốp.'],
  ['Vệ sinh nệm','🛋️',60,'Hút bụi, phơi nắng.'],
];
const uid = () => Math.random().toString(36).slice(2) + Date.now().toString(36);
const load = () => { try { return JSON.parse(localStorage.getItem(KEY)) || { tasks: [] }; } catch { return { tasks: [] }; } };
const save = (d) => { localStorage.setItem(KEY, JSON.stringify(d)); localStorage.setItem(SAVED_KEY, String(Date.now())); queueSync(); };
const SAVED_KEY = 'habit_saved_at';
const SES_KEY = 'habit_session';
const getSes = () => { try { return JSON.parse(localStorage.getItem(SES_KEY) || 'null'); } catch { return null; } };
const getTok = () => (getSes() || {}).token || null;
const clearSes = () => localStorage.removeItem(SES_KEY);
let _syncT = null;
function queueSync() {
  clearTimeout(_syncT);
  _syncT = setTimeout(syncPush, 1500);
}
// Đồng bộ list của USER đang đăng nhập lên server (last-writer-wins theo savedAt).
async function syncPush() {
  try {
    if (!getTok()) return;
    const { tasks } = load();
    const r = await apiReq('/api/sync', 'PUT', { tasks, savedAt: +(localStorage.getItem(SAVED_KEY) || 0) });
    if (r.stale) {
      localStorage.setItem(KEY, JSON.stringify({ tasks: r.tasks || [] }));
      localStorage.setItem(SAVED_KEY, String(r.savedAt || 0));
      render();
    }
  } catch {}
}
// Kéo list server về khi đăng nhập (máy mới / máy khác).
async function pullSync() {
  const r = await apiReq('/api/sync', 'GET');
  const localSaved = +(localStorage.getItem(SAVED_KEY) || 0);
  if ((r.savedAt || 0) > localSaved) {
    localStorage.setItem(KEY, JSON.stringify({ tasks: r.tasks || [] }));
    localStorage.setItem(SAVED_KEY, String(r.savedAt || 0));
  } else if (localSaved > (r.savedAt || 0)) {
    const { tasks } = load();
    await apiReq('/api/sync', 'PUT', { tasks, savedAt: localSaved });
  }
  // Gắn lại push subscription của máy này vào user vừa đăng nhập.
  try {
    const sub = JSON.parse(localStorage.getItem(PUSH_KEY) || 'null');
    if (sub) await apiReq('/api/subscribe', 'POST', { subscription: sub });
  } catch {}
}
async function apiReq(path, method, body) {
  const r = await fetch(path, {
    method, headers: { 'Content-Type': 'application/json', ...(getTok() ? { Authorization: 'Bearer ' + getTok() } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  if (r.status === 401) { clearSes(); const e = new Error('het phien, dang nhap lai'); e.auth = true; throw e; }
  if (!r.ok) throw new Error('http ' + r.status);
  return r.json();
}
function b64url(s) {
  const pad = '='.repeat((4 - (s.length % 4)) % 4);
  return Uint8Array.from(atob((s + pad).replaceAll('-', '+').replaceAll('_', '/')), (c) => c.charCodeAt(0));
}

// --- recurrence (canonical: floor, giống Dart) ---
const nextDue = (last, cycle) => last + cycle * DAY;
function statusOf(t, now = Date.now()) {
  const eff = (t.snoozedUntil && t.snoozedUntil > now) ? t.snoozedUntil : t.nextDueAt;
  const diff = Math.floor((eff - now) / DAY);
  if (diff < -t.grace) return { s: 'overdue', diff, txt: `Quá hạn ${-diff} ngày` };
  if (diff < 0) return { s: 'dueGrace', diff, txt: `Trễ ${-diff} ngày` };
  if (diff === 0) return { s: 'dueToday', diff, txt: 'Đến hạn hôm nay' };
  if (diff <= t.remindBefore) return { s: 'upcoming', diff, txt: `Còn ${diff} ngày` };
  return { s: 'ok', diff, txt: `Còn ${diff} ngày` };
}
const colorOf = (s) => s === 'overdue' ? '#D64545' : (s === 'dueGrace' || s === 'dueToday') ? '#E86A2C' : (s === 'upcoming') ? '#E69F00' : '#2E9E5B';
function markDone(t, now = Date.now()) {
  const st = now < t.nextDueAt - DAY ? 'early' : now > t.nextDueAt ? 'late' : 'done';
  return { ...t, lastDoneAt: now, nextDueAt: nextDue(now, t.cycleDays), snoozedUntil: null, status: st };
}

let filter = 'all', tab = 'today';
function sorted() {
  const { tasks } = load();
  return tasks.filter((t) => t.isActive !== false).sort((a, b) => a.nextDueAt - b.nextDueAt);
}
function render() {
  const h = location.hash || '#/';
  const v = $('#view');
  if (h.startsWith('#/detail/')) return renderDetail(v, decodeURIComponent(h.slice(9)));
  if (h.startsWith('#/account')) return renderAccount(v);
  if (h.startsWith('#/form')) return renderForm(v, new URLSearchParams(h.split('?')[1] || '').get('edit'));
  if (h.startsWith('#/items')) { tab = 'items'; return renderItems(v); }
  if (h.startsWith('#/activity')) { tab = 'activity'; return renderActivity(v); }
  tab = 'today';
  return renderHome(v);
}
// "2 days" / "1 day" / "3 wks" — đúng như ảnh tham chiếu.
function fmtSpan(d) {
  if (d <= 0) return 'Hôm nay';
  if (d < 28) return `${d} day${d === 1 ? '' : 's'}`;
  const w = Math.round(d / 7);
  return `${w} wk${w === 1 ? '' : 's'}`;
}
function fmtLate(d) { return `${d} day${d === 1 ? '' : 's'} late`; }
function tabbar(active) {
  return `<nav class="tabbar" aria-label="Điều hướng">
    <button class="tab${active === 'today' ? ' on' : ''}" data-go="#/">🏠<span>Today</span></button>
    <button class="tab${active === 'items' ? ' on' : ''}" data-go="#/items">☰<span>Items</span></button>
    <button class="tab${active === 'activity' ? ' on' : ''}" data-go="#/activity">📊<span>Activity</span></button>
  </nav>`;
}
function bindTabs(v) { v.querySelectorAll('[data-go]').forEach((b) => b.onclick = () => location.hash = b.dataset.go); }
function header(v, title, sub) {
  v.insertAdjacentHTML('afterbegin', `<header class="top"><div><h1>${title}</h1><p>${sub}</p></div>
    <button class="iconbtn" id="account" aria-label="Tài khoản">👤</button>
    <button class="iconbtn" id="notif" aria-label="Bật nhắc việc">🔔</button>
    <button class="addbtn" id="add" aria-label="Thêm việc">＋</button></header>`);
  $('#add').onclick = () => location.hash = '#/form';
  $('#account').onclick = () => location.hash = '#/account';
  $('#notif').onclick = enableNotif;
}

// ── Tab Today: NEXT UP + lưới 2 cột + OVERDUE ──
function renderHome(v) {
  const tasks = sorted(), now = Date.now();
  const all = tasks.map((t) => ({ t, s: statusOf(t, now) }));
  const late = all.filter((x) => x.s.s === 'overdue' || x.s.s === 'dueGrace').sort((a, b) => a.s.diff - b.s.diff);
  const soon = all.filter((x) => x.s.diff >= 0);
  const next = soon[0];
  const grid = soon.slice(1, 5);
  const over = soon.slice(5);

  v.innerHTML = '';
  header(v, 'Today', late.length ? `${late.length} việc cần xử lý ngay` : 'Small swaps. A fresher home.');
  const wrap = document.createElement('main');
  wrap.innerHTML = `
    ${next ? `<section class="next"><div class="row"><div class="thumb">${next.t.icon}</div>
      <div><h2>${esc(next.t.title)}</h2><p class="due">Due in</p></div></div>
      <div class="big">${fmtSpan(next.s.diff)}</div>
      <button class="mark" id="markNext">Mark as done</button></section>` : ''}
    ${grid.length ? `<div class="grid">${grid.map((x) => tile(x)).join('')}</div>` : ''}
    ${over.length ? `<div class="lbl">Sắp tới nữa</div><div class="grid">${over.map((x) => tile(x)).join('')}</div>` : ''}
    ${late.length ? `<div class="lbl">Overdue</div><div class="list">${late.map((x) => overdueRow(x)).join('')}</div>` : ''}
    ${!tasks.length ? `<div class="empty"><div class="big">🏡</div><p><b>Chưa có việc nào</b><br><small class="mut">Chạm ＋ để thêm hoặc chọn mẫu bên dưới.</small></p></div>` : ''}
    <div class="lbl">Mẫu có sẵn</div>
    <div class="list">${TEMPLATES.map((t, i) => `<div class="row-i" data-t="${i}"><span class="e">${t[1]}</span>
      <span class="t">${t[0]}</span><span class="s" style="color:var(--muted);font-weight:600">${t[2]} ngày</span></div>`).join('')}</div>`;
  v.appendChild(wrap);
  v.insertAdjacentHTML('beforeend', tabbar('today'));
  bindTabs(v);
  if (next) $('#markNext').onclick = () => doDone(next.t.id, true);
  v.querySelectorAll('[data-t]').forEach((el) => el.onclick = () => addFromTemplate(+el.dataset.t));
  v.querySelectorAll('[data-open]').forEach((el) => el.onclick = () => location.hash = '#/detail/' + encodeURIComponent(el.dataset.open));
}
function tile(x) {
  return `<div class="tile" role="button" tabindex="0" data-open="${esc(x.t.id)}">
    <div class="topr"><span class="e">${x.t.icon}</span><span class="chev">›</span></div>
    <b>${esc(x.t.title)}</b><span class="d">${fmtSpan(x.s.diff)}</span></div>`;
}
function overdueRow(x) {
  return `<div class="row-i" role="button" tabindex="0" data-open="${esc(x.t.id)}"><span class="e">${x.t.icon}</span>
    <span class="t">${esc(x.t.title)}</span><span class="s">${fmtLate(-x.s.diff)}</span><span class="chev">›</span></div>`;
}

// ── Tab Items: toàn bộ danh sách ──
function renderItems(v) {
  const tasks = sorted(), now = Date.now();
  const all = tasks.map((t) => ({ t, s: statusOf(t, now) }));
  v.innerHTML = '';
  header(v, 'Items', `${tasks.length} việc đang theo dõi`);
  const wrap = document.createElement('main');
  wrap.innerHTML = all.length
    ? `<div class="lbl">Tất cả</div><div class="grid">${all.map((x) => tile(x)).join('')}</div>`
    : `<div class="empty"><div class="big">📋</div><p><b>Chưa có việc nào</b><br><small class="mut">Chạm ＋ để thêm.</small></p></div>`;
  v.appendChild(wrap);
  v.insertAdjacentHTML('beforeend', tabbar('items'));
  bindTabs(v);
  v.querySelectorAll('[data-open]').forEach((el) => el.onclick = () => location.hash = '#/detail/' + encodeURIComponent(el.dataset.open));
}

// ── Tab Activity: lịch sử làm gần nhất ──
function renderActivity(v) {
  const { tasks } = load();
  const done = tasks.filter((t) => t.lastDoneAt).sort((a, b) => b.lastDoneAt - a.lastDoneAt).slice(0, 30);
  const now = Date.now();
  v.innerHTML = '';
  header(v, 'Activity', `${done.length} lần hoàn thành gần đây`);
  const wrap = document.createElement('main');
  wrap.innerHTML = done.length
    ? `<div class="list">${done.map((t) => {
        const ago = Math.floor((now - t.lastDoneAt) / DAY);
        return `<div class="row-i" role="button" tabindex="0" data-open="${esc(t.id)}"><span class="e">${t.icon}</span>
          <span class="t">${esc(t.title)}</span><span class="s" style="color:var(--muted);font-weight:600">${ago === 0 ? 'Hôm nay' : ago === 1 ? 'Hôm qua' : ago + ' ngày trước'}</span></div>`;
      }).join('')}</div>`
    : `<div class="empty"><div class="big">📊</div><p><b>Chưa có hoạt động</b><br><small class="mut">Đánh dấu "Mark as done" để ghi lại lịch sử.</small></p></div>`;
  v.appendChild(wrap);
  v.insertAdjacentHTML('beforeend', tabbar('activity'));
  bindTabs(v);
  v.querySelectorAll('[data-open]').forEach((el) => el.onclick = () => location.hash = '#/detail/' + encodeURIComponent(el.dataset.open));
}
function renderDetail(v, id) {
  const d = load(), t = d.tasks.find((x) => x.id === id);
  if (!t) { v.innerHTML = `<main><div class="empty"><p>Không tìm thấy.</p><a href="#/">Về trang chủ</a></div></main>`; return; }
  const st = statusOf(t);
  const span = st.diff < 0 ? fmtLate(-st.diff) : fmtSpan(st.diff);
  v.innerHTML = `<main><a class="back" href="#/">← Trang chủ</a>
    <div class="dhero"><div class="e">${t.icon}</div><h2>${esc(t.title)}</h2><p>${span}</p></div>
    <div class="kv">
      <div><span>Lần cuối làm</span><b>${t.lastDoneAt ? fmt(t.lastDoneAt) : 'chưa ghi'}</b></div>
      <div><span>Chu kỳ</span><b>${t.cycleDays} ngày</b></div>
      <div><span>Nhắc trước</span><b>${t.remindBefore} ngày</b></div>
      <div><span>Trạng thái</span><b>${span} · hạn ${fmt(t.nextDueAt)}</b></div>
    </div>
    <button class="cta" id="done">✓ Đánh dấu đã xong</button>
    <div class="row" style="margin-top:10px"><button class="ghost" id="snz">Hoãn 1 ngày</button><button class="ghost" id="edit">Sửa</button></div>
    <div style="margin-top:10px"><button class="ghost danger" id="del">Xóa việc này</button></div></main>`;
  $('#done').onclick = () => doDone(id, true);
  $('#snz').onclick = () => { d.tasks = d.tasks.map((x) => x.id === id ? { ...x, snoozedUntil: Date.now() + DAY } : x); save(d); location.hash = '#/'; };
  $('#edit').onclick = () => location.hash = '#/form?edit=' + encodeURIComponent(id);
  $('#del').onclick = () => { if (confirm('Xóa việc này?')) { d.tasks = d.tasks.filter((x) => x.id !== id); save(d); location.hash = '#/'; } };
}
function renderForm(v, editId) {
  const d = load(), t = editId ? d.tasks.find((x) => x.id === editId) : null;
  v.innerHTML = `<main><a class="back" href="#/">← Trang chủ</a><h2 style="margin:4px 0 2px">${t ? 'Sửa việc' : 'Thêm việc mới'}</h2>
    <small class="mut">Chỉ cần gõ tên là xong — chu kỳ mặc định 7 ngày.</small>
    <form class="fcard" id="f" style="margin-top:12px">
    <label class="fl" for="title">Tên việc</label><input id="title" required maxlength="60" placeholder="VD: Dọn toilet" value="${esc(t?.title || '')}">
    <div class="row"><div><label class="fl" for="icon">Icon</label><select id="icon">${['🧹','🚽','🛏️','🪥','💧','🌱','🧊','🛵','💊','🦷'].map((e)=>`<option ${t?.icon===e?'selected':''}>${e}</option>`).join('')}</select></div>
    <div><label class="fl" for="cycle">Chu kỳ (ngày)</label><input id="cycle" type="number" min="1" max="730" value="${t?.cycleDays || 7}"></div></div>
    <div class="row"><div><label class="fl" for="last">Lần cuối</label><input id="last" type="date" value="${t?.lastDoneAt ? iso(t.lastDoneAt) : iso(Date.now())}"></div><div><label class="fl" for="rb">Nhắc trước</label><input id="rb" type="number" min="0" max="30" value="${t?.remindBefore ?? 2}"></div></div>
    <button class="cta" type="submit">Lưu việc</button></form></main>`;
  $('#f').onsubmit = (e) => {
    e.preventDefault();
    const title = $('#title').value.trim(); if (!title) return;
    const cycle = Math.max(1, +$('#cycle').value || 7);
    const last = new Date($('#last').value + 'T08:00:00').getTime() || Date.now();
    if (t) d.tasks = d.tasks.map((x) => x.id === t.id ? { ...x, title, icon: $('#icon').value, cycleDays: cycle, lastDoneAt: last, nextDueAt: nextDue(last, cycle), remindBefore: +$('#rb').value || 0, snoozedUntil: null } : x);
    else d.tasks.push({ id: uid(), title, icon: $('#icon').value, cycleDays: cycle, lastDoneAt: last, nextDueAt: nextDue(last, cycle), remindBefore: +$('#rb').value || 0, grace: 0, snoozedUntil: null, isActive: true });
    save(d); location.hash = '#/'; checkDue();
  };
}
function renderAccount(v) {
  const ses = getSes();
  if (ses && ses.token) {
    v.innerHTML = `<main><a class="back" href="#/">← Trang chủ</a>
      <div class="sec"><h3>Tài khoản</h3></div>
      <div class="fcard"><div class="kv" style="margin:0;border:none;box-shadow:none;padding:0">
      <div><span>Đăng nhập là</span><b>${esc(ses.username || '')}</b></div>
      <div><span>Danh sách</span><b>riêng của bạn, đồng bộ đa máy</b></div></div>
      <button class="cta" id="out">Đăng xuất</button></div>
      <p><small class="mut">Đăng xuất sẽ xóa list trên máy này (bản server vẫn giữ).</small></p></main>`;
    $('#out').onclick = () => {
      clearSes();
      localStorage.removeItem(KEY); localStorage.removeItem(SAVED_KEY);
      location.hash = '#/';
    };
    return;
  }
  v.innerHTML = `<main><a class="back" href="#/">← Trang chủ</a>
    <div class="sec"><h3>Tài khoản</h3><small>mỗi người 1 danh sách riêng</small></div>
    <form class="fcard" id="auth">
    <label class="fl" for="u">Tên đăng nhập</label><input id="u" required minlength="2" maxlength="30" autocomplete="username" placeholder="vd: lan">
    <label class="fl" for="pw">Mật khẩu (≥ 6 ký tự)</label><input id="pw" type="password" required minlength="6" autocomplete="current-password">
    <div class="row" style="margin-top:14px"><button class="cta" style="margin-top:0" type="submit" data-a="login">Đăng nhập</button><button class="ghost" type="submit" data-a="register">Đăng ký</button></div>
    <p><small class="mut" id="ams"></small></p></form></main>`;
  let action = 'login';
  v.querySelectorAll('[data-a]').forEach((b) => b.onclick = () => { action = b.dataset.a; });
  $('#auth').onsubmit = async (e) => {
    e.preventDefault();
    const msg = $('#ams');
    msg.textContent = 'Đang xử lý...';
    try {
      const r = await fetch('/api/auth', { method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action, username: $('#u').value.trim(), password: $('#pw').value }) });
      const d = await r.json();
      if (!r.ok) throw new Error(d.error || ('Lỗi ' + r.status));
      localStorage.setItem(SES_KEY, JSON.stringify({ token: d.token, username: d.username }));
      await pullSync();
      location.hash = '#/';
    } catch (err) { msg.textContent = 'Lỗi: ' + (err.message || err); }
  };
}
function addFromTemplate(i) {
  const [title, icon, cycle] = TEMPLATES[i], d = load(), now = Date.now();
  d.tasks.push({ id: uid(), title, icon, cycleDays: cycle, lastDoneAt: now, nextDueAt: nextDue(now, cycle), remindBefore: Math.min(7, Math.max(1, Math.floor(cycle / 4))), grace: 0, snoozedUntil: null, isActive: true });
  save(d); render(); checkDue();
}
function doDone(id, goHome) {
  const d = load();
  d.tasks = d.tasks.map((x) => x.id === id ? markDone(x) : x);
  save(d); if (goHome) location.hash = '#/'; else render(); checkDue();
}
async function enableNotif() {
  if (!('Notification' in window)) return alert('Trình duyệt không hỗ trợ notification.');
  if (!getTok()) { location.hash = '#/account'; return alert('Đăng nhập trước để nhắc đúng danh sách của bạn.'); }
  const p = await Notification.requestPermission();
  if (p !== 'granted') return alert('Chưa cấp quyền: ' + p);
  // Đăng ký đẩy nền (Web Push) — gắn subscription vào user đang đăng nhập.
  try {
    const reg = await navigator.serviceWorker.ready;
    const sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64url(VAPID_PUBLIC).buffer });
    const sj = sub.toJSON ? sub.toJSON() : sub;
    localStorage.setItem(PUSH_KEY, JSON.stringify(sj));
    await apiReq('/api/subscribe', 'POST', { subscription: sj });
    alert('Đã bật nhắc việc! Kể cả khi tắt app, bạn vẫn được nhắc lúc 7h sáng.');
  } catch (e) {
    alert(e && e.auth ? 'Hết phiên, hãy đăng nhập lại.' : 'Đã bật nhắc khi mở app. (Đẩy nền chưa sẵn sàng: backend /api hoặc VAPID chưa cấu hình.)');
  }
  checkDue();
}
function checkDue() {
  if (!('Notification' in window) || Notification.permission !== 'granted') return;
  const now = Date.now();
  sorted().slice(0, 3).forEach((t) => {
    const st = statusOf(t, now);
    if (st.s === 'dueToday' || st.s === 'overdue') { try { new Notification(st.s === 'overdue' ? `Quá hạn: ${t.title}` : `Đến hạn: ${t.title}`, { body: st.txt, icon: './icon.svg' }); } catch {} }
  });
}
const esc = (s) => String(s || '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const fmt = (ms) => { const d = new Date(ms); return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}`; };
const iso = (ms) => { const d = new Date(ms); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; };
window.addEventListener('hashchange', render);
// Seed lần đầu: 3 mẫu để có aha-moment 30s
if (!localStorage.getItem(KEY)) {
  const now = Date.now();
  const mk = (ti, ago) => { const [title, icon, cycle] = TEMPLATES[ti], last = now - ago * DAY; return { id: uid(), title, icon, cycleDays: cycle, lastDoneAt: last, nextDueAt: nextDue(last, cycle), remindBefore: 2, grace: 0, snoozedUntil: null, isActive: true }; };
  save({ tasks: [mk(0, 6), mk(6, 45), mk(1, 12)] });
  localStorage.removeItem(SAVED_KEY); // seed demo không đóng dấu thời gian để bản server (nếu có) luôn thắng khi đăng nhập
}
render(); checkDue();
if ('serviceWorker' in navigator) navigator.serviceWorker.register('./sw.js');
